# Actions-OpenWrt-RAX3000Q（集成 PassWall + Xray/v2ray）

用 GitHub Actions 给 **CMCC RAX3000Q / RAX3000QY** 云编译固件，参考
[kkstone/Actions-OpenWrt-RAX3000Q](https://github.com/kkstone/Actions-OpenWrt-RAX3000Q)
与 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 的骨架。

固件预置：**LuCI 中文界面 + PassWall + Xray（兼容 v2ray 协议/订阅）**，并根据你选的分支
额外带上 **v2ray-core**、Wi-Fi、NSS 加速等能力。

界面采用 **Kwrt 风格**：默认 **Argon 主题**（毛玻璃 + 明暗模式 + 可换登录页背景），
开机即为中文，默认主机名 `RAX3000Q`、时区 `Asia/Shanghai`。

---

## 一、两条编译轨道（选一条跑就行）

| | **轨道 A：官方 mainline（推荐，内核最新）** | 轨道 B：ImmortalWrt 21.02 + QSDK 5.4 |
|---|---|---|
| 工作流 | `.github/workflows/build-mainline.yml` | `.github/workflows/build-qsdk-nss.yml` |
| 源码 | `openwrt/openwrt` **main**（snapshot，内核 6.x） | `kkstone/immortalwrt-ipq50xx` `openwrt-21.02` |
| 设备符号 | `qualcommax / ipq50xx / cmcc_rax3000q` | `ipq50xx / arm / cmcc_rax3000q` |
| 包管理 | `apk` | `opkg` |
| Wi-Fi | ⚠️ 实验性：上游因 256MB 内存把 DTS 里的 Wi-Fi 关闭了，且**没有板级 BDF**；工作流可打补丁打开，但不保证能用 | ✅ IPQ5018（2.4G）+ QCN6102（5G），有板级 BDF |
| NSS 硬件加速 | ❌（官方主线未合入 offload 栈） | ✅ NAT + Wi-Fi NSS |
| 界面 | Argon 主题（jerrykuku 新版，ucode 架构）+ `luci-app-argon-config` | Argon 主题（ImmortalWrt feed 自带，Lua 架构） |
| PassWall 核心 | `xray-core`（PassWall 上游已不再维护 v2ray-core） | `xray-core` + `v2ray-core` 都编入 |
| 产物 | `*squashfs-factory.ubi` / `*squashfs-sysupgrade.bin` | `*nand-factory.ubi` / `*nand-sysupgrade.bin` |

> **怎么选**
> - 想要**最新内核 + 官方长期维护**、只用有线：跑 **轨道 A**。
> - 想要**Wi-Fi 和 NSS 加速**（家用路由器必需）：跑 **轨道 B**。

两条轨道各有一处必要的"补丁"（已写进工作流/脚本，出处见括号）：
- 轨道 A：主线 ipq50xx 的内核配置默认**没有** `NFT_TPROXY` / `NFT_SOCKET` / `NFT_NAT`，
  不开的话 `kmod-nft-tproxy` 是空包、PassWall 透明代理跑不起来 →
  `scripts/diy-mainline-part2.sh` 会往 `config-default` 追加这几个符号。
- 轨道 B：ImmortalWrt 21.02 自带的 golang 是 **1.19**，而 xray-core 1.8.3 /
  v2ray-core 5.7.0 的 go.mod 要求 **go ≥ 1.20**，不换会直接编译失败 →
  工作流把 `feeds/packages/lang/golang` 换成 `kenzok8/golang@1.25`。

---

## 二、怎么用（3 步）

1. 把本目录推到一个 GitHub 仓库（私有仓库也行）：

   ```bash
   cd Actions-OpenWrt-RAX3000Q
   git init && git add -A && git commit -m "init"
   git remote add origin git@github.com:<你的用户名>/Actions-OpenWrt-RAX3000Q.git
   git push -u origin main
   ```

2. 打开仓库 **Actions** 页 → 选择工作流 → `Run workflow`：
   - `A-OpenWrt mainline (RAX3000Q + PassWall)`
     - `ref` 留空 = 跟随官方 main 最新（也可填某个提交号固定版本）
     - `wifi` 默认 `true`（打补丁打开 Wi-Fi，实验性；想完全按上游默认就设 `false`）
     - `ssh` 勾选可开 tmate 远程调试
   - `B-ImmortalWrt QSDK NSS (RAX3000Q + PassWall)` → 带 Wi-Fi/NSS 的固件

   首次编译约 2～4 小时（免费额度足够），之后有 ccache 会快一些。

3. 从 **Artifacts** 或 **Releases** 下载镜像，进 U-Boot 网页刷入（见下）。

---

## 三、刷机（前置：已刷第三方 / NWrt U-Boot）

1. 网线接路由器的 **LAN1**，电脑 IP 设为 `192.168.1.8`（或自动获取）。
2. 浏览器打开 `http://192.168.1.1` 进 U-Boot 网页。
3. 上传对应镜像：
   - 轨道 A：`*squashfs-factory.ubi`
   - 轨道 B：`*nand-factory.ubi`
4. 刷完断电重启，等 2～3 分钟（首次启动要格式化 overlay），然后浏览器访问
   `http://192.168.10.1`，用 `root` / `root` 登录。

### 固件出厂默认值（首次启动自动写入，见 `files/etc/uci-defaults/99-kwrt-style`）

| 项 | 值 |
|---|---|
| 管理地址 | `http://192.168.10.1` |
| 用户名 / 密码 | `root` / `root`（**务必登录后立刻改掉**） |
| 无线 | SSID `RAX3000`，2.4G + 5G 均开启，**无密码**（开放网络，建议进「网络 → 无线」加 WPA2） |
| 主机名 / 时区 | `RAX3000QY` / Asia/Shanghai |
| LAN DHCP | 开，从 `192.168.10.100` 起分配 |
| WAN | DHCP 客户端（网口按源码定义：`1:wan`，`2/4/5:lan`） |

> ⚠️ 风险提示：刷固件有变砖风险。本机（RAX3000QY）用的是
> [sfxfs/rax3000qy-OpenWrt](https://github.com/sfxfs/rax3000qy-OpenWrt) 里那套 NWrt
> U-Boot（`nwrt_rax3000qy_uboot.mbn`）。刷不死靠的是 U-Boot，但**分区布局必须匹配**：
> 轨道 A（主线 OpenWrt）的 NAND 布局与这套 U-Boot 不一致，实测刷入后无法启动，
> **请刷轨道 B**（ImmortalWrt/QSDK 体系，与该 U-Boot 同源）。
>
> 已经跑着 OpenWrt 的系统，可直接在 LuCI「备份/升级」里刷 `*sysupgrade.bin`；
> 新版镜像已把 `cmcc,rax3000qy` 写进 `SUPPORTED_DEVICES`，不会再报
> `Device cmcc,rax3000qy not supported by this image`。

---

## 四、PassWall / v2ray 说明

* 固件里 **PassWall 菜单在「服务 → PassWall」**，首次进入后：
  - 「节点列表」按订阅链接或分享链接导入节点（VMess / VLESS / Trojan / SS 等）；
  - 「全局设置 → 运行模式」建议先用 `中国列表以外`；
  - 「DNS」建议 `ChinaDNS-NG` 或 `Dnsmasq`，并更新一次 GeoIP/GeoSite 数据。
* **关于 v2ray**：上游 [Openwrt-Passwall](https://github.com/Openwrt-Passwall/openwrt-passwall)
  自 2026 年起已把 v2ray-core 合并到 **Xray-core**（协议完全向后兼容：VMess、VLESS、
  Trojan、SS、v2ray 订阅链接都能直接用）。  所以轨道 A 只装 `xray-core`。
  * 轨道 B 同样**只装 `xray-core`**：`v2ray-core` 体积约 20MB，且要用 Go 再编译一遍
    （编译时间几乎翻倍），在这台 128MB NAND / 256MB RAM 的机器上不划算，而 xray
    能直接吃 v2ray 订阅链接。确实需要 v2ray-core 的话，把 `scripts/diy-qsdk.sh` 里的
    `INCLUDE_V2ray` 与 `CONFIG_PACKAGE_v2ray-core` 改回 `=y` 再编。
  * 规则数据用 `v2ray-geoip` / `v2ray-geosite`（`v2ray-geodata` 的数据源已 404，
    开了会直接编译失败）。若 PassWall 提示缺少 geo 数据，在 PassWall 里点一次
    「更新规则」在线拉取即可。
* PassWall 依赖 `kmod-nft-tproxy` / `kmod-nft-socket`，是**编进固件**的（不是后装），
  所以请不要指望装官方源的 kmod 包能匹配（内核 vermagic 不同），用户态包不受影响。
* 256MB 内存 + 约 58MB 镜像上限的设备，别额外塞太多插件；要加插件建议从源码改
  `configs/mainline.config` 后重新跑一次 Actions。

### 界面（Kwrt 风格）怎么调

* 登录页背景、主色、明暗模式：**系统 → Argon 配置**（`luci-app-argon-config`）。
  想省资源就把背景图关掉、动画减弱。
* 换回原生主题：
  `uci set luci.main.mediaurlbase=/luci-static/bootstrap && uci commit luci`
* 默认主题/中文/主机名/时区由 `files/etc/uci-defaults/99-kwrt-style` 在**首次启动**时写入，
  只跑一次；已经跑过的机器改这个文件不会生效，需手动改或重刷。
* 256MB 内存的机器上 Argon 的毛玻璃+背景图会略占资源，卡顿就在 Argon 配置里把
  blur/transparency 调到 0、背景图留空。

---

## 五、目录结构

```
Actions-OpenWrt-RAX3000Q/
├── .github/workflows/
│   ├── build-mainline.yml        # 轨道 A：官方 mainline + PassWall(Xray)
│   └── build-qsdk-nss.yml        # 轨道 B：ImmortalWrt 21.02/QSDK + PassWall(Xray)
├── files/                        # 打进固件的 overlay（Kwrt 风格默认设置）
│   └── etc/uci-defaults/99-kwrt-style
├── configs/
│   ├── mainline.config           # 轨道 A 种子配置（目标设备 + 要装的包）
│   └── qsdk-nss.config           # 轨道 B 完整配置（来自参考仓库，已验证）
├── scripts/
│   ├── diy-mainline-part1.sh     # A：清理官方 feed 中与 PassWall 重名的旧包
│   ├── diy-mainline-part2.sh     # A：拉取 PassWall 上游 + 载入配置
│   ├── diy-qsdk.sh               # B：载入配置 + 打开 PassWall/v2ray
│   └── enable-wifi.py            # A：给 DTS 追加 overlay 重新打开 Wi-Fi
└── README.md
```

---

## 六、常见问题

| 现象 | 处理 |
|---|---|
| 轨道 A 编译报某个 `kmod-*` 缺失 | 官方 main 偶尔改名，等上游修复或把 `ref` 固定到已知可用的提交 |
| 轨道 A 刷完没有 Wi-Fi | 预期内：上游缺 `ipq-wifi-cmcc_rax3000q` BDF，请改用轨道 B |
| 镜像超过 58MB 上限 | 少装插件（关掉 `INCLUDE_SingBox`/`Hysteria`/`V2ray_Geodata` 等） |
| PassWall 节点能连但打不开网页 | 检查 DNS 模式、更新 GeoIP/GeoSite、确认路由器时间正确 |
| 界面还是原生 bootstrap | 检查 `luci-theme-argon` 是否真的被选中（看 `config.final.txt`），或手动执行上面的 uci 命令 |
| 轨道 B 报 `go.mod requires go >= 1.20` | 工作流已把 golang 换成 1.25；若仍失败，在 `scripts/diy-qsdk.sh` 里把 `INCLUDE_Xray` 改成 `is not set` 只保留 v2ray |
| 轨道 A 报 `lyaml`/`luci-compat` 缺失 | 官方源偶尔改包名，固定 `ref` 到已知可用的提交再编 |
| Release 403 | 仓库 Settings → Actions → General → Workflow permissions 选 `Read and write` |

---

## 七、致谢

[OpenWrt](https://github.com/openwrt/openwrt)、[ImmortalWrt](https://github.com/immortalwrt)、
[Openwrt-Passwall](https://github.com/Openwrt-Passwall)、
[kkstone/Actions-OpenWrt-RAX3000Q](https://github.com/kkstone/Actions-OpenWrt-RAX3000Q)、
[P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)、
[sfxfs/rax3000qy-OpenWrt](https://github.com/sfxfs/rax3000qy-OpenWrt)（NWrt U-Boot 与刷机方法）。

本仓库只提供构建脚本与配置，不改动上游源码。
