{{/*
Expand the name of the chart.
*/}}
{{- define "genieacs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "genieacs.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "genieacs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "genieacs.labels" -}}
helm.sh/chart: {{ include "genieacs.chart" . }}
{{ include "genieacs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for GenieACS
*/}}
{{- define "genieacs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "genieacs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
MongoDB name
*/}}
{{- define "genieacs.mongodb.name" -}}
{{- printf "%s-mongodb" (include "genieacs.fullname" .) }}
{{- end }}

{{/*
MongoDB labels
*/}}
{{- define "genieacs.mongodb.labels" -}}
helm.sh/chart: {{ include "genieacs.chart" . }}
{{ include "genieacs.mongodb.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for MongoDB
*/}}
{{- define "genieacs.mongodb.selectorLabels" -}}
app.kubernetes.io/name: {{ include "genieacs.mongodb.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "genieacs.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "genieacs.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}