#!/bin/bash
#
# 轨道 B（ImmortalWrt 21.02 / QSDK 5.4 / NSS）· DIY 脚本
#
# configs/qsdk-nss.config 来自参考仓库（RAX3000Q 已验证可用的完整 .config），
# 其中 luci-app-passwall 及其 INCLUDE_* 选项默认是关闭的，这里把它打开。
#
set -e

CONFIG_FILE="${CONFIG_FILE:-configs/qsdk-nss.config}"

if [ -f "$GITHUB_WORKSPACE/$CONFIG_FILE" ]; then
    cp "$GITHUB_WORKSPACE/$CONFIG_FILE" .config
elif [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" .config
else
    echo "!! 找不到配置文件 $CONFIG_FILE"
    exit 1
fi

echo "== 补 sysupgrade 镜像 + 兼容 cmcc,rax3000qy（本机实际 board_name）=="
IMG_MK="target/linux/ipq50xx/image/Makefile"
if [ -f "$IMG_MK" ]; then
python3 - "$IMG_MK" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
pat = re.compile(r'(define Device/cmcc_rax3000q\b[\s\S]*?)(\n\s*endef)')

def fix(m):
    body = m.group(1)
    # 设备块里的 IMAGES := nand-factory.ubi 覆盖了 Device/UbiFit 默认的
    # "nand-factory.ubi nand-sysupgrade.bin"，导致只出 factory 镜像——
    # 刷完以后每次升级都得进 U-Boot，这里补回 sysupgrade
    body2, k = re.subn(r'^(\s*)IMAGES := nand-factory\.ubi\s*$',
                       r'\1IMAGES := nand-factory.ubi nand-sysupgrade.bin',
                       body, count=1, flags=re.M)
    if k:
        print('  已补回 nand-sysupgrade.bin')
    elif 'nand-sysupgrade' in body:
        print('  已有 sysupgrade 镜像')
    else:
        body2 = body + '\n  IMAGES := nand-factory.ubi nand-sysupgrade.bin'
        print('  已追加 sysupgrade 镜像定义')
    if 'SUPPORTED_DEVICES' in body:
        return body2 + m.group(2)
    return body2 + '\n  SUPPORTED_DEVICES := cmcc,rax3000q cmcc,rax3000qy' + m.group(2)

new, n = pat.subn(fix, s, count=1)
if n:
    open(p, 'w').write(new)
    print('  已写入 SUPPORTED_DEVICES: cmcc,rax3000q cmcc,rax3000qy')
else:
    print('!! 没匹配到 define Device/cmcc_rax3000q，刷机请用 sysupgrade -F')
PY
else
    echo "!! 找不到 $IMG_MK（上游可能改路径）"
fi

echo "== 打开 PassWall =="
sed -i 's|^# CONFIG_PACKAGE_luci-app-passwall is not set|CONFIG_PACKAGE_luci-app-passwall=y|' .config

cat >> .config <<'EOF'

# ---- 由 diy-qsdk.sh 追加：Kwrt 风格界面（ImmortalWrt 21.02 feed 自带 Argon）----
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-i18n-opkg-zh-cn=y
CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

# ---- 由 diy-qsdk.sh 追加：PassWall / xray ----
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray=y
# 只保留 xray-core：xray 兼容 v2ray 协议与订阅；v2ray-core 体积约 20MB 且要用 Go
# 再编一遍（编译耗时翻倍），128MB NAND / 256MB RAM 的机器上没必要两个都编
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray is not set
# 注意：21.02 的 v2ray-geodata 写死了 dlc.dat.20231202050515，该 release 已 404，
# 开着会让整个编译失败（=m 也一样会被编译！）；21.02 源里又没有独立的
# v2ray-geoip / v2ray-geosite 包，所以固件内不含规则数据，
# 首次使用在 PassWall 里点「更新规则」在线拉取即可
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata is not set
# CONFIG_PACKAGE_v2ray-geodata is not set
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y
CONFIG_PACKAGE_xray-core=y
# CONFIG_PACKAGE_v2ray-core is not set
# 不需要的服务端组件，省体积
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server is not set

# ---- 精简：只要 PassWall + Xray，其余一律关掉（省体积、大幅缩短编译）----
# Xray 本身支持 VLESS / VMess / Trojan / Shadowsocks，所以这些独立客户端都不需要：
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Client is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Simple_Obfs is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Trojan_Plus is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Plugin is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Haproxy is not set
# 唯一例外是 ShadowsocksR（SSR）——Xray 不支持，用 SSR 节点就把上面 SSR 那行改回 =y

# 与 PassWall 无关的应用：连中文包一起关（只关应用的话，中文包会把它拉回来）
# CONFIG_PACKAGE_luci-app-zerotier is not set
# CONFIG_PACKAGE_luci-i18n-zerotier-zh-cn is not set
# CONFIG_PACKAGE_luci-app-frpc is not set
# CONFIG_PACKAGE_luci-i18n-frpc-zh-cn is not set
# CONFIG_PACKAGE_luci-app-upnp is not set
# CONFIG_PACKAGE_luci-i18n-upnp-zh-cn is not set
# CONFIG_PACKAGE_luci-app-autoreboot is not set
# CONFIG_PACKAGE_luci-i18n-autoreboot-zh-cn is not set
# CONFIG_PACKAGE_luci-app-watchcat is not set
# CONFIG_PACKAGE_luci-i18n-watchcat-zh-cn is not set
# 下面这些只选了中文包、应用本身没选，同样关掉避免反向拉入
# CONFIG_PACKAGE_luci-i18n-ddns-go-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-natmap-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-vlmcsd-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-wol-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-xlnetacc-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-filetransfer-zh-cn is not set
# CONFIG_PACKAGE_luci-i18n-turboacc-zh-cn is not set
# 保留：luci-app-ttyd（排障用的网页终端，很轻）+ Argon 主题与中文基础包
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y
EOF

# 一律关掉这些包：要么数据源已失效（v2ray-geodata），要么没必要编（v2ray-core）。
# 关键：必须同时匹配 =y 和 =m —— 只关 =y 的话，=m 的包照样会被编译并触发下载
sed -i 's|^CONFIG_PACKAGE_v2ray-geodata=[ym]|# CONFIG_PACKAGE_v2ray-geodata is not set|' .config
sed -i 's|^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata=[ym]|# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata is not set|' .config
# PassWall 开启 INCLUDE_V2ray 会通过依赖把 v2ray-core 拉进来，这里统一关掉只留 xray
sed -i 's|^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray=[ym]|# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray is not set|' .config
sed -i 's|^CONFIG_PACKAGE_v2ray-core=[ym]|# CONFIG_PACKAGE_v2ray-core is not set|' .config

# 种子配置里有大量 =m 的包：它们只生成 ipk、不会打进固件，但仍会被完整编译一遍，
# 既拖慢编译（这是上一版跑 2 小时的主要原因），又可能因为写死旧下载链接而失败
# （v2ray-geodata 就是这么挂的）。这里统一关掉，只保留真正要进固件的 =y 包
sed -i 's|^CONFIG_PACKAGE_\([A-Za-z0-9_.-]*\)=m$|# CONFIG_PACKAGE_\1 is not set|' .config
echo "  已关闭 =m 包（只保留 =y）：剩余待编译包数 = $(grep -c '^CONFIG_PACKAGE_.*=y' .config)"

echo "== make defconfig =="
make defconfig

echo "== 校验 =="
for p in luci-app-passwall xray-core; do
    if grep -q "^CONFIG_PACKAGE_${p}=y" .config; then
        echo "  OK  $p"
    else
        echo "::error::$p 未选中（该源码树里可能不存在此包）"
        exit 1
    fi
done

echo "== DIY 完成 =="
