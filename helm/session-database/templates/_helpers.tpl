{{/*
Expand the name of the chart.
*/}}
{{- define "session-database.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "session-database.fullname" -}}
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
{{- define "session-database.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "session-database.labels" -}}
helm.sh/chart: {{ include "session-database.chart" . }}
{{ include "session-database.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "session-database.selectorLabels" -}}
app.kubernetes.io/name: {{ include "session-database.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "session-database.serviceAccountName" -}}
{{- if .Values.security.serviceAccount.create }}
{{- default (include "session-database.fullname" .) .Values.security.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.security.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Redis Master labels
*/}}
{{- define "session-database.masterLabels" -}}
{{ include "session-database.labels" . }}
app.kubernetes.io/component: redis-master
{{- end }}

{{/*
Redis Master selector labels
*/}}
{{- define "session-database.masterSelectorLabels" -}}
{{ include "session-database.selectorLabels" . }}
app.kubernetes.io/component: redis-master
{{- end }}

{{/*
Redis Replica labels
*/}}
{{- define "session-database.replicaLabels" -}}
{{ include "session-database.labels" . }}
app.kubernetes.io/component: redis-replica
{{- end }}

{{/*
Redis Replica selector labels
*/}}
{{- define "session-database.replicaSelectorLabels" -}}
{{ include "session-database.selectorLabels" . }}
app.kubernetes.io/component: redis-replica
{{- end }}

{{/*
Redis Sentinel labels
*/}}
{{- define "session-database.sentinelLabels" -}}
{{ include "session-database.labels" . }}
app.kubernetes.io/component: redis-sentinel
{{- end }}

{{/*
Redis Sentinel selector labels
*/}}
{{- define "session-database.sentinelSelectorLabels" -}}
{{ include "session-database.selectorLabels" . }}
app.kubernetes.io/component: redis-sentinel
{{- end }}

{{/*
Monitoring labels
*/}}
{{- define "session-database.monitoringLabels" -}}
{{ include "session-database.labels" . }}
app.kubernetes.io/component: monitoring
{{- end }}

{{/*
Security Context
*/}}
{{- define "session-database.securityContext" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: 999
  runAsGroup: 999
  fsGroup: 999
{{- end }}

{{/*
Container Security Context
*/}}
{{- define "session-database.containerSecurityContext" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false
  capabilities:
    drop:
    - ALL
    add:
    - SETUID
    - SETGID
{{- end }}

{{/*
Image
*/}}
{{- define "session-database.image" -}}
{{- $registry := default .Values.image.registry .Values.global.imageRegistry -}}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry .Values.image.repository .Values.image.tag -}}
{{- else }}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end }}
{{- end }}

{{/*
Storage Class
*/}}
{{- define "session-database.storageClass" -}}
{{- default .Values.global.storageClass .Values.ha.master.persistence.storageClass -}}
{{- end }}
