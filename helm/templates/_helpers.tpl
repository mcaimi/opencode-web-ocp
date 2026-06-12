{{/*
Expand the name of the chart.
*/}}
{{- define "opencode-web.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "opencode-web.fullname" -}}
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
{{- define "opencode-web.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "opencode-web.labels" -}}
helm.sh/chart: {{ include "opencode-web.chart" . }}
{{ include "opencode-web.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "opencode-web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "opencode-web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "opencode-web.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "opencode-web.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate NO_PROXY environment variable value
Includes standard Kubernetes/OpenShift exclusions plus custom domains
*/}}
{{- define "opencode-web.noProxy" -}}
{{- if .Values.proxy.noProxy -}}
{{- .Values.proxy.noProxy -}}
{{- else -}}
{{- $noProxy := list -}}
{{- $noProxy = append $noProxy "localhost" -}}
{{- $noProxy = append $noProxy "127.0.0.1" -}}
{{- $noProxy = append $noProxy ".local" -}}
{{- $noProxy = append $noProxy ".svc" -}}
{{- $noProxy = append $noProxy ".svc.cluster.local" -}}
{{- if .Values.proxy.kubernetes.apiServer -}}
{{- $noProxy = append $noProxy .Values.proxy.kubernetes.apiServer -}}
{{- end -}}
{{- if .Values.proxy.kubernetes.serviceCIDR -}}
{{- $noProxy = append $noProxy .Values.proxy.kubernetes.serviceCIDR -}}
{{- end -}}
{{- if .Values.proxy.kubernetes.podCIDR -}}
{{- $noProxy = append $noProxy .Values.proxy.kubernetes.podCIDR -}}
{{- end -}}
{{- if .Values.proxy.additionalNoProxy -}}
{{- $noProxy = concat $noProxy .Values.proxy.additionalNoProxy -}}
{{- end -}}
{{- join "," $noProxy -}}
{{- end -}}
{{- end -}}
