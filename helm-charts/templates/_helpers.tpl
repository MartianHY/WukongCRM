{{- define "wukong.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "wukong.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "wukong.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "wukong.labels" -}}
app.kubernetes.io/name: {{ include "wukong.name" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "wukong.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wukong.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "wukong.credentialsSecret" -}}
{{- default (printf "%s-credentials" (include "wukong.fullname" .)) .Values.security.existingSecret -}}
{{- end -}}

{{- define "wukong.mysqlHost" -}}
{{- if .Values.mysql.enabled -}}{{ include "wukong.fullname" . }}-mysql{{- else -}}{{ required "externalMysql.host is required when mysql.enabled=false" .Values.externalMysql.host }}{{- end -}}
{{- end -}}

{{- define "wukong.mysqlPort" -}}
{{- if .Values.mysql.enabled -}}{{ .Values.mysql.service.port }}{{- else -}}{{ .Values.externalMysql.port }}{{- end -}}
{{- end -}}

{{- define "wukong.mysqlUsername" -}}
{{- if .Values.mysql.enabled -}}root{{- else -}}{{ .Values.externalMysql.username }}{{- end -}}
{{- end -}}

{{- define "wukong.mysqlSecret" -}}
{{- if .Values.mysql.enabled -}}{{ include "wukong.credentialsSecret" . }}{{- else -}}{{ default (include "wukong.credentialsSecret" .) .Values.externalMysql.existingSecret }}{{- end -}}
{{- end -}}

{{- define "wukong.mysqlPasswordKey" -}}
{{- if .Values.mysql.enabled -}}mysql-root-password{{- else -}}{{ .Values.externalMysql.passwordKey }}{{- end -}}
{{- end -}}

{{- define "wukong.redisHost" -}}
{{- if .Values.redis.enabled -}}{{ include "wukong.fullname" . }}-redis{{- else -}}{{ required "externalRedis.host is required when redis.enabled=false" .Values.externalRedis.host }}{{- end -}}
{{- end -}}

{{- define "wukong.redisPort" -}}
{{- if .Values.redis.enabled -}}{{ .Values.redis.service.port }}{{- else -}}{{ .Values.externalRedis.port }}{{- end -}}
{{- end -}}

{{- define "wukong.redisSecret" -}}
{{- if .Values.redis.enabled -}}{{ include "wukong.credentialsSecret" . }}{{- else -}}{{ default (include "wukong.credentialsSecret" .) .Values.externalRedis.existingSecret }}{{- end -}}
{{- end -}}

{{- define "wukong.redisPasswordKey" -}}
{{- if .Values.redis.enabled -}}redis-password{{- else -}}{{ .Values.externalRedis.passwordKey }}{{- end -}}
{{- end -}}

{{- define "wukong.elasticsearchAddress" -}}
{{- if .Values.elasticsearch.enabled -}}{{ include "wukong.fullname" . }}-elasticsearch:{{ .Values.elasticsearch.service.port }}{{- else -}}{{ required "externalElasticsearch.address is required when elasticsearch.enabled=false" .Values.externalElasticsearch.address }}{{- end -}}
{{- end -}}

{{- define "wukong.nacosAddress" -}}
{{- if .Values.nacos.enabled -}}{{ include "wukong.fullname" . }}-nacos:{{ .Values.nacos.service.port }}{{- else -}}{{ required "externalNacos.address is required when nacos.enabled=false" .Values.externalNacos.address }}{{- end -}}
{{- end -}}

{{- define "wukong.sentinelAddress" -}}
{{- if .Values.sentinel.enabled -}}{{ include "wukong.fullname" . }}-sentinel:{{ .Values.sentinel.service.port }}{{- else -}}{{ required "externalSentinel.address is required when sentinel.enabled=false" .Values.externalSentinel.address }}{{- end -}}
{{- end -}}

{{- define "wukong.xxlJobAddress" -}}
{{- if .Values.xxlJob.enabled -}}http://{{ include "wukong.fullname" . }}-xxl-job:{{ .Values.xxlJob.service.port }}/xxl-job-admin{{- else -}}{{ .Values.externalXxlJob.address }}{{- end -}}
{{- end -}}

{{- define "wukong.appImage" -}}
{{- $root := index . 0 -}}
{{- $service := index . 1 -}}
{{- $registry := trimSuffix "/" $root.Values.global.imageRegistry -}}
{{- $tag := default $root.Values.global.imageTag $service.image.tag | toString -}}
{{- if $registry -}}{{ printf "%s/%s:%s" $registry $service.image.repository $tag }}{{- else -}}{{ printf "%s:%s" $service.image.repository $tag }}{{- end -}}
{{- end -}}

{{- define "wukong.uiImage" -}}
{{- $registry := trimSuffix "/" .Values.global.imageRegistry -}}
{{- $tag := default .Values.global.imageTag .Values.ui.image.tag | toString -}}
{{- if $registry -}}{{ printf "%s/%s:%s" $registry .Values.ui.image.repository $tag }}{{- else -}}{{ printf "%s:%s" .Values.ui.image.repository $tag }}{{- end -}}
{{- end -}}

{{- define "wukong.initImage" -}}
{{- $registry := trimSuffix "/" .Values.global.imageRegistry -}}
{{- $tag := default .Values.global.imageTag .Values.mysql.initImage.tag | toString -}}
{{- if $registry -}}{{ printf "%s/%s:%s" $registry .Values.mysql.initImage.repository $tag }}{{- else -}}{{ printf "%s:%s" .Values.mysql.initImage.repository $tag }}{{- end -}}
{{- end -}}

{{- define "wukong.sentinelImage" -}}
{{- $registry := trimSuffix "/" .Values.global.imageRegistry -}}
{{- $tag := default .Values.global.imageTag .Values.sentinel.image.tag | toString -}}
{{- if $registry -}}{{ printf "%s/%s:%s" $registry .Values.sentinel.image.repository $tag }}{{- else -}}{{ printf "%s:%s" .Values.sentinel.image.repository $tag }}{{- end -}}
{{- end -}}
