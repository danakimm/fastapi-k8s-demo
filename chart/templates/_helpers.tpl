{{- define "fastapi-pg.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fastapi-pg.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "fastapi-pg.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fastapi-pg.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "fastapi-pg.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{ include "fastapi-pg.selectorLabels" . }}
{{- end }}

{{- define "fastapi-pg.apiName" -}}
{{ include "fastapi-pg.fullname" . }}-api
{{- end }}

{{- define "fastapi-pg.postgresName" -}}
{{ include "fastapi-pg.fullname" . }}-postgres
{{- end }}
