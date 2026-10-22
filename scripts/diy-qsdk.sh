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

echo "== 让镜像同时兼容 cmcc,rax3000qy（这台机器实际的 board_name）=="
IMG_MK="target/linux/ipq50xx/image/Makefile"
if [ -f "$IMG_MK" ]; then
python3 - "$IMG_MK" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
if 'rax3000qy' in s:
    print('  已包含 rax3000qy')
else:
    pat = re.compile(r'(define Device/cmcc_rax3000q\b[\s\S]*?)(\n\s*endef)')
    new, n = pat.subn(lambda m: m.group(1) +
        '\n  SUPPORTED_DEVICES := cmcc,rax3000q cmcc,rax3000qy' + m.group(2), s, count=1)
    if n:
        open(p, 'w').write(new)
        print('  已追加 SUPPORTED_DEVICES: cmcc,rax3000q cmcc,rax3000qy')
    else:
        print('!! 没匹配到 define Device/cmcc_rax3000q，刷机时请用 sysupgrade -F')
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

# ---- 由 diy-qsdk.sh 追加：PassWall / v2ray / xray ----
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Xray=y
CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray=y
# 注意：21.02 的 v2ray-geodata 写死了 dlc.dat.20231202050515，数据源已 404，
# 开着它会让整个编译失败；改由 v2ray-geoip / v2ray-geosite 提供规则数据，
# 装好后可在 PassWall 里点「更新规则」在线拉取最新 geodata
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata is not set
CONFIG_PACKAGE_luci-i18n-passwall-zh-cn=y
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_v2ray-core=y
CONFIG_PACKAGE_v2ray-geoip=y
CONFIG_PACKAGE_v2ray-geosite=y
# 不需要的内核/服务端组件，省体积
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_Shadowsocks_Libev_Server is not set
# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_ShadowsocksR_Libev_Server is not set
EOF

# 参考配置里可能直接选了 v2ray-geodata，一律关掉（数据源 404）
sed -i 's|^CONFIG_PACKAGE_v2ray-geodata=y|# CONFIG_PACKAGE_v2ray-geodata is not set|' .config
sed -i 's|^CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata=y|# CONFIG_PACKAGE_luci-app-passwall_INCLUDE_V2ray_Geodata is not set|' .config

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
