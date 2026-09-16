SHELL := /bin/sh

REGISTRY ?= crpi-ofm6apm8s01eita1.cn-beijing.personal.cr.aliyuncs.com/martian-ali
VERSION ?= latest
PLATFORM ?=
DOCKER_BUILD ?= docker build
HELM_RELEASE ?= wukong-crm
HELM_NAMESPACE ?= wukong-crm
HELM_VALUES ?= helm-charts/values.yaml

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

.PHONY: help repositories images images-core image-db-init push push-core push-db-init \
	helm-lint helm-template deploy uninstall \
	$(addprefix image-,$(ALL_SERVICES)) $(addprefix push-,$(ALL_SERVICES))

help:
	@echo "make images                         构建全部后端服务及数据库初始化镜像"
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

define SERVICE_IMAGE_RULE
image-$(1):
	$$(DOCKER_BUILD) $$(PLATFORM_ARG) --build-arg APP_MODULE=$(1) -t "$$(REGISTRY)/$$($(1)_IMAGE):$$(VERSION)" .
endef
$(foreach service,$(ALL_SERVICES),$(eval $(call SERVICE_IMAGE_RULE,$(service))))

image-db-init:
	$(DOCKER_BUILD) $(PLATFORM_ARG) -f deploy/docker/Dockerfile.db-init -t "$(REGISTRY)/wukong-db-init:$(VERSION)" .

images: $(addprefix image-,$(SERVICES)) image-db-init

images-core: $(addprefix image-,$(CORE_SERVICES)) image-db-init

define PUSH_SERVICE_RULE
push-$(1):
	docker push "$$(REGISTRY)/$$($(1)_IMAGE):$$(VERSION)"
endef
$(foreach service,$(ALL_SERVICES),$(eval $(call PUSH_SERVICE_RULE,$(service))))

push-db-init:
	docker push "$(REGISTRY)/wukong-db-init:$(VERSION)"

push: $(addprefix push-,$(SERVICES)) push-db-init

push-core: $(addprefix push-,$(CORE_SERVICES)) push-db-init

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
