{{/*
Default name of the Chart (and its resources) is defined in the Chart.yaml.
However, this name may be overriden to avoid conflict if more than one application use this chart.
*/}}
{{- define "cloud-shuffle-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cloud-shuffle-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cloud-shuffle-service.labels" -}}
helm.sh/chart: {{ include "cloud-shuffle-service.chart" . }}
{{ include "cloud-shuffle-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cloud-shuffle-service.selectorLabels" -}}
app: rss
{{- end }}

