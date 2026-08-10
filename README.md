# custom-routing-rules

Personal domain exceptions for Clash / sing-box. **Rules only — no proxy credentials.**

| Path | Consumer |
|------|----------|
| `clash/custom-{direct,reject,proxy}.yaml` | Mihomo / Stash `rule-providers` (`behavior: domain`) |
| `clash/apple-direct.yaml` | Mihomo / Stash (`behavior: domain`) — Apple download CDNs → DIRECT |
| `clash/steam-direct.yaml` | Mihomo / Stash (`behavior: domain`) — Steam download CDNs → DIRECT |
| `clash/wifi-calling-*.yaml`, `clash/apple-location.yaml` | Mihomo / Stash (`behavior: classical`) |
| `sing-box/*.json` | sing-box `rule_set` (`format: source`) |

Raw base: `https://raw.githubusercontent.com/xiaoqingwanga/custom-routing-rules/main/`

Consumers pull by `interval` (clients) or router cron (`NetworkTurbo` `scripts/update-singbox-rules.sh` → `/etc/sing-box/*.json`). **Push to `main` before expecting remote/cron refresh.**

## Buckets

| File | Role / intended outbound (wired in NetworkTurbo `confs/`) |
|------|-----------------------------------------------------------|
| `custom-direct` | → DIRECT（杂项例外；不含 Apple / Steam 下载 CDN） |
| `apple-direct` | → DIRECT（Apple **下载 CDN** 白名单，非整站 `apple.com`） |
| `steam-direct` | → DIRECT（Steam **下载 CDN**：`steamcontent.com` / `steamserver.net`） |
| `custom-reject` | → REJECT |
| `custom-proxy` | → default `proxy` |
| `wifi-calling-us` | → `cog-us-lax-v4` |
| `wifi-calling-uk` | → `jjfly-gb-lwt`（经 `yunyoo-de-fra`） |
| `wifi-calling-de` | → `yunyoo-de-fra` |
| `wifi-calling-ch` | → `yunyoo-de-fra` |
| `apple-location` | → `jjfly-gb-lwt`（经 `yunyoo-de-fra`） |
| `wifi-calling-hk` | ruleset only — not wired yet |

Outbound binding lives in NetworkTurbo `confs/`, not here. **新建桶**（如 `apple-direct` / `steam-direct`）除本仓文件外，还需改 NetworkTurbo：`rule-providers` / `rule_set` 接线 + `update-singbox-rules.sh` 的 `CUSTOMS`。

---

## SOP: 日常例外域名（custom-*）

1. 在对应文件加/删域名：
   - Clash：`clash/custom-*.yaml` 的 `payload`（`+.example.com`）
   - sing-box：`sing-box/custom-*.json` 的 `domain_suffix`（无前导 `.`）
2. **两边必须同步**（同一批域名）。
3. `git commit` + `push` `main`。
4. 客户端等 `interval` 或手动更新 rule-providers；路由器等 cron / 手动跑 `update-rules.sh`（改完规则仓本身一般**不必**为 custom-* 重启，除非本地文件已换且服务要热加载——以路由器脚本为准：有变更会 restart）。

Apple / Steam 下载 CDN **不要**写进 `custom-direct`，见下方对应 SOP。

---

## SOP: 定期更新 Wi-Fi Calling / Apple location

**建议周期**：每季度，或换卡/WFC 挂掉时立刻查。

### 1. 对照上游与运营商资料

优先交叉看（不要只抄一份）：

- HenryChiao [`Wi-Fi_Calling_rule-set`](https://github.com/HenryChiao/the_clash_ruleset/tree/main/The_Location_rule-set/Wi-Fi_Calling_rule-set) / `apple-location.list`
- 厂商 QoS 列表：Omada / Aruba Wi-Fi Calling DNS patterns
- 网关目录：[Netify mobile gateways](https://www.netify.ai/resources/mobile-gateways)（按国家 MCC）
- 论坛/实测（如某 MVNO 实际解析到的 ePDG）

按地区维护：`wifi-calling-us` / `-uk` / `-de` / `-ch` / `-hk`；`apple-location` 目前为 `gspe1-ssl.ls.apple.com`、`gspe79-ssl.ls.apple.com`。

**自动化（只读）**：NetworkTurbo `scripts/security-summary.sh` 会拉取上述上游 + 本仓已发布规则，对 ours 做 DoH，并对「上游有、我们没有」的候选再 DoH。HenryChiao / Omada 上仍存活的缺口记 `WARN: MISSING`；Netify 噪声记 `INFO`；上游死域名（NXDOMAIN / `127.0.0.1` / NO_A）**自动跳过**并缓存约 7 天（`~/.cache/networkturbo/wfc-dead-domains.tsv`）。若死域名已在本仓规则里则仍 WARN。写入/push 仍手工。该 SOP 与 `apple-direct` / `steam-direct` SOP 一样，**默认至少间隔 3 天**才再跑（戳记 `~/.cache/networkturbo/sop-last-run-wifi-calling`）；`--force-sop` 或 `FORCE_RULESET_SOP=1` 可强制。

### 2. 解析校验（必做）

对每个候选 **ePDG FQDN** 做 DoH（勿盲信列表）：

```bash
# 例：Cloudflare DoH
curl -sH 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=epdg.epc.mnc033.mcc234.pub.3gppnetwork.org&type=A'
```

| 结果 | 处理 |
|------|------|
| 公网 A 记录 | 可加入（记 IP，可选补 `IP-CIDR`） |
| `NXDOMAIN` / 无 A | **不要**加入 |
| A = `127.0.0.1`（或同类占位） | **不要**加入（未开通/废弃 MNC 的常见坑） |

MVNO（如 CTExcel）往往**没有**自有 ePDG，而是宿主网（如 EE `mnc030/033/071`）；以实测 FQDN 为准，不要为品牌名硬编域名。

### 3. 写入规则（双格式）

同一逻辑写两份：

| | Clash (`behavior: classical`) | sing-box (`format: source`) |
|--|-------------------------------|-----------------------------|
| 域名 | `DOMAIN-SUFFIX,example.com` | `domain_suffix: ["example.com"]` |
| IP | `IP-CIDR,x.x.x.x/y,no-resolve` | `ip_cidr: ["x.x.x.x/y"]` |

注意：

- **每个运营商块必须带消费网站**（`DOMAIN-SUFFIX` / `domain_suffix`），不只 ePDG。
- 不要用过宽的 `DOMAIN-KEYWORD`（易误伤）。
- 不要全局 `DST-PORT,500/4500`（会匹配所有 IKE）。
- 注释里写清运营商 / MCC-MNC / 来源日期，方便下次 diff。
- 品牌不明、又找不到官网的 ePDG：**不要单独成块**（可丢弃或等确认后再加）。

### 4. 发布与生效

1. 本仓 `commit` + `push` `main`。
2. **NetworkTurbo**：若只改域名/IP、出站不变 → 客户端自动拉；路由器跑 / 等 `update-singbox-rules.sh`（会下载并在有变更时重启 sing-box）。
3. 若要**改出站或新建桶并接线**：改 NetworkTurbo `confs/`（`singbox-router.json` / `clash.yaml` / `stash.yaml`）+ 视需要改 `update-singbox-rules.sh` 的 `CUSTOMS` 列表，再按路由器部署流程备份 → 上传 → `sing-box check` → 重启一次。

### 5. 快速自检

- [ ] clash 与 sing-box 条目一致  
- [ ] 无 `127.0.0.1` / 明显垃圾域名  
- [ ] 已 push；路由器/客户端能拉到新内容  
- [ ] HK 等「仅 ruleset」桶：不要误接到 `confs/`，除非明确要接线  

---

## SOP: 检查 Apple 直连（apple-direct）

**文件**：`clash/apple-direct.yaml` + `sing-box/apple-direct.json`（`behavior: domain` / `domain_suffix`）。  
**策略**：大文件下载 → `apple-direct`（DIRECT）；App Store / Apple ID **登录与商店 API** → 不写本桶，落到 NetworkTurbo 默认 `proxy`（`MATCH`）。  
**禁止**整站 `+.apple.com` / `apple.com`；**禁止**把 Apple CDN 塞回 `custom-direct`。

**建议周期**：每半年，或 Apple 企业网络文档大改、系统大版本更新下不动包、App Store 安装异常时立刻查。

**自动化（只读）**：NetworkTurbo `scripts/security-summary.sh` 的 `apple-direct` SOP：拉已发布 clash + sing-box → 双格式同步 → 反模式（禁整站 `apple.com` / `itunes`·`apps`·`idmsa` 等）→ DoH ours → 检查是否漏回 `custom-direct`。戳记 `~/.cache/networkturbo/sop-last-run-apple-direct`，**默认至少间隔 3 天**；`--force-sop` / `FORCE_RULESET_SOP=1` 强制。对照 [101555](https://support.apple.com/en-us/101555) 增删域名仍手工。

### 1. 对照官方清单

主源：[Use Apple products on enterprise networks](https://support.apple.com/en-us/101555)（HT211152）。重点看这几节表格：

| 章节 | 直连候选（下载/CDN） | 应留给 proxy（勿塞进 apple-direct） |
|------|----------------------|--------------------------------------|
| Software updates | `updates(.cdn-apple)`、`swcdn` / `swdist` / `swdownload`、`appldnld`、`oscdn` / `osrecovery` 等 | `mesu` / `gdmf` / `swscan` 等**目录**；`xp` / `gg` / `gs` 等小流量 API |
| Apps and additional content | `*.mzstatic.com`；`audiocontentdownload`；`download.developer` / `devimages-cdn`；`playgrounds-*`；`sylvan` | `*.itunes.apple.com`、`*.apps.apple.com`（商店 API / 区服） |
| Apple Account | — | `idmsa` / `account` / `gsa` / `appleid.cdn-apple.com`（登录；`cdn-apple` 后缀已直连时静态资源会直连，可接受） |
| iCloud | `*.icloud-content.com`；`*.cdn-apple.com`（面宽，含更新包） | 一般 `*.icloud.com` API（整站勿直连） |

官方标 **Supports proxies: —** 且描述为 downloads / Store content CDN 的，优先考虑进本桶。

### 2. 本仓应对齐的条目

Clash / sing-box **同一批**。当前应大致覆盖：

- 后缀：`mzstatic.com`、`cdn-apple.com`、`icloud-content.com`
- 主机：`appldnld` / `swcdn` / `swdist` / `swdownload` / `oscdn` / `osrecovery`、`download.developer` / `devimages-cdn`、`audiocontentdownload`、`sylvan`、`playgrounds-cdn` / `playgrounds-assets-cdn`（注意官方现为 **playgrounds** 复数）

文档新增「明显大文件」主机时：只加下载侧；**不要**为了省事写 `+.apple.com`。

### 3. 解析抽查（可选）

对拟新增或可疑的 FQDN 做 DoH（与 WFC SOP 相同手法）。能解析再写入；`NXDOMAIN` 不写。

```bash
curl -sH 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=updates.cdn-apple.com&type=A'
```

### 4. 行为自检（改完或巡检时）

| 流量 | 期望 |
|------|------|
| App / 系统更新 / Xcode 组件包体 | DIRECT（`apple-direct`） |
| App Store 登录、购买、商店页 API | proxy（`itunes` / `apps` / `idmsa` 等） |
| `apple-location` / Wi‑Fi Calling | 专用规则优先于 `apple-direct`（出站在 NetworkTurbo `confs/`） |

### 5. 发布

双格式改完 → `commit` + `push` `main` → 客户端 `interval` / 路由器 `update-singbox-rules.sh`（须已含 `apple-direct.json`）。  
若 NetworkTurbo 尚未接线本桶：改 `confs/` + `CUSTOMS` 后再部署路由器配置。

### 6. 快速自检

- [ ] 条目只在 `apple-direct`，不在 `custom-direct`  
- [ ] 无整站 `apple.com`  
- [ ] clash ↔ sing-box 条目一致  
- [ ] 无 `itunes.apple.com` / `apps.apple.com` / `idmsa.apple.com` 等登录·API  
- [ ] 对照过 [101555](https://support.apple.com/en-us/101555) 近期 changelog（页底 Recent changes）  
- [ ] 已 push；`update-singbox-rules.sh` / 客户端能拉到新内容  

---

## SOP: 检查 Steam 直连（steam-direct）

**文件**：`clash/steam-direct.yaml` + `sing-box/steam-direct.json`（`behavior: domain` / `domain_suffix`）。  
**策略**：游戏包下载 → `steam-direct`（DIRECT）；商店 / 登录 / 社区 → 不写本桶，落到默认 `proxy`。  
**禁止**把 Steam CDN 塞回 `custom-direct`；**禁止**把 `steampowered.com` / `steamcommunity.com` / `cm.steampowered.com` 等登录·商店域塞进本桶。

**建议周期**：每半年，或 Steam 客户端大改、下载异常走代理时立刻查。

**自动化（只读）**：NetworkTurbo `scripts/security-summary.sh` 的 `steam-direct` SOP（同步 / 反模式 / DoH / 漏回检查）。戳记 `~/.cache/networkturbo/sop-last-run-steam-direct`，**默认至少间隔 3 天**；`--force-sop` / `FORCE_RULESET_SOP=1` 强制。

### 1. 对照来源

| 来源 | 用途 |
|------|------|
| [uklans/cache-domains](https://github.com/uklans/cache-domains) `steam.txt` | Lancache：下载高度收拢到 `steamcontent.com` |
| [v2fly `data/steam`](https://github.com/v2fly/domain-list-community/blob/master/data/steam) | 全量 Steam 域（含商店/社区/国区）；只摘下载 CDN |

### 2. 本仓应对齐

- 国际下载核心：`steamcontent.com`、`steamserver.net`
- 国区专用 CDN（`dl.steam.clngaa.com`、`st.dl.*`、`steamchina.com` 等）默认**不加**（国际账号用不上）
- 商店/登录留给 proxy：`steampowered.com`、`steamcommunity.com`、`cm.steampowered.com`、`steamstatic.com` 等

### 3. 发布与自检

双格式改完 → `commit` + `push` → 客户端 / `update-singbox-rules.sh`（须已含 `steam-direct.json`）。

- [ ] 条目只在 `steam-direct`，不在 `custom-direct`  
- [ ] clash ↔ sing-box 一致  
- [ ] 无商店/登录域  
- [ ] 已 push；消费者能拉到新内容  
