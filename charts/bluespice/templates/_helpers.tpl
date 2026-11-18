{{/*
Expand the name of the chart.
*/}}
{{- define "bluespice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "bluespice.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version string.
*/}}
{{- define "bluespice.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to chart-scoped resources.
*/}}
{{- define "bluespice.labels" -}}
helm.sh/chart: {{ include "bluespice.chart" . }}
{{ include "bluespice.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels (kept small to satisfy label length rules).
*/}}
{{- define "bluespice.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bluespice.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Creates list from merged extraVolumeMounts with global,
  filters null (disabled) mounts.
Use: $var := include "bluespice.extraVolumeMounts" (list $ $value) | fromYamlArray
*/}}
{{- define "bluespice.extraVolumeMounts" -}}
{{- $global := default dict (index . 0).Values.global.extraVolumeMounts }}
{{- $extra := default dict (index . 1).extraVolumeMounts }}
{{- $merged := mustMergeOverwrite (dict) $extra $global }}
{{- $items := list }}
{{- range $name, $mount := $merged -}}
{{- if $mount -}}
  {{- $vname := regexFind "^[a-z0-9-]+" $name | trimSuffix "-" }}
  {{- $n := mustMergeOverwrite (dict "name" $vname) $mount }}
  {{- $items = append $items $n }}
{{- end }}
{{- end }}
{{ toYaml $items }}
{{- end -}}

{{/*
Creates list from merged extraVolumes with global,
  filters null (disabled) volumes.
Use: $var := include "bluespice.extraVolumes" (list $ $value) | fromYamlArray
*/}}
{{- define "bluespice.extraVolumes" -}}
{{- $global := default dict (index . 0).Values.global.extraVolumes }}
{{- $extra := default dict (index . 1).extraVolumes }}
{{- $merged := mustMergeOverwrite (dict) $extra $global }}
{{- $items := list }}
{{- range $name, $mount := $merged -}}
{{- if $mount -}}
  {{- $n := mustMergeOverwrite (dict "name" $name) $mount }}
  {{- $items = append $items $n }}
{{- end }}
{{- end }}
{{ toYaml $items }}
{{- end -}}
