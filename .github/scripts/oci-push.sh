#!/usr/bin/env bash
# Push packaged charts (.tgz) to the Artifact Registry OCI repo, skipping any
# name:version already there.
#
# Usage: oci-push.sh <chart.tgz>...
#
# Auth: runs on the self-hosted-gke runners (gke-keystone), whose pod identity
# is Workload Identity for secret-management-sa; that SA has repo-level
# artifactregistry.writer on livspace-artifacts/helm-charts (troposphere
# stacks/artifacts/helm-charts). The access token comes from the metadata
# server, so no key is stored anywhere.
set -euo pipefail

OCI_HOST="${OCI_HOST:-asia-south1-docker.pkg.dev}"
OCI_REPO="${OCI_REPO:-oci://${OCI_HOST}/livspace-artifacts/helm-charts}"

oci_login() {
  curl -sSf -H 'Metadata-Flavor: Google' \
    http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' |
    helm registry login "$OCI_HOST" -u oauth2accesstoken --password-stdin
}

oci_has() { # <name> <version>
  helm show chart "${OCI_REPO}/$1" --version "$2" >/dev/null 2>&1
}

chart_field() { # <chart.tgz> <field>
  # Top-level keys only: Chart.yaml also has maintainers[].name.
  helm show chart "$1" | awk -v f="$2:" 'index($0, f) == 1 { print $2; exit }' | tr -d "\"'"
}

main() {
  [ "$#" -gt 0 ] || { echo "usage: $0 <chart.tgz>..." >&2; exit 2; }
  oci_login
  for pkg in "$@"; do
    name=$(chart_field "$pkg" name)
    version=$(chart_field "$pkg" version)
    if oci_has "$name" "$version"; then
      echo "skip   ${name}:${version} (already in ${OCI_REPO})"
    else
      helm push "$pkg" "$OCI_REPO"
    fi
  done
}

# Sourced by oci-backfill.sh for the helpers; executed directly to push.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
