# RAX3000QY OpenWrt 固件（PassWall + Xray）

为 **中国移动 RAX3000Q / RAX3000QY**（IPQ5018，128MB NAND / 256MB RAM）构建的 OpenWrt 固件，
基于 **ImmortalWrt 21.02（QSDK）**，内置 **PassWall + Xray**，带 **Wi-Fi** 与 **NSS 硬件加速**，
通过 GitHub Actions 云编译，无需本地环境。

## 特性

| 项目 | 说明 |
|---|---|
| 系统 | ImmortalWrt 21.02 + QSDK，Linux 5.4，包管理 `opkg` |
| 代理 | PassWall + `xray-core`（VLESS / VMess / Trojan / Shadowsocks） |
| 分流规则 | `v2ray-geoip` + `v2ray-geosite` |
| 无线 | IPQ5018（2.4G）+ QCN6102（5G），含板级 BDF |
| 硬件加速 | NSS offload（NAT + Wi-Fi） |
| 界面 | Argon 主题（`luci-app-argon-config` 可调），开机中文 |
| 设备兼容 | 同时支持 `cmcc,rax3000q` 与 `cmcc,rax3000qy` |
| 预装 | Argon 主题、中文语言包、`luci-app-ttyd` 网页终端 |

---

## 一、编译

1. Fork 本仓库（或直接使用）。
2. 仓库 **Settings → Actions → General → Workflow permissions** 选 **Read and write**
   （发布 Release 需要）。
3. **Actions** 页 → 选 `RAX3000QY 正式版 (PassWall + Xray / QSDK NSS)` → **Run workflow**。
4. 首次编译约 1～3 小时；之后有 ccache 缓存会明显更快。

### 产物

| 文件 | 用途 |
|---|---|
| `openwrt-ipq50xx-arm-cmcc_rax3000q-nand-factory.ubi` | **首次刷机**：经 U-Boot 网页刷入 |
| `openwrt-ipq50xx-arm-cmcc_rax3000q-nand-sysupgrade.bin` | **升级**：已在 OpenWrt 上刷，保留配置 |
| `config.final.txt` | 该固件的最终 `.config`，用于核对编进了哪些包 |

产物同时出现在 **Artifacts**（run 页底部）和 **Releases**（仓库首页右侧）。

---

## 二、刷机

**前提：机器已刷 NWrt U-Boot**（`nwrt_rax3000qy_uboot.mbn`）。U-Boot 与刷机方法见
[sfxfs/rax3000qy-OpenWrt](https://github.com/sfxfs/rax3000qy-OpenWrt)。

1. 电脑网卡设为静态 `192.168.1.8` / `255.255.255.0`，网线接路由器 LAN 口。
2. 断电，按住 **Reset** 上电，约 10 秒后松开。
3. 浏览器打开 `http://192.168.1.1` 进入 U-Boot 网页。
4. 上传 `*-nand-factory.ubi`，等待写入完成并自动重启。
5. 首次启动需 2～3 分钟（要格式化 overlay），之后访问 `http://192.168.10.1`。

> 已运行 OpenWrt 的机器，直接在 LuCI「系统 → 备份/升级」刷 `*-sysupgrade.bin` 即可保留配置。
> 若提示 `Image check failed`，用强制刷：`sysupgrade -F -n /tmp/xxx-sysupgrade.bin`。

### 出厂默认值

由 `files/etc/uci-defaults/99-kwrt-style` 在**首次启动**时写入（只执行一次）。

| 项 | 值 |
|---|---|
| 管理地址 | `http://192.168.10.1` |
| 用户名 / 密码 | `root` / `root` —— **登录后请立即修改** |
| 无线 | SSID `RAX3000`，2.4G + 5G 均开启，**无密码（开放网络）** |
| 主机名 / 时区 | `RAX3000QY` / Asia/Shanghai |
| LAN DHCP | 开启，从 `192.168.10.100` 起分配 |
| WAN | DHCP 客户端（网口：`1:wan`，`2/4/5:lan`） |

> ⚠️ 无线默认为开放网络，建议在「网络 → 无线」里加 WPA2 密码。
> 若光猫也使用 `192.168.10.1`，请先把 LAN 改到其它网段再接光猫。

---

## 三、PassWall 使用

菜单在 **服务 → PassWall**：

1. **节点列表**：用订阅链接或分享链接导入节点。
2. **全局设置 → 运行模式**：建议先用 `中国列表以外`。
3. **DNS**：`ChinaDNS-NG` 或 `Dnsmasq`；首次使用在 PassWall 里点一次「更新规则」拉取最新
   GeoIP / GeoSite 数据。
4. 透明代理所需的 `kmod-nft-tproxy` / `kmod-nft-socket` 已编进固件。

**协议支持**：Xray 原生支持 VLESS、VMess、Trojan、Shadowsocks，v2ray 订阅链接可直接导入。
唯一例外是 **ShadowsocksR（SSR）** —— Xray 不支持，需要 SSR 节点时请把
`scripts/diy-qsdk.sh` 里的 `INCLUDE_ShadowsocksR_Libev_Client` 改回 `=y` 再编译。

---

## 四、构建说明

| 项目 | 值 |
|---|---|
| 工作流 | `.github/workflows/build-qsdk-nss.yml` |
| 源码 | `kkstone/immortalwrt-ipq50xx` @ `openwrt-21.02` |
| 目标 | `ipq50xx / arm / cmcc_rax3000q` |
| 种子配置 | `configs/qsdk-nss.config` |

源码选择该分支的原因：官方主线缺少本机型（`cmcc_rax3000q`）的**板级 Wi-Fi BDF**，
且其 NAND 分区布局与本机使用的 NWrt U-Boot 不一致；ImmortalWrt/QSDK 分支与该 U-Boot 同源，
无线与 NSS 加速均可用。

构建时对上游做了四处必要的调整（均写在 `scripts/diy-qsdk.sh` 与工作流里）：

| 调整 | 原因 |
|---|---|
| `feeds/packages/lang/golang` 换成 `kenzok8/golang@1.25` | 上游自带 Go 1.19，而 xray-core 的 `go.mod` 要求 Go ≥ 1.20 |
| `SUPPORTED_DEVICES` 追加 `cmcc,rax3000qy` | 本机型实际 `board_name` 为 `rax3000qy`，否则 `sysupgrade` 会拒绝刷入 |
| 关闭 `v2ray-geodata` | 该包写死的 `dlc.dat` 数据源已失效（404），会导致编译失败；规则数据改用 `v2ray-geoip` / `v2ray-geosite` |
| 仅保留 `xray-core` | `v2ray-core` 体积约 20MB 且需额外一轮 Go 编译；Xray 已完全兼容 v2ray 协议与订阅 |

### 目录结构

```
Actions-OpenWrt-RAX3000Q/
├── .github/workflows/
│   └── build-qsdk-nss.yml        # 云编译工作流
├── files/                        # 打进固件的 overlay
│   └── etc/uci-defaults/99-kwrt-style   # 界面 / 网络 / 无线默认值
├── configs/
│   └── qsdk-nss.config           # 种子配置
├── scripts/
│   └── diy-qsdk.sh               # 包选择、PassWall/Xray 启用、精简无关插件
└── README.md
```

---

## 五、常见问题

| 现象 | 处理 |
|---|---|
| 刷完连不上（ping 不通 `192.168.10.1`） | 电脑设静态 `192.168.10.100`；等 2～3 分钟让首次启动跑完；换一个 LAN 口再试 |
| `Image check failed` | 镜像已包含 `cmcc,rax3000qy`；旧镜像用 `sysupgrade -F -n xxx.bin` |
| 刷完没有 Wi-Fi | 进「网络 → 无线」启用；默认 SSID 为 `RAX3000` |
| PassWall 节点能连但打不开网页 | 检查 DNS 模式、更新 GeoIP/GeoSite、确认路由器时间正确 |
| 界面不是 Argon | 检查 `config.final.txt` 里 `luci-theme-argon` 是否被选中；或执行 `uci set luci.main.mediaurlbase=/luci-static/argon && uci commit luci` |
| 编译报 `go.mod requires go >= 1.20` | 工作流已内置 Go 1.25 替换步骤 |
| 镜像超过 58MB 上限 | 精简 `scripts/diy-qsdk.sh` 里追加的包 |
| Release 403 | Settings → Actions → General → Workflow permissions 选 `Read and write` |

---

## 六、致谢

[OpenWrt](https://github.com/openwrt/openwrt)、[ImmortalWrt](https://github.com/immortalwrt)、
[Openwrt-Passwall](https://github.com/Openwrt-Passwall)、
[kkstone/Actions-OpenWrt-RAX3000Q](https://github.com/kkstone/Actions-OpenWrt-RAX3000Q)、
[P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)、
[sfxfs/rax3000qy-OpenWrt](https://github.com/sfxfs/rax3000qy-OpenWrt)（NWrt U-Boot 与刷机方法）。

本仓库只提供构建脚本与配置，不改动上游源码。刷机有风险，请自行备份原厂固件。
