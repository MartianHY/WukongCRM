SHELL := /bin/sh

REGISTRY ?= crpi-ofm6apm8s01eita1.cn-beijing.personal.cr.aliyuncs.com/martian-ali
VERSION ?= latest
PLATFORM ?=
DOCKER_BUILD ?= docker build
HELM_RELEASE ?= wukong-crm
HELM_NAMESPACE ?= wukong-crm
HELM_VALUES ?= helm-charts/values.yaml
SENTINEL_SOURCE_IMAGE ?= registry.cn-hangzhou.aliyuncs.com/72crm/crm:11.3.3
SENTINEL_JAVA_IMAGE ?= eclipse-temurin:8-jre-jammy
ELASTICSEARCH_SOURCE_IMAGE ?= registry.cn-hangzhou.aliyuncs.com/72crm/elasticsearch:6.8.6

PLATFORM_ARG := $(if $(PLATFORM),--platform $(PLATFORM),)

CORE_SERVICES := gateway authorization admin
OPTIONAL_SERVICES := crm examine bi job oa work hrm
ALL_SERVICES := $(CORE_SERVICES) $(OPTIONAL_SERVICES)
SERVICES ?= $(ALL_SERVICES)

gateway_IMAGE := wukong-gateway
authorization_IMAGE := wukong-authorization
admin_IMAGE := wukong-admin
crm_IMAGE := wukong-crm
examine_IMAGE := wukong-examine
bi_IMAGE := wukong-bi
job_IMAGE := wukong-job
oa_IMAGE := wukong-oa
work_IMAGE := wukong-work
hrm_IMAGE := wukong-hrm

.PHONY: help repositories images images-core image-db-init image-sentinel image-elasticsearch push push-core push-db-init push-sentinel push-elasticsearch \
	helm-lint helm-template deploy uninstall \
	$(addprefix image-,$(ALL_SERVICES)) $(addprefix push-,$(ALL_SERVICES))

help:
	@echo "make images                         构建全部后端服务、数据库初始化、Sentinel 和 Elasticsearch 镜像"
	@echo "make images SERVICES='gateway authorization admin crm'  构建指定服务"
	@echo "make images-core                    只构建 Gateway/Authorization/Admin"
	@echo "make image-crm VERSION=v1           构建单个服务镜像"
	@echo "make push VERSION=v1                推送指定服务及初始化镜像"
	@echo "make repositories                   列出需要预先创建的镜像仓库"
	@echo "make helm-lint / helm-template      校验 Helm Chart"
	@echo "make deploy                         部署或升级"
	@echo "变量: REGISTRY, VERSION, PLATFORM, SERVICES, HELM_RELEASE, HELM_NAMESPACE, HELM_VALUES"

repositories:
	@$(foreach service,$(ALL_SERVICES),echo "$(REGISTRY)/$($(service)_IMAGE)";)
	@echo "$(REGISTRY)/wukong-db-init"
	@echo "$(REGISTRY)/wukong-sentinel"
	@echo "$(REGISTRY)/wukong-elasticsearch"

define SERVICE_IMAGE_RULE
image-$(1):
	$$(DOCKER_BUILD) $$(PLATFORM_ARG) --build-arg APP_MODULE=$(1) -t "$$(REGISTRY)/$$($(1)_IMAGE):$$(VERSION)" .
endef
$(foreach service,$(ALL_SERVICES),$(eval $(call SERVICE_IMAGE_RULE,$(service))))

image-db-init:
	$(DOCKER_BUILD) $(PLATFORM_ARG) -f deploy/docker/Dockerfile.db-init -t "$(REGISTRY)/wukong-db-init:$(VERSION)" .

image-sentinel:
	$(DOCKER_BUILD) $(PLATFORM_ARG) --build-arg SENTINEL_SOURCE_IMAGE="$(SENTINEL_SOURCE_IMAGE)" --build-arg JAVA_IMAGE="$(SENTINEL_JAVA_IMAGE)" -f deploy/docker/Dockerfile.sentinel -t "$(REGISTRY)/wukong-sentinel:$(VERSION)" .

image-elasticsearch:
	$(DOCKER_BUILD) $(PLATFORM_ARG) --build-arg ELASTICSEARCH_SOURCE_IMAGE="$(ELASTICSEARCH_SOURCE_IMAGE)" -f deploy/docker/Dockerfile.elasticsearch -t "$(REGISTRY)/wukong-elasticsearch:$(VERSION)" .

images: $(addprefix image-,$(SERVICES)) image-db-init image-sentinel image-elasticsearch

images-core: $(addprefix image-,$(CORE_SERVICES)) image-db-init image-sentinel

define PUSH_SERVICE_RULE
push-$(1):
	docker push "$$(REGISTRY)/$$($(1)_IMAGE):$$(VERSION)"
endef
$(foreach service,$(ALL_SERVICES),$(eval $(call PUSH_SERVICE_RULE,$(service))))

push-db-init:
	docker push "$(REGISTRY)/wukong-db-init:$(VERSION)"

push-sentinel:
	docker push "$(REGISTRY)/wukong-sentinel:$(VERSION)"

push-elasticsearch:
	docker push "$(REGISTRY)/wukong-elasticsearch:$(VERSION)"

push: $(addprefix push-,$(SERVICES)) push-db-init push-sentinel push-elasticsearch

push-core: $(addprefix push-,$(CORE_SERVICES)) push-db-init push-sentinel

helm-lint:
	helm lint helm-charts -f $(HELM_VALUES)

helm-template:
	helm template $(HELM_RELEASE) helm-charts --namespace $(HELM_NAMESPACE) -f $(HELM_VALUES) \
		--set-string global.imageRegistry="$(REGISTRY)" --set-string global.imageTag="$(VERSION)" >/dev/null

deploy: helm-lint
	helm upgrade --install $(HELM_RELEASE) helm-charts --namespace $(HELM_NAMESPACE) --create-namespace \
		-f $(HELM_VALUES) --set-string global.imageRegistry="$(REGISTRY)" --set-string global.imageTag="$(VERSION)"

uninstall:
	helm uninstall $(HELM_RELEASE) --namespace $(HELM_NAMESPACE)
