#!/usr/bin/env bash
# 校验 apps/ 下 7 个预编译 APK 的 SHA-256。
# 缺文件或哈希不符都会以非零码退出，避免把错版本编进 ROM。
set -euo pipefail
cd "$(dirname "$0")/../apps"

[ -f SHA256SUMS ] || { echo "找不到 apps/SHA256SUMS"; exit 1; }

missing=0
while read -r _ name; do
    [ -n "$name" ] || continue
    if [ ! -f "$name" ]; then
        echo "MISSING   $name"
        missing=1
    fi
done < SHA256SUMS

if [ "$missing" -ne 0 ]; then
    echo
    echo "先把缺失的 APK 放进 apps/（来源见 apps/README.md），再重跑本脚本。"
    exit 1
fi

sha256sum -c SHA256SUMS
echo
echo "OK：7 个预编译 APK 全部匹配。"
