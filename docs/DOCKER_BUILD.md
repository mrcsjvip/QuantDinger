# Docker 镜像构建说明

QuantDinger 的 Docker 编排仅包含 **Vue 前端** 和 **Python 后端**，数据库使用**外部已有 PostgreSQL**。在目标机器上配置好 `DATABASE_URL` 即可。

## 前置要求

- [Docker](https://docs.docker.com/get-docker/)（建议 20.10+）
- [Docker Compose](https://docs.docker.com/compose/install/)（v2 或 v3）
- 已有可用的 PostgreSQL 服务（本机或远程）

## 方式一：使用 Docker Compose（推荐）

在目标机器上配置数据库连接：在 `backend_api_python/.env` 中设置（可参考 `backend_api_python/env.example`），例如：

```bash
DATABASE_URL=postgresql://user:password@your-pg-host:5432/quantdinger
```

若 PostgreSQL 在宿主机上，宿主机内可用 `host.docker.internal`（Mac/Windows）或宿主机 IP 作为 host。

然后执行：

```bash
# 构建并启动后端 + 前端
docker-compose up -d --build
```

- **后端 API**：<http://127.0.0.1:5000>
- **前端页面**：<http://127.0.0.1:8888>（前端通过 Nginx 将 `/api/` 代理到后端）

仅构建镜像、不启动：

```bash
docker-compose build
```

指定镜像标签（例如用于推送到镜像仓库）：

```bash
docker-compose build --build-arg BUILD_TAG=1.0.0
# 或先 build 再打 tag
docker tag quantdinger-backend your-registry/quantdinger-backend:1.0.0
docker tag quantdinger-frontend your-registry/quantdinger-frontend:1.0.0
```

## 根目录单镜像（适用于阿里云 ACR 镜像构建）

阿里云 ACR 的「镜像构建」通常从代码库**根目录**的 Dockerfile 构建**一个**镜像。项目在仓库根目录提供了 `Dockerfile`，会先构建 Vue 前端，再与 Python 后端打成一个镜像（后端在同一端口提供 API 并托管前端静态资源）。

**构建（在仓库根目录）：**

```bash
docker build -t quantdinger:latest .
```

**推送至 ACR：** 在 ACR 控制台配置「镜像构建」时，将构建上下文设为仓库根目录，Dockerfile 路径为 `./Dockerfile`。构建产物为单镜像，运行一个容器即可（需配置 `DATABASE_URL` 等环境变量）。

**运行示例：**

```bash
docker run -p 5000:5000 --env-file backend_api_python/.env quantdinger:latest
```

访问 <http://127.0.0.1:5000> 即可使用前端与 API（同一端口）。

### 单镜像在目标服务器上的配置与运行

从 ACR 拉取单镜像后，通过**宿主机上的配置文件**注入环境变量即可运行。

#### 1. 准备配置文件

在目标服务器上任意目录创建 `.env` 文件（可参考项目中的 `backend_api_python/env.example`），至少配置：

- **DATABASE_URL**：PostgreSQL 连接串，必填。例如：`postgresql://用户:密码@数据库地址:5432/数据库名`
- **SECRET_KEY**：会话密钥，建议修改
- **ADMIN_USER / ADMIN_PASSWORD**：管理员账号

示例 `.env` 片段：

```bash
DATABASE_URL=postgresql://quantdinger:yourpassword@192.168.1.10:5432/quantdinger
SECRET_KEY=your-random-secret-key
ADMIN_USER=admin
ADMIN_PASSWORD=your-admin-password
```

若 PostgreSQL 在宿主机本机，地址可填 `host.docker.internal:5432`（Mac/Windows）或宿主机内网 IP。

#### 2. 方式一：docker run

```bash
# 先登录 ACR（仅首次）
docker login registry.cn-hangzhou.aliyuncs.com

# 拉取镜像（替换为你的 ACR 地址与标签）
docker pull registry.cn-hangzhou.aliyuncs.com/mycompany/quantdinger:1.0.0

# 指定配置文件并运行（/path/to/.env 改为你放 .env 的路径）
docker run -d \
  --name quantdinger \
  -p 5000:5000 \
  --restart unless-stopped \
  --env-file /path/to/.env \
  -v /path/to/logs:/app/logs \
  -v /path/to/data:/app/data \
  registry.cn-hangzhou.aliyuncs.com/mycompany/quantdinger:1.0.0
```

- `--env-file /path/to/.env`：使用该文件中的所有环境变量。
- `-v .../logs:/app/logs`、`-v .../data:/app/data`：持久化日志与数据（可选，不挂载则重启后丢失）。

#### 3. 方式二：docker-compose（推荐）

将项目中的 `docker-compose.single.yml` 复制到目标服务器同一目录，把其中的 `image` 改为你的 ACR 镜像地址，在同一目录下放置 `.env`，然后执行：

```bash
# 拉取镜像并启动
docker-compose -f docker-compose.single.yml pull
docker-compose -f docker-compose.single.yml up -d

# 查看日志
docker-compose -f docker-compose.single.yml logs -f

# 停止
docker-compose -f docker-compose.single.yml down
```

`docker-compose.single.yml` 中已通过 `env_file: - .env` 指定配置文件，并通过 `volumes` 挂载 `./logs`、`./data`，按需修改路径或镜像名即可。

#### 4. 仅覆盖部分变量

若不想用完整 `.env`，可只传必要变量，其余用默认值：

```bash
docker run -d --name quantdinger -p 5000:5000 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/quantdinger \
  -e SECRET_KEY=your-secret \
  registry.cn-hangzhou.aliyuncs.com/mycompany/quantdinger:1.0.0
```

容器内应用会从 `os.environ` 读取变量；未设置的项会使用代码中的默认值或空值。

## 方式二：单独构建各镜像

适用于只改某一端、或需要在 CI 中分别构建的场景。

### 构建后端镜像（Python）

```bash
docker build -t quantdinger-backend:latest ./backend_api_python
```

运行示例（需自行提供数据库等环境变量）：

```bash
docker run -p 5000:5000 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/quantdinger \
  quantdinger-backend:latest
```

### 构建前端镜像（Vue → Nginx）

```bash
docker build -t quantdinger-frontend:latest ./quantdinger_vue
```

前端镜像内已包含 Nginx，`/api/` 会代理到 `http://backend:5000`，因此**单独跑前端容器时**需与后端在同一 Docker 网络中，或修改 `quantdinger_vue/deploy/nginx-docker.conf` 中的 `proxy_pass` 指向实际后端地址。

## 镜像说明

| 服务 | 构建上下文           | 说明 |
|------|----------------------|------|
| 后端 | `./backend_api_python` | `python:3.12-slim`，入口 `python run.py`，依赖外部 PostgreSQL |
| 前端 | `./quantdinger_vue`  | 多阶段：Node 18 构建 → `nginx:alpine` 托管静态资源 |

## 常用命令

```bash
# 查看运行状态
docker-compose ps

# 查看日志
docker-compose logs -f
docker-compose logs -f backend
docker-compose logs -f frontend

# 停止服务
docker-compose down
```

## 推送到阿里云容器镜像服务 (ACR)

将镜像构建并推送到 [阿里云 ACR](https://cr.console.aliyun.com) 私有仓库后，可在目标机器上拉取运行。

### 1. 登录 ACR

在 ACR 控制台创建命名空间与仓库后，在本地登录（密码在控制台「访问凭证」中设置）：

```bash
# 个人版：按地域选择，例如华东1（杭州）
docker login registry.cn-hangzhou.aliyuncs.com
# 输入阿里云账号（或子账号）、访问凭证中的密码
```

企业版实例的登录地址格式为：`<实例名>-registry.cn-<地域>.cr.aliyuncs.com`，在控制台可查看具体地址。

### 2. 构建并推送镜像

使用 Makefile（推荐）：`REGISTRY` 为仓库域名，`NAMESPACE` 为命名空间，`TAG` 为版本号。

```bash
# 示例：个人版杭州，命名空间为 mycompany，版本 1.0.0
make push REGISTRY=registry.cn-hangzhou.aliyuncs.com NAMESPACE=mycompany TAG=1.0.0
```

上述命令会先执行 `make build`，再给两个镜像打 tag 并 push。默认 `REGISTRY=registry.cn-hangzhou.aliyuncs.com`、`NAMESPACE=quantdinger`、`TAG=latest`，可按需覆盖：

```bash
make push
# 或指定地域与命名空间
make push REGISTRY=registry.cn-shanghai.aliyuncs.com NAMESPACE=mycompany TAG=v1.0
```

仅推送后端或前端：

```bash
make build
make push-backend REGISTRY=registry.cn-hangzhou.aliyuncs.com NAMESPACE=mycompany TAG=1.0.0
make push-frontend REGISTRY=registry.cn-hangzhou.aliyuncs.com NAMESPACE=mycompany TAG=1.0.0
```

### 3. 在目标机器拉取并运行

在已部署 PostgreSQL 的机器上，创建 `docker-compose.yml` 或直接运行容器时使用 ACR 镜像地址，例如：

```bash
docker pull registry.cn-hangzhou.aliyuncs.com/mycompany/quantdinger-backend:1.0.0
docker pull registry.cn-hangzhou.aliyuncs.com/mycompany/quantdinger-frontend:1.0.0
```

若使用 Compose，在 `docker-compose.yml` 中为 `backend` / `frontend` 指定 `image: <REGISTRY>/<NAMESPACE>/quantdinger-backend:<TAG>` 和 `quantdinger-frontend:<TAG>`，并去掉或注释 `build` 块即可。

## 生产/自定义部署提示

1. **DATABASE_URL**：在 `backend_api_python/.env` 中设置，指向已有的 PostgreSQL；Compose 通过 `env_file` 注入后端容器。
2. **前端 API 地址**：若前端与后端不在同一 Compose 网络中，需修改 `quantdinger_vue/deploy/nginx-docker.conf` 的 `proxy_pass`。
