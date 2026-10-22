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

echo "== 打开 PassWall =="
sed -i 's|^# CONFIG_PACKAGE_luci-app-passwall is not set|CONFIG_PACKAGE_luci-app-passwall=y|' .config

cat >> .config <<'EOF'

# ---- 由 diy-qsdk.sh 追加：Kwrt 风格界面（ImmortalWrt 21.02 feed 自带 Argon）----
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-i18n-opkg-zh-cn=y
CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y

# ---- 由 diy-qsdk.sh 追加：PassWall / v2ray / xray ----
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata=y
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_v2ray-core=y
CONFIG_PACKAGE_v2ray-geoip=y
CONFIG_PACKAGE_v2ray-geosite=y
# 不需要的内核/服务端组件，省体积
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server is not set
EOF

echo "== make defconfig =="
make defconfig

echo "== 校验 =="
for p in luci-app-passwall xray-core v2ray-core; do
    if grep -q "^CONFIG_PACKAGE_${p}=y" .config; then
        echo "  OK  $p"
    else
        echo "::error::$p 未选中（该源码树里可能不存在此包）"
        exit 1
    fi
done

echo "== DIY 完成 =="
