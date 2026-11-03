#!/usr/bin/env bash
#
# 直接从 OTA zip 里核对产物内容（不依赖刷机）。
#
#   tools/verify-image.sh lineage-23.2-XXXX-UNOFFICIAL-virtio_x86_64.zip
#
# 发布物里的 .iso / .img 只是安装介质，真正的系统在 OTA 的 payload.bin 里。
# 这里用构建出来的 ota_extractor 解出 product / system 分区，再用 debugfs 读文件，
# 不需要 root、不需要挂载 loop 设备（容器里通常也没有 /dev/loop*）。
#
# 需要环境变量 ANDROID_BUILD_TOP 指向源码树根（lunch 之后就有）。
set -uo pipefail

ZIP=${1:?用法: tools/verify-image.sh <lineage-*.zip>}
TOP=${ANDROID_BUILD_TOP:-$(pwd)}
EXT="$TOP/out/host/linux-x86/bin/ota_extractor"
AAPT="${AAPT2:-$TOP/out/host/linux-x86/bin/aapt2}"

[ -x "$EXT" ] || { echo "找不到 $EXT（先编一次，或导出 ANDROID_BUILD_TOP）"; exit 1; }

W=$(mktemp -d /tmp/verify-img.XXXXXX)
trap 'rm -rf "$W"' EXIT

echo "== 解 payload =="
unzip -o -q "$ZIP" payload.bin -d "$W" || { echo "zip 里没有 payload.bin"; exit 1; }
mkdir -p "$W/img"
"$EXT" --payload="$W/payload.bin" --output_dir="$W/img" --partitions=product,system >/dev/null 2>&1

P="$W/img/product.img"
S="$W/img/system.img"
fail=0
ok()  { printf '  OK    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }

# debugfs 列目录 / 导出文件；目录不存在时返回空
lsdir() { debugfs -R "ls -l $2" "$1" 2>/dev/null | awk '{print $NF}' | grep -vE '^\.\.?$' | tr '\n' ' '; }
extract() { debugfs -R "dump $2 $3" "$1" >/dev/null 2>&1; }

echo "== 替换应用与工具 =="
APP=$(lsdir "$P" /app)
PRIV=$(lsdir "$P" /priv-app)
for m in Calendula ConnectYou; do
    case "$APP" in *"$m"*) ok "/product/app/$m";; *) bad "/product/app/$m 缺失";; esac
done
for m in GmsCore Obtainium F-Droid F-DroidPrivilegedExtension DAVx5; do
    case "$PRIV" in *"$m"*) ok "/product/priv-app/$m";; *) bad "/product/priv-app/$m 缺失";; esac
done

echo "== 应当不存在的应用 =="
# 既没有预装包目录，也要确认旧应用真的没在别处
SYSAPP=$(lsdir "$S" /system/app)
SYSPRIV=$(lsdir "$S" /system/priv-app)
ALL="$APP $PRIV $SYSAPP $SYSPRIV"
for m in Firefox Etar Jelly Contacts; do
    case "$ALL" in *"$m"*) bad "$m 仍在包里";; *) ok "$m 不存在";; esac
done

echo "== 外观覆盖层（RRO） =="
OVL=$(lsdir "$P" /overlay)
for m in CalendulaLabelOverlay ConnectYouLabelOverlay; do
    case "$OVL" in
        *"$m"*)
            extract "$P" "/overlay/$m/$m.apk" "$W/$m.apk"
            if "$AAPT" dump resources "$W/$m.apk" 2>/dev/null | grep -q "mipmap/ic_launcher"; then
                ok "$m 含 mipmap/ic_launcher"
            else
                bad "$m 里没有 mipmap/ic_launcher"
            fi
            ;;
        *) bad "/product/overlay/$m 缺失";;
    esac
done

echo "== 特权权限白名单 =="
extract "$P" /etc/permissions/privapp-permissions-extra.xml "$W/perm.xml"
if grep -q 'android.permission.WATCH_APPOPS' "$W/perm.xml" 2>/dev/null; then
    ok "WATCH_APPOPS 正确"
else
    bad "白名单里没有 WATCH_APPOPS（开机可能死循环）"
fi
if grep -q '<permission name="android.permission.WATCH_APP_OPS"' "$W/perm.xml" 2>/dev/null; then
    bad "仍有拼错的 WATCH_APP_OPS 条目"
else
    ok "无拼错条目"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "全部检查通过。"
else
    echo "有检查项未通过（见上）。"
fi
exit "$fail"
