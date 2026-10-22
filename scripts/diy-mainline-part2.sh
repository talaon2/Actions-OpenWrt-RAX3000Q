#!/bin/bash
#
# 轨道 A · DIY 第二部分（在 ./scripts/feeds install -a 之后执行）
#
# 作用：
#   1. 从 Openwrt-Passwall 上游拉取 luci-app-passwall 与它依赖的软件包
#   2. 载入种子配置 configs/mainline.config
#   3. make defconfig 展开成完整 .config
#
set -e

PASSWALL_LUCI_REPO="https://github.com/Openwrt-Passwall/openwrt-passwall.git"
PASSWALL_PKGS_REPO="https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git"

# Kwrt 风格界面：Argon 主题（新 LuCI 架构版本，仓库内自带 compat/luci-app-argon-config）
ARGON_REPO="https://github.com/jerrykuku/luci-theme-argon.git"

echo "== 拉取 PassWall 上游 =="
rm -rf package/passwall-luci package/passwall-packages
git clone --depth 1 "$PASSWALL_LUCI_REPO" package/passwall-luci
git clone --depth 1 "$PASSWALL_PKGS_REPO" package/passwall-packages
# 构建树不需要这两个仓库的 .git（体积大且无意义）
rm -rf package/passwall-luci/.git package/passwall-packages/.git

echo "== 拉取 Argon 主题（Kwrt 风格界面）=="
rm -rf package/luci-theme-argon package/luci-app-argon-config
git clone --depth 1 "$ARGON_REPO" package/luci-theme-argon
rm -rf package/luci-theme-argon/.git
# 新版仓库把 luci-app-argon-config 放在 compat/ 下，单独拿出来便于打包成独立 ipk/apk
if [ -d package/luci-theme-argon/compat/luci-app-argon-config ]; then
    cp -a package/luci-theme-argon/compat/luci-app-argon-config package/luci-app-argon-config
    rm -rf package/luci-theme-argon/compat
fi

echo "== 打开 nftables 透明代理所需的内核模块 =="
# PassWall 的 nftables 模式依赖 kmod-nft-tproxy / kmod-nft-socket / kmod-nft-nat，
# 而主线 generic + ipq50xx 的内核配置默认没开这些符号，不开的话 kmod 包是空的
KCFG="target/linux/qualcommax/ipq50xx/config-default"
if [ -f "$KCFG" ]; then
    for sym in CONFIG_NFT_TPROXY=m CONFIG_NFT_SOCKET=m CONFIG_NFT_NAT=m \
               CONFIG_NETFILTER_XT_TARGET_TPROXY=m CONFIG_NF_TPROXY_IPV4=m CONFIG_NF_TPROXY_IPV6=m; do
        name="${sym%%=*}"
        if grep -q "^${name}=" "$KCFG"; then
            echo "  已存在: $name"
        else
            echo "  追加: $sym"
            echo "$sym" >> "$KCFG"
        fi
    done
else
    echo "!! 找不到 $KCFG（上游可能改了路径），请手动确认 nftables tproxy 内核模块"
fi

echo "== 载入种子配置 =="
[ -f "$GITHUB_WORKSPACE/$CONFIG_FILE" ] || {
    echo "!! 找不到配置文件 $CONFIG_FILE"
    exit 1
}
cp "$GITHUB_WORKSPACE/$CONFIG_FILE" .config

echo "== make defconfig =="
make defconfig

echo "== 检查配置里请求的包是否都被接受 =="
MISSING=""
for pkg in $(grep -oE '^CONFIG_PACKAGE_[^=]+=y' "$GITHUB_WORKSPACE/$CONFIG_FILE" \
             | sed 's/^CONFIG_PACKAGE_//; s/=y$//'); do
    grep -q "^CONFIG_PACKAGE_${pkg}=y" .config || MISSING="$MISSING $pkg"
done
if [ -n "$MISSING" ]; then
    echo "::warning::以下包名未被接受（名字写错或该 feed 不存在）:$MISSING"
else
    echo "所有请求的包均已选中"
fi

echo "== DIY 第二部分完成 =="
