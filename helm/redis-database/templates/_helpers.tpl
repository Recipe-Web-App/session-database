{{/*
Expand the name of the chart.
*/}}
{{- define "redis-database.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "redis-database.fullname" -}}
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
{{- define "redis-database.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "redis-database.labels" -}}
helm.sh/chart: {{ include "redis-database.chart" . }}
{{ include "redis-database.selectorLabels" . }}
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
{{- define "redis-database.selectorLabels" -}}
app.kubernetes.io/name: {{ include "redis-database.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "redis-database.serviceAccountName" -}}
{{- if .Values.security.serviceAccount.create }}
{{- default (include "redis-database.fullname" .) .Values.security.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.security.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Redis Master labels
*/}}
{{- define "redis-database.masterLabels" -}}
{{ include "redis-database.labels" . }}
app.kubernetes.io/component: redis-master
{{- end }}

{{/*
Redis Master selector labels
*/}}
{{- define "redis-database.masterSelectorLabels" -}}
{{ include "redis-database.selectorLabels" . }}
app.kubernetes.io/component: redis-master
{{- end }}

{{/*
Redis Replica labels
*/}}
{{- define "redis-database.replicaLabels" -}}
{{ include "redis-database.labels" . }}
app.kubernetes.io/component: redis-replica
{{- end }}

{{/*
Redis Replica selector labels
*/}}
{{- define "redis-database.replicaSelectorLabels" -}}
{{ include "redis-database.selectorLabels" . }}
app.kubernetes.io/component: redis-replica
{{- end }}

{{/*
Redis Sentinel labels
*/}}
{{- define "redis-database.sentinelLabels" -}}
{{ include "redis-database.labels" . }}
app.kubernetes.io/component: redis-sentinel
{{- end }}

{{/*
Redis Sentinel selector labels
*/}}
{{- define "redis-database.sentinelSelectorLabels" -}}
{{ include "redis-database.selectorLabels" . }}
app.kubernetes.io/component: redis-sentinel
{{- end }}

{{/*
Monitoring labels
*/}}
{{- define "redis-database.monitoringLabels" -}}
{{ include "redis-database.labels" . }}
app.kubernetes.io/component: monitoring
{{- end }}

{{/*
Security Context
*/}}
{{- define "redis-database.securityContext" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: 999
  runAsGroup: 999
  fsGroup: 999
{{- end }}

{{/*
Container Security Context
*/}}
{{- define "redis-database.containerSecurityContext" -}}
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
{{- define "redis-database.image" -}}
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
{{- define "redis-database.storageClass" -}}
{{- default .Values.global.storageClass .Values.ha.master.persistence.storageClass -}}
{{- end }}

{{/*
Service labels - adds service-specific label to common labels
*/}}
{{- define "redis-database.serviceLabels" -}}
{{- $serviceName := index . 0 -}}
{{- $root := index . 1 -}}
{{ include "redis-database.labels" $root }}
app.kubernetes.io/service: {{ $serviceName }}
{{- end }}

{{/*
Get sentinel master name
*/}}
{{- define "redis-database.sentinelMasterName" -}}
{{- default "redis-master" .Values.sentinel.masterName -}}
{{- end }}
