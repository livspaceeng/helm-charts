## Livspace Public Helm Charts

All livspace maintained public helm charts are available here.

### Adding livspace helm repo

Before one start installing the charts from livspace helm repo, you must add the repo to your helm. Hope you have valid helm setup

```markdown
$ helm repo add livspace https://charts.livspace.com
```

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
