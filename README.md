# custom-routing-rules

Personal domain exceptions for Clash / sing-box. **Rules only — no proxy credentials.**

| Path | Consumer |
|------|----------|
| `clash/custom-{direct,reject,proxy}.yaml` | Mihomo / Stash `rule-providers` (`behavior: domain`) |
| `clash/wifi-calling-*.yaml`, `clash/apple-location.yaml` | Mihomo / Stash (`behavior: classical`) |
| `sing-box/*.json` | sing-box `rule_set` (`format: source`) |

Raw base: `https://raw.githubusercontent.com/xiaoqingwanga/custom-routing-rules/main/`

Consumers pull by `interval` (clients) or router cron (`NetworkTurbo` `scripts/update-singbox-rules.sh` → `/etc/sing-box/*.json`). **Push to `main` before expecting remote/cron refresh.**

## Buckets

| File | Role / intended outbound (wired in NetworkTurbo `confs/`) |
|------|-----------------------------------------------------------|
| `custom-direct` | → DIRECT |
| `custom-reject` | → REJECT |
| `custom-proxy` | → default `proxy` |
| `wifi-calling-us` | → `cog-us-lax-v4` |
| `wifi-calling-uk` | → `yunyoo-gb-ncl` |
| `apple-location` | → `yunyoo-gb-ncl` |
| `wifi-calling-hk` | ruleset only — not wired yet |

Outbound binding lives in NetworkTurbo `confs/`, not here.

---

## SOP: 日常例外域名（custom-*）

1. 在对应文件加/删域名：
   - Clash：`clash/custom-*.yaml` 的 `payload`（`+.example.com`）
   - sing-box：`sing-box/custom-*.json` 的 `domain_suffix`（无前导 `.`）
2. **两边必须同步**（同一批域名）。
3. `git commit` + `push` `main`。
4. 客户端等 `interval` 或手动更新 rule-providers；路由器等 cron / 手动跑 `update-rules.sh`（改完规则仓本身一般**不必**为 custom-* 重启，除非本地文件已换且服务要热加载——以路由器脚本为准：有变更会 restart）。

---

## SOP: 定期更新 Wi-Fi Calling / Apple location

**建议周期**：每季度，或换卡/WFC 挂掉时立刻查。

### 1. 对照上游与运营商资料

优先交叉看（不要只抄一份）：

- HenryChiao [`Wi-Fi_Calling_rule-set`](https://github.com/HenryChiao/the_clash_ruleset/tree/main/The_Location_rule-set/Wi-Fi_Calling_rule-set) / `apple-location.list`
- 厂商 QoS 列表：Omada / Aruba Wi-Fi Calling DNS patterns
- 网关目录：[Netify mobile gateways](https://www.netify.ai/resources/mobile-gateways)（按国家 MCC）
- 论坛/实测（如某 MVNO 实际解析到的 ePDG）

按地区维护：`wifi-calling-us` / `-uk` / `-hk`；`apple-location` 目前只有 `gspe1-ssl.ls.apple.com`。

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

- 不要用过宽的 `DOMAIN-KEYWORD`（易误伤）。
- 不要全局 `DST-PORT,500/4500`（会匹配所有 IKE）。
- 注释里写清运营商 / MCC-MNC / 来源日期，方便下次 diff。

### 4. 发布与生效

1. 本仓 `commit` + `push` `main`。
2. **NetworkTurbo**：若只改域名/IP、出站不变 → 客户端自动拉；路由器跑 / 等 `update-singbox-rules.sh`（会下载并在有变更时重启 sing-box）。
3. 若要**改出站或新建桶并接线**：改 NetworkTurbo `confs/`（`singbox-router.json` / `clash.yaml` / `stash.yaml`）+ 视需要改 `update-singbox-rules.sh` 的 `CUSTOMS` 列表，再按路由器部署流程备份 → 上传 → `sing-box check` → 重启一次。

### 5. 快速自检

- [ ] clash 与 sing-box 条目一致  
- [ ] 无 `127.0.0.1` / 明显垃圾域名  
- [ ] 已 push；路由器/客户端能拉到新内容  
- [ ] HK 等「仅 ruleset」桶：不要误接到 `confs/`，除非明确要接线  
