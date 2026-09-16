# Wukong CRM Helm 部署说明

本 Chart 默认部署完整环境：MySQL 5.7、Redis、Elasticsearch 6.8.6、Nacos 1.2.1、Seata 1.2.0、Sentinel 1.7.2、XXL-JOB 2.1.2、10 个后端服务和独立前端。数据库首次创建 PVC 时会自动导入仓库中的初始化 SQL。

## 1. 构建并推送镜像

先在镜像仓库中创建 `make repositories` 输出的仓库，并登录镜像仓库。

```bash
cd WukongCRM-11.0-JAVA
make repositories
make images VERSION=20260916 PLATFORM=linux/amd64
make push VERSION=20260916

cd ../WukongCRM-11.0-web-JAVA
make image VERSION=20260916 PLATFORM=linux/amd64
make push VERSION=20260916
```

只构建最低后端集合可使用 `make images-core`；构建单个模块可使用 `make image-crm`。业务完整运行仍建议构建全部模块。

## 2. 准备集群配置

不要直接修改默认值，复制一份环境配置：

```bash
cd ../WukongCRM-11.0-JAVA
cp helm-charts/values.yaml values-prod.yaml
```

至少修改以下内容：

- `global.imageRegistry` 和 `global.imageTag`
- `global.imagePullSecrets`（私有仓库需要）
- `security.mysqlRootPassword`、`security.redisPassword`
- MySQL、Redis、Elasticsearch 与上传目录的 `storageClass`
- `ingress.enabled`、域名、IngressClass 和 TLS

私有仓库 Secret 示例：

```bash
kubectl -n wukong-crm create secret docker-registry registry-auth \
  --docker-server=crpi-ofm6apm8s01eita1.cn-beijing.personal.cr.aliyuncs.com \
  --docker-username='<username>' \
  --docker-password='<password>'
```

然后在 `values-prod.yaml` 中设置：

```yaml
global:
  imagePullSecrets:
    - name: registry-auth
```

若上传文件需要跨节点读写，请把 `uploads.persistence.accessModes` 改为 `ReadWriteMany`，并使用支持 RWX 的 StorageClass；默认 `ReadWriteOnce` 更适合单节点或所有服务可挂载同一卷的存储实现。

## 3. 校验并部署

```bash
make helm-lint HELM_VALUES=values-prod.yaml
make helm-template HELM_VALUES=values-prod.yaml VERSION=20260916
make deploy HELM_VALUES=values-prod.yaml VERSION=20260916
```

等价的原生 Helm 命令：

```bash
helm upgrade --install wukong-crm helm-charts \
  --namespace wukong-crm --create-namespace \
  -f values-prod.yaml \
  --set-string global.imageTag=20260916
```

查看状态：

```bash
kubectl -n wukong-crm get pods,svc,ingress,pvc
kubectl -n wukong-crm get pods -w
```

未启用 Ingress 时可临时访问：

```bash
kubectl -n wukong-crm port-forward svc/wukong-crm-wukong-crm-ui 8080:80
```

浏览器打开 `http://127.0.0.1:8080`。

## 使用外部中间件

关闭内置组件时必须填写对应外部地址。MySQL 和 Redis 密码建议放入已有 Secret：

```yaml
security:
  existingSecret: wukong-external-credentials

mysql:
  enabled: false
externalMysql:
  host: mysql.example.internal
  port: 3306
  username: root
  existingSecret: wukong-external-credentials
  passwordKey: mysql-root-password

redis:
  enabled: false
externalRedis:
  host: redis.example.internal
  port: 6379
  existingSecret: wukong-external-credentials
  passwordKey: redis-password

elasticsearch:
  enabled: false
externalElasticsearch:
  address: elasticsearch.example.internal:9200

nacos:
  enabled: false
externalNacos:
  address: nacos.example.internal:8848

seata:
  enabled: false
externalSeata:
  enabled: true

sentinel:
  enabled: false
externalSentinel:
  address: sentinel.example.internal:8079

xxlJob:
  enabled: false
externalXxlJob:
  address: http://xxl-job.example.internal/xxl-job-admin
```

外置 MySQL 必须事先导入 `docker/data/mysql/init/` 下的 SQL；外置 Seata 必须以 `seata-server` 服务名注册到同一个 Nacos。

## 常用操作

```bash
# 单独重建并推送 CRM 服务
make image-crm push-crm VERSION=20260916 PLATFORM=linux/amd64

# 查看某个服务日志
kubectl -n wukong-crm logs deploy/wukong-crm-wukong-crm-gateway -f

# 升级
make deploy HELM_VALUES=values-prod.yaml VERSION=20260917

# 卸载（PVC 默认保留）
make uninstall
```

MySQL 使用 PVC 内的 `/var/lib/mysql/data` 子目录作为数据目录，避免 ext4 卷根目录的 `lost+found` 导致首次初始化报 `--initialize specified but the data directory has files in it`。出现过该错误时无需删除 PVC，升级到包含此配置的 Chart 后等待 Pod 重建即可。
