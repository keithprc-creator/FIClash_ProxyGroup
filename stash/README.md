# Stash Overrides

iOS Stash 客户端的覆写（Override）配置文件，托管在公开 raw URL 供 Stash 直接下载。

## 工作原理

Stash 不支持在 App 内本地编辑覆写 YAML，必须提供一个公网可访问的 URL。Stash 会从 URL 下载覆写文件，每次订阅更新时自动重新拉取并合并到订阅配置上，不会被订阅刷新冲掉。

## 当前覆写列表

| 文件 | 用途 | Raw URL |
|---|---|---|
| `linkedin-asia.yaml` | LinkedIn 走亚太节点（JP/TW/HK/SG/KR），DIRECT 兜底 | `https://raw.githubusercontent.com/keithprc-creator/FIClash_ProxyGroup/main/stash/linkedin-asia.yaml` |
| `onedrive-auto.yaml` | OneDrive 全球节点自动测速选最快（亚太+北美+欧洲），DIRECT 兜底 | `https://raw.githubusercontent.com/keithprc-creator/FIClash_ProxyGroup/main/stash/onedrive-auto.yaml` |
| `teams-direct.yaml` | Microsoft Teams 默认 DIRECT，可通过 Teams-Nodes 手动切换订阅节点 | `https://raw.githubusercontent.com/keithprc-creator/FIClash_ProxyGroup/main/stash/teams-direct.yaml` |

## 添加覆写步骤

1. 在 Stash iOS App 中：**配置** → 选中订阅 → 右上角"…" → **覆写**
2. 点击 **添加覆写**
3. 粘贴上表中的 raw URL
4. 点击 **下载**
5. 下拉刷新订阅，覆写生效

## YAML 格式说明

Stash 覆写遵循 Clash YAML 规范，关键字段：

- `proxy-groups` — 新增/覆盖代理组（同名会覆盖订阅里的）
- `rules` — 默认 prepend 在订阅规则之前
- `include-all: true` + `filter: <regex>` — 自动从订阅拉取匹配关键词的节点
- 列表中第一个节点会成为 select 组的默认选项

## 与 FIClash 的差异

| 维度 | FIClash (macOS) | Stash (iOS) |
|---|---|---|
| 覆写编辑 | 本地 SQLite + UI | 必须远程 URL |
| 合并机制 | profile_rule_mapping 表的 scene='prepend' | YAML 字段合并 + rules 默认 prepend |
| 订阅更新影响 | 数据库覆写存活 | 远程 URL 重新拉取后合并 |

Teams 使用两层选择组：外层 `Teams` 显式列出 `DIRECT`（默认）和 `Teams-Nodes`，内层 `Teams-Nodes` 用 `include-all: true` 加载订阅节点，避免在同一组中混用自动加载与显式选项。已有覆写请重新下载并重新加载配置；在 `Teams` 中选择 `DIRECT` 即可直连，需要代理时选择 `Teams-Nodes` 并在该组内选节点。

Teams 分流域名参考 [Microsoft 365 官方端点文档](https://learn.microsoft.com/en-us/microsoft-365/enterprise/urls-and-ip-address-ranges?view=o365-worldwide)。登录、Office/SharePoint 等共享服务及仅通过 IP 连接的媒体流量不一定会命中这些域名规则。
