# FIClash ProxyGroup Override Guide

How to add custom proxy groups (e.g. "Qoder") in FIClash (FlClash) that persist across subscription updates.

## Solutions

| 方案 | 目录 | 平台 | 推荐程度 |
|---|---|---|---|
| **[脚本模式覆写](script/)** | `script/` | FlClash macOS/Windows | **推荐** — 保留订阅组 + 追加自定义组 |
| [SQLite 数据库覆写](#solution-database-override--api-reload) | `setup_qoder_proxy_group.sh` | FlClash macOS/Windows | ⚠️ v0.8.93 有已知问题 |
| [Stash iOS 覆写](stash/) | `stash/` | Stash iOS | 适用于 iOS |

> **⚠️ SQLite 方案注意**：FlClash v0.8.93 中 `proxy_groups` 表有数据时会触发"自定义"模式，**完全替换**订阅的代理组（而非追加）。推荐使用脚本模式覆写代替。

---

## Problem

FIClash manages subscription-based configs. Directly editing the profile YAML gets overwritten on next subscription update. We need a way to inject custom proxy groups and rules that survive updates.

## Solution: Database Override + API Reload

FIClash stores override data in a SQLite database alongside the subscription profile. When FIClash regenerates its config, it merges database overrides with the subscription data.

### Architecture

```
┌─────────────────────────────────────────────────┐
│  FIClash Config Directory                        │
│  ~/Library/Application Support/com.follow.clash/ │
│                                                  │
│  ├── database.sqlite  ← override storage         │
│  ├── config.yaml      ← merged running config    │
│  └── profiles/        ← subscription YAMLs       │
│       └── {profile_id}.yaml                      │
└─────────────────────────────────────────────────┘
```

### Database Schema (Override Tables)

```sql
-- Custom proxy groups
CREATE TABLE proxy_groups (
  id INTEGER PRIMARY KEY,
  profile_id INTEGER REFERENCES profiles(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL,          -- "select", "url-test", "fallback", etc.
  proxies TEXT,                -- JSON array: '["DIRECT", "proxy-name"]'
  include_all_proxies INTEGER, -- 1 = auto-include all proxies from subscription
  filter TEXT,                 -- regex to filter included proxies
  "order" TEXT                 -- lexicographic sort key ("a0", "a1", ...)
);

-- Custom rules
CREATE TABLE rules (
  id INTEGER PRIMARY KEY,
  rule_action TEXT NOT NULL,   -- "PROCESS-NAME", "DOMAIN-SUFFIX", "IP-CIDR", etc.
  content TEXT,                -- match value: "Qoder", "example.com", "8.8.8.8/32"
  rule_target TEXT,            -- target proxy group name
  no_resolve INTEGER DEFAULT 0,
  src INTEGER DEFAULT 0
);

-- Map rules to profiles (controls ordering)
CREATE TABLE profile_rule_mapping (
  id TEXT PRIMARY KEY,         -- unique string ID
  profile_id INTEGER REFERENCES profiles(id),
  rule_id INTEGER REFERENCES rules(id),
  scene TEXT,                  -- "prepend" = before subscription rules
  "order" TEXT                 -- lexicographic sort within scene
);
```

### Clash Meta API (port 9090)

```
GET  /version             -- verify API is reachable
GET  /proxies             -- list all proxy groups and their state
GET  /proxies/{name}      -- get specific group details
PUT  /proxies/{name}      -- switch selected proxy in a group
GET  /rules               -- list all active rules
PUT  /configs?force=true  -- reload config from file (body: {"path": "..."})
GET  /configs             -- get current running config
```

## Example: Route Qoder Traffic via Custom Group

### Goal

- Create a "Qoder" proxy group (type: select)
- Default to DIRECT
- Include JP/TW/SG nodes for optional manual switching
- Match Qoder/QoderWork/qodercli processes via PROCESS-NAME rules
- Persist across subscription updates

### Step 1: Find Profile ID

```bash
sqlite3 ~/Library/Application\ Support/com.follow.clash/database.sqlite \
  "SELECT id, label FROM profiles;"
```

### Step 2: Insert Proxy Group

```bash
PROFILE_ID=305548707309293568  # replace with your profile ID

sqlite3 ~/Library/Application\ Support/com.follow.clash/database.sqlite "
INSERT INTO proxy_groups (profile_id, name, type, proxies, include_all_proxies, filter, \"order\")
VALUES ($PROFILE_ID, 'Qoder', 'select', '[\"DIRECT\"]', 1, '(?i)(JP|TW|SG|HK)', 'a0');
"
```

**Parameters explained:**
- `proxies: '["DIRECT"]'` — DIRECT is always available and listed first (becomes default)
- `include_all_proxies: 1` — automatically pull in proxies from the subscription
- `filter: '(?i)(JP|TW|SG|HK)'` — only include nodes matching these region keywords

### Step 3: Insert Rules

```bash
sqlite3 ~/Library/Application\ Support/com.follow.clash/database.sqlite "
INSERT INTO rules (rule_action, content, rule_target, no_resolve, src)
VALUES ('PROCESS-NAME', 'Qoder', 'Qoder', 0, 0);

INSERT INTO rules (rule_action, content, rule_target, no_resolve, src)
VALUES ('PROCESS-NAME', 'QoderWork', 'Qoder', 0, 0);

INSERT INTO rules (rule_action, content, rule_target, no_resolve, src)
VALUES ('PROCESS-NAME', 'qodercli', 'Qoder', 0, 0);
"
```

### Step 4: Map Rules to Profile (Prepend)

```bash
sqlite3 ~/Library/Application\ Support/com.follow.clash/database.sqlite "
-- Get the rule IDs just inserted
INSERT INTO profile_rule_mapping (id, profile_id, rule_id, scene, \"order\")
SELECT 'qoder-rule-' || id, $PROFILE_ID, id, 'prepend', 'a' || (id - 1)
FROM rules WHERE rule_target = 'Qoder';
"
```

### Step 5: Apply to Running Config

After database changes, also update `config.yaml` and reload:

```bash
# Add proxy group to config.yaml (insert before first existing group)
# Add rules to top of rules section
# Then reload:
curl -X PUT "http://127.0.0.1:9090/configs?force=true" \
  -H "Content-Type: application/json" \
  -d '{"path": "'"$HOME/Library/Application Support/com.follow.clash/config.yaml"'"}'
```

### Step 6: Verify

```bash
# Check proxy group exists
curl -s http://127.0.0.1:9090/proxies/Qoder | python3 -m json.tool

# Check rules are prepended
curl -s http://127.0.0.1:9090/rules | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data['rules'][:5]:
    print(f\"{r['type']},{r['payload']},{r['proxy']}\")
"
```

Expected output:
```
ProcessName,Qoder,Qoder
ProcessName,QoderWork,Qoder
ProcessName,qodercli,Qoder
DstPort,8080,DIRECT
DomainSuffix,localhost,DIRECT
```

## Switching Proxy via API

```bash
# Switch Qoder group to a JP node
curl -X PUT "http://127.0.0.1:9090/proxies/Qoder" \
  -H "Content-Type: application/json" \
  -d '{"name": "JP-X5-1"}'

# Switch back to DIRECT
curl -X PUT "http://127.0.0.1:9090/proxies/Qoder" \
  -H "Content-Type: application/json" \
  -d '{"name": "DIRECT"}'
```

## Notes

- **Process names on macOS** (confirmed via `ps aux`): `Qoder`, `QoderWork`, `qodercli`
- **Why PROCESS-NAME over IP-CIDR**: Qoder backend IPs change frequently; process matching is stable
- **Clash Meta version**: 1.10.0 (mihomo) — supports PROCESS-NAME rules with `find-process-mode: always`
- **FIClash version**: FlClash v0.8.93
- **If override doesn't survive update**: Recreate via FIClash UI "Override" tab as fallback; the DB approach is reverse-engineered from schema
- **Backup**: Always backup `database.sqlite` before modifying

## Quick Reference: config.yaml Override Format

If inserting directly into config.yaml (for immediate runtime use):

```yaml
proxy-groups:
  - name: "Qoder"
    type: select
    proxies:
      - "DIRECT"
      - "JP-X5-1"
      - "JP-X5-2"
      # ... all JP/TW/SG nodes
    # OR use include-all with filter (if supported by FlClash's config merge):
    # include-all-proxies: true
    # filter: "(?i)(JP|TW|SG|HK)"

rules:
  # Prepend these BEFORE all other rules
  - "PROCESS-NAME,Qoder,Qoder"
  - "PROCESS-NAME,QoderWork,Qoder"
  - "PROCESS-NAME,qodercli,Qoder"
```
