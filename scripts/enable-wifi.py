#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
轨道 A：把上游默认 disabled 的 Wi-Fi 节点重新打开（实验性）。

背景：上游在 ipq5018-rax3000q.dts 里写着
    //256M RAM is too small for ath11k, so WiFi is disabled to prevent OOM.
    &q6v5_wcss { status = "disabled"; };
    &wifi      { status = "disabled"; };   // IPQ5018 2.4G
    &wifi1     { status = "disabled"; };   // QCN6102 5G

做法：在设备 DTS 末尾追加 overlay（后出现的 status 覆盖先前的），
      幂等、不改动任何原有节点。
注意：上游没有提供该机型的板级 BDF（ipq-wifi-cmcc_rax3000q），
      Wi-Fi 能否真正启动取决于 ath11k 固件能否匹配到校准数据，属于实验性功能。

用法：python3 enable-wifi.py <openwrt 源码根目录>
环境变量：ENABLE_WIFI=false 时跳过
"""

import os
import re
import sys

DTS_REL = "target/linux/qualcommax/dts/ipq5018-rax3000q.dts"
MARKER = "/* rax3000q: re-enable wifi (build script) */"
CANDIDATES = ("q6v5_wcss", "wifi", "wifi1")


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    path = os.path.join(root, DTS_REL)

    if not os.path.isfile(path):
        print("[enable-wifi] 找不到 %s（上游可能改了路径/文件名）" % DTS_REL)
        return 1

    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()

    if MARKER in text:
        print("[enable-wifi] 已存在 overlay，跳过")
        return 0

    labels = []
    for label in CANDIDATES:
        m = re.search(r"&%s\s*\{(.*?)\n\};" % re.escape(label), text, re.S)
        if m and re.search(r'status\s*=\s*"disabled"', m.group(1)):
            labels.append(label)

    if not labels:
        print("[enable-wifi] 没有发现被禁用的 Wi-Fi 节点（上游可能已改为默认开启），不做修改")
        return 0

    with open(path, "a", encoding="utf-8") as f:
        f.write("\n%s\n" % MARKER)
        for label in labels:
            f.write('&%s {\n\tstatus = "okay";\n};\n' % label)

    print("[enable-wifi] 已重新打开: %s" % ", ".join(labels))
    return 0


if __name__ == "__main__":
    if os.environ.get("ENABLE_WIFI", "1").lower() in ("0", "false", "no"):
        print("[enable-wifi] ENABLE_WIFI=false，跳过")
        sys.exit(0)
    sys.exit(main())
