# RAX3000QY OpenWrt 固件

为 **中国移动 RAX3000Q / RAX3000QY**（IPQ5018）构建的 OpenWrt 固件，
带 **Wi-Fi** 与 **NSS 硬件加速**，界面为 **Argon 中文主题**，通过 GitHub Actions 云编译。

## 特性

| 项目 | 说明 |
|---|---|
| 无线 | IPQ5018（2.4G）+ QCN6102（5G） |
| 硬件加速 | NSS offload（NAT + Wi-Fi） |
| 界面 | Argon 主题，开机中文 |
| 软件中心 | **iStore** —— 一级菜单，可在线搜索安装插件 |
| 设置向导 | 「系统 → 设置向导」一键切换：正常路由 / 旁路由 / 无线接入点 |
| 网络检测 | 显示出口 IP、归属地与国内外站点连通性 |
| 附带 | `luci-app-ddns-go` 动态域名、`luci-app-ttyd` 网页终端 |
| 系统兼容 | 同时支持 `cmcc,rax3000q` 与 `cmcc,rax3000qy` |

---

## 一、编译

1. Fork 本仓库（或直接使用）。
2. 仓库 **Settings → Actions → General → Workflow permissions** 选 **Read and write**。
3. **Actions** 页 → 选 `RAX3000QY 固件编译` → **Run workflow**。
4. 首次编译约 1～3 小时；产物在 run 页底部的 **Artifacts** 与仓库首页的 **Releases**。

| 产物 | 用途 |
|---|---|
| `*-nand-factory.ubi` | **首次刷机**：经 U-Boot 网页刷入 |
| `*-nand-sysupgrade.bin` | **升级**：已在 OpenWrt 上时刷，保留配置 |

---

## 二、刷机

**前提：机器已刷 NWrt U-Boot**（`nwrt_rax3000qy_uboot.mbn`），
U-Boot 与刷机方法见 [sfxfs/rax3000qy-OpenWrt](https://github.com/sfxfs/rax3000qy-OpenWrt)。

1. 电脑设为静态 `192.168.1.8` / `255.255.255.0`，网线接路由器 LAN 口。
2. 断电，按住 **Reset** 上电，约 10 秒后松开。
3. 浏览器打开 `http://192.168.1.1` 进入 U-Boot 网页。
4. 上传 `*-nand-factory.ubi`，等待写入完成并自动重启。
5. 首次启动需 2～3 分钟，之后访问 `http://192.168.10.1`。

> 已运行 OpenWrt 的机器，直接在 LuCI「系统 → 备份/升级」刷 `*-sysupgrade.bin` 即可保留配置。

### 出厂默认值

首次启动时写入（只执行一次）。

| 项 | 值 |
|---|---|
| 管理地址 | `http://192.168.10.1` |
| 用户名 / 密码 | `root` / `root` —— **登录后请立即修改** |
| 无线 | SSID `RAX3000`，2.4G + 5G 已开启，**无密码（开放网络）** |
| 主机名 / 时区 | `RAX3000QY` / Asia/Shanghai |
| LAN DHCP | 开启，从 `192.168.10.100` 起分配 |
| WAN | DHCP 客户端（网口：`1:wan`，`2/4/5:lan`） |

> ⚠️ 无线默认为开放网络，建议在「网络 → 无线」里加 WPA2 密码。
> 若光猫也使用 `192.168.10.1`，请先把 LAN 改到其它网段再接光猫。

---

## 三、使用

### 网络检测

**服务 → 网络检测**：显示当前出口 IP、国家 / 地区、城市、运营商，
以及国内（baidu.com）与国外（google.com）站点是否连通，点「重新检测」可刷新。

### 设置向导

**系统 → 设置向导**，选择后保存即自动应用并重启网络：

| 模式 | 说明 |
|---|---|
| 正常路由 | LAN 开启 DHCP，WAN 自动获取（默认） |
| 旁路由 | 关闭 DHCP，LAN 设静态 IP，网关指向主路由 |
| 无线接入点 | 关闭 DHCP 与防火墙，当作交换机使用 |

### iStore

**一级菜单 iStore**，可在线浏览并安装插件，无需命令行。

### DDNS-Go

**服务 → DDNS-Go**，填入服务商与令牌即可使用动态域名。

---

## 四、常见问题

| 现象 | 处理 |
|---|---|
| 刷完连不上（ping 不通 `192.168.10.1`） | 电脑设静态 `192.168.10.100`；等 2～3 分钟让首次启动跑完；换一个 LAN 口再试 |
| `Image check failed` | 镜像已包含 `cmcc,rax3000qy`；旧镜像用 `sysupgrade -F -n xxx.bin` |
| 刷完没有 Wi-Fi | 进「网络 → 无线」启用；默认 SSID 为 `RAX3000` |
| 界面不是 Argon | 执行 `uci set luci.main.mediaurlbase=/luci-static/argon && uci commit luci` |
| Release 发布失败（403） | Settings → Actions → General → Workflow permissions 选 `Read and write` |

---

## 致谢

[OpenWrt](https://github.com/openwrt/openwrt)、[ImmortalWrt](https://github.com/immortalwrt)、
[kkstone/Actions-OpenWrt-RAX3000Q](https://github.com/kkstone/Actions-OpenWrt-RAX3000Q)、
[P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)、
[sfxfs/rax3000qy-OpenWrt](https://github.com/sfxfs/rax3000qy-OpenWrt)。

刷机有风险，请自行备份原厂固件。
