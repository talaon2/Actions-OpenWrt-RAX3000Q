#!/bin/bash
#
# 轨道 A · DIY 第一部分（在 ./scripts/feeds install -a 之前执行）
#
# 作用：官方 packages feed 里与 PassWall 上游重名的包版本偏旧（甚至已停更），
#      这里先把它们从 feed 里删掉，避免「同名包两份」导致 feeds install/编译冲突。
#      PassWall 需要的依赖稍后由 diy-mainline-part2.sh 从上游仓库直接拉取。
#
set -e

CONFLICT_PKGS="
xray-core
xray-plugin
v2ray-core
v2ray-geodata
v2ray-plugin
sing-box
chinadns-ng
dns2socks
hysteria
ipt2socks
microsocks
naiveproxy
shadowsocks-rust
shadowsocksr-libev
simple-obfs
tcping
geoview
shadow-tls
smartdns
"

echo "== 清理官方 feed 中与 PassWall 上游重名的包 =="
for p in $CONFLICT_PKGS; do
    found=$(find feeds -maxdepth 4 -type d -name "$p" 2>/dev/null || true)
    if [ -n "$found" ]; then
        echo "  移除: $found"
        # shellcheck disable=SC2086
        rm -rf $found
    fi
done

# 官方 luci feed 里若有旧版 passwall 也一并清掉
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2

echo "== DIY 第一部分完成 =="
