# FlClash Script Override (脚本模式覆写)

FlClash (macOS/Windows) 通过**脚本模式**追加自定义代理组和规则。订阅更新后自动保持，无需手动维护。

## 为什么用脚本模式而不是 SQLite

FlClash v0.8.93+ 有三种覆写模式：

| 模式 | 能力 | 适用场景 |
|---|---|---|
| **标准** | 仅追加规则（prepend） | 只需加分流规则，不改组 |
| **脚本** | JS 函数修改完整配置 | 需要追加代理组 + 规则 |
| **自定义** | 完全替换订阅组和规则 | 不依赖订阅组，全手搓 |

**关键发现**：SQLite `proxy_groups` 表有数据时会触发"自定义"模式，**完全替换**订阅的所有代理组（而非追加）。这导致订阅里的 Default Proxy / US Fixed IP 等组全部消失。

脚本模式（JS 覆写函数）是唯一能在保留订阅组的同时追加自定义组的方式。

## 使用方式

1. 打开 FlClash
2. 配置 → 点击订阅右侧的"更多" → **覆写**
3. 选择 **脚本** 标签
4. 将 `override.js` 的内容粘贴进编辑器
5. 点击右上角保存图标
6. 回到代理页面，自定义组即时生效

## 当前脚本功能

`override.js` 包含以下覆写：

### 策略组

| 组名 | 类型 | 说明 |
|---|---|---|
| Qoder | select | DIRECT 默认 + 亚太节点 (JP/TW/SG/HK) |
| OneDrive | select | 外层手动切换（默认 Auto / DIRECT / 所有节点） |
| OneDrive Auto | url-test (hidden) | 全部节点自动选最快，180s 间隔，50ms 容差 |
| LinkedIn | select | 同 OneDrive 结构 |
| LinkedIn Auto | url-test (hidden) | 同 OneDrive Auto |

### 规则 (prepend)

```
PROCESS-NAME,Qoder,Qoder
PROCESS-NAME,QoderWork,Qoder
PROCESS-NAME,qodercli,Qoder
DOMAIN-SUFFIX,onedrive.com,OneDrive
DOMAIN-SUFFIX,onedrive.live.com,OneDrive
DOMAIN-SUFFIX,1drv.com,OneDrive
DOMAIN-SUFFIX,1drv.ms,OneDrive
DOMAIN-SUFFIX,sharepoint.com,OneDrive
DOMAIN-SUFFIX,storage.live.com,OneDrive
DOMAIN-KEYWORD,onedrive,OneDrive
DOMAIN-SUFFIX,linkedin.com,LinkedIn
DOMAIN-SUFFIX,licdn.com,LinkedIn
DOMAIN-SUFFIX,linkedin.cn,LinkedIn
DOMAIN-SUFFIX,lnkd.in,LinkedIn
DOMAIN-KEYWORD,linkedin,LinkedIn
```

## 自定义/扩展

### 添加新的服务组

在 `override.js` 中仿照 OneDrive 结构添加：

```javascript
// 在 proxy-groups 数组中加入:
{
  name: "MyService",
  type: "select",
  proxies: ["MyService Auto", "DIRECT", ...allProxies]
},
{
  name: "MyService Auto",
  type: "url-test",
  proxies: allProxies,
  url: "http://www.gstatic.com/generate_204",
  interval: 180,
  tolerance: 50,
  hidden: true
},

// 在 rules 数组中加入:
"DOMAIN-SUFFIX,myservice.com,MyService",
"DOMAIN-KEYWORD,myservice,MyService",
```

### 只想要特定地区节点参与测速

```javascript
// 例如 OneDrive 只走美国节点:
const usFilter = /(?:US)/i;
const onedriveAutoProxies = allProxies.filter(n => usFilter.test(n));
```

## 注意事项

- 脚本覆写在每次订阅更新后自动重新执行，无需手动操作
- `config["proxy-groups"]` 使用展开运算符 `...` 保留订阅原有组
- 自定义组 prepend 到数组最前面，会显示为 tab 栏左侧
- `hidden: true` 的 url-test 组不会占用 tab 栏位置
- 规则 prepend 到最前面，优先匹配（覆盖订阅中同域名的规则）
