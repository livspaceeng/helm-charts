#!/usr/bin/env bash
# One-off: copy chart versions already published on charts.livspace.com into
# the Artifact Registry OCI repo, so kustomizations can repoint without a chart
# version bump. Versions already in AR are skipped, so it is safe to re-run.
#
# Usage: oci-backfill.sh [chart-name]   (no argument = every chart)
set -euo pipefail

# shellcheck source=oci-push.sh
. "$(dirname "$0")/oci-push.sh"

only="${1:-}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

helm repo add livspace https://charts.livspace.com --force-update >/dev/null
oci_login

helm search repo livspace/ --versions -o json |
  python3 -c '
import json, sys
only = sys.argv[1]
for c in json.load(sys.stdin):
    name = c["name"].split("/", 1)[1]
    if not only or name == only:
        print(name, c["version"])
' "$only" |
  while read -r name version; do
    if oci_has "$name" "$version"; then
      echo "skip   ${name}:${version}"
      continue
    fi
    # The .tgz still comes from GitHub release assets, which 504 intermittently.
    for attempt in 1 2 3 4 5; do
      helm pull "livspace/${name}" --version "$version" -d "$work" && break
      [ "$attempt" -lt 5 ] || { echo "FAILED ${name}:${version}" >&2; exit 1; }
      sleep $((attempt * 10))
    done
    oci_login # metadata tokens last an hour; a full backfill can take longer
    helm push "${work}/${name}-${version}.tgz" "$OCI_REPO"
    rm -f "${work}/${name}-${version}.tgz"
  done
