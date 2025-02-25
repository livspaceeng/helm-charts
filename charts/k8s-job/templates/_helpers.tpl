{{/*
Expand the name of the chart.
*/}}
{{- define "k8s-job.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this.
If release name contains non-alphanumeric characters, replace them with dashes.
We truncate at 63 chars because some Kubernetes name fields are limited to this.
*/}}
{{- define "k8s-job.fullname" -}}
{{- $fullName := printf "%s-%s" .Release.Name .Chart.Name -}}
{{- if .Values.fullnameOverride -}}
{{- $fullName := .Values.fullnameOverride -}}
{{- end -}}
{{- /* regxpReplaceAll "[^a-zA-Z0-9-]" "-" $fullName | */ -}}
{{- trunc 63 $fullName | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "k8s-job.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "k8s-job.labels" -}}
helm.sh/chart: {{ include "k8s-job.chart" . }}
{{ include "k8s-job.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "k8s-job.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-job.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "k8s-job.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "k8s-job.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default .Values.serviceAccount.name .Release.Name -}}
{{- end -}}
{{- end -}}