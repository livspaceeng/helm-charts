## Livspace Public Helm Charts

All livspace maintained public helm charts are available here.

### Adding livspace helm repo

Before one start installing the charts from livspace helm repo, you must add the repo to your helm. Hope you have valid helm setup

```markdown
$ helm repo add livspace https://charts.livspace.com
```

### OCI registry (Artifact Registry)

Every released chart is also pushed to an OCI repo in GCP Artifact Registry. Argo CD pulls from there, so builds no longer depend on GitHub release downloads.

```yaml
# kustomization.yaml
helmCharts:
  - name: app-compat
    repo: oci://asia-south1-docker.pkg.dev/livspace-artifacts/helm-charts
    version: 3.3.8   # pin an exact version
```

Pulls need `roles/artifactregistry.reader` on `livspace-artifacts/helm-charts`; the repo is not public. Pushes happen in the `Release Charts` workflow. To copy versions released before the OCI repo existed, run the `Backfill Charts to Artifact Registry` workflow.

### Support or Contact

Having trouble with Pages? Check out our [documentation](https://help.github.com/categories/github-pages-basics/) or [contact support](https://github.com/contact) and we’ll help you sort it out.

### For  developers
```sh
git clone https://github.com/livspaceeng/helm-charts.git
cd helm-charts
#Chart name and folder name should be same
helm package ../app-chart-folder
helm repo index --merge index.yaml --url https://charts.livspace.com .
git add .
git commit
git push origin
```
