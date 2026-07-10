# Docker 饥荒联机版专用服务器

使用自建镜像和 Docker Compose 部署《饥荒联机版》（Don't Starve Together）地面与洞穴双分片服务器。服务器文件由 SteamCMD 官方匿名账号下载，世界数据通过宿主机目录挂载持久化。

## 前置条件

- Linux x86_64 主机
- Docker Engine 与 Docker Compose v2
- 建议至少 4 GB 内存、15 GB 可用磁盘
- 一个有效的 Klei 集群 Token
- 防火墙放行游戏端口 `10999/udp`、`11000/udp`，Steam 查询端口 `27018/udp`、`27019/udp`，认证端口 `8768/udp`、`8769/udp`（如修改 `.env`，使用修改后的端口）

## 快速开始

```bash
make init
```

1. 编辑 `.env`，设置服务器名、密码、人数等参数。
2. 登录 [Klei 游戏服务器页面](https://accounts.klei.com/account/game/servers?game=DontStarveTogether)，创建集群并将 Token 原样写入 `secrets/cluster_token.txt`。
3. 启动服务器：

```bash
make up
make logs
```

首次启动需要下载并校验专用服务器，耗时取决于网络。看到地面和洞穴分片完成加载后，即可在游戏服务器列表中搜索 `.env` 里的 `SERVER_NAME`。

> `secrets/cluster_token.txt`、`.env`、存档和备份都已被 Git 忽略。不要提交这些内容。

## 常用命令

```bash
make status       # 查看容器与健康状态
make logs         # 跟随两个分片的日志
make stop         # 停止游戏分片，保留容器和数据
make down         # 删除容器和网络，保留命名卷
make restart      # 停服、检查更新并依次启动两个分片
make update       # 与 restart 相同，执行 SteamCMD validate
make config       # 展开并验证 Compose 配置
```

请使用 `make update` 更新运行中的服务器，不要只重启其中一个分片，以免地面和洞穴短暂处于不同版本。

## 配置

常用设置位于 `.env`。每次执行 `make up` 或 `make update` 时，`prepare` 服务会生成原生 `cluster.ini` 与两个分片的 `server.ini`。

世界生成参数分别位于：

- `config/Master/worldgenoverride.lua`
- `config/Caves/worldgenoverride.lua`

这些模板会在准备阶段复制到集群目录。修改世界生成选项通常只影响新世界；已有世界需要按游戏规则重置后才会重新生成。

地面模板默认设置 `healthpenalty = "none"`，关闭复活造成的最大生命值惩罚。该选项由地面分片控制并自动同步到洞穴，修改后重启现有世界即可生效。

### Workshop 模组

1. 在 `config/mods/dedicated_server_mods_setup.lua` 中为每个模组添加：

   ```lua
   ServerModSetup("378160973")
   ```

2. 在 `config/mods/modoverrides.lua` 中启用并配置同一个模组：

   ```lua
   return {
     ["workshop-378160973"] = {
       enabled = true,
       configuration_options = {},
     },
   }
   ```

3. 执行 `make restart`。两个分片共享同一份模组配置。

模组 ID 来自 Steam Workshop 页面 URL。模组不兼容或配置字段错误时，请先查看 `make logs` 的 Lua 错误。

## 备份与恢复

创建一致性备份会短暂停止两个分片，归档只包含必须保留的集群配置、世界和玩家数据，不包含可由 SteamCMD 重新下载的程序文件：

```bash
make backup
```

备份和 SHA-256 文件保存到 `backups/`。

恢复指定备份：

```bash
make restore BACKUP=backups/dst-cluster-20260101T120000Z.tar.gz
```

恢复前会自动创建 `pre-restore-*.tar.gz` 安全备份，并拒绝包含绝对路径或目录穿越项的归档。恢复完成后会重新校验服务器并应用当前配置模板。

## 数据与网络布局

- `data/server/`：挂载到容器的 `/opt/dst`，保存 SteamCMD 下载的服务端和模组；可删除后重新下载。
- `data/cluster/`：挂载到容器的 `/data`，保存集群配置、Token、世界和玩家存档；必须备份。
- `backups/`：宿主机上的压缩备份。
- `master`：公开地面游戏端口，并在内部网络监听分片协调端口。
- `caves`：公开洞穴游戏端口，通过服务名 `master` 加入集群。

删除容器不会删除存档，因为数据保存在宿主机的 `data/` 目录。删除 `data/cluster/` 会永久删除世界和玩家数据，请谨慎操作。

## 排障

- **Token 错误或缺失**：检查 `secrets/cluster_token.txt`，文件中只应有 Klei 提供的 Token。
- **服务器无法搜索到**：确认 UDP 端口已在云安全组和主机防火墙中开放，并查看地面分片日志。
- **洞穴未连接**：运行 `docker compose logs caves master`，检查 Master 是否健康以及 `SHARD_MASTER_PORT` 是否被意外修改。
- **SteamCMD 下载失败**：确认主机可访问 Steam CDN，然后重新执行 `make update`。
- **权限错误**：镜像入口会将 `data/server/` 和 `data/cluster/` 调整为容器中的默认 UID/GID 10001；宿主机普通用户可能需要 `sudo` 才能直接读取其中部分文件。
