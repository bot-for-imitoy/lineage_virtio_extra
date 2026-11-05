#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

parameters=
if [ "${BUILD_AOSP_KERNEL}" = "1" ]; then
  echo "WARNING: BUILD_AOSP_KERNEL is deprecated." \
    "Use --kernel_package=@//aosp instead." >&2
  parameters="--kernel_package=@//aosp"
fi

if [ "${BUILD_STAGING_KERNEL}" = "1" ]; then
  echo "WARNING: BUILD_STAGING_KERNEL is deprecated." \
    "Use --kernel_package=@//aosp-staging instead." >&2
  parameters="--kernel_package=@//aosp-staging"
fi

# 2026-11-05: 强制 GKI 内核从源码构建（kernel_aarch64 sources = aosp/**），
# 否则默认 --use_prebuilt_gki=true 直接下载 CI 预编译 vmlinux/Image，
# drivers/kernelsu 的改动只被 Kbuild 解析、永远不会链进内核镜像。
# 注意：必须用全 label 形式——短 flag --use_prebuilt_gki（alias→bool_flag）
# 受 bazel issue #13463 影响不可靠（cquery 实测不翻转 select）。
# 两个 flag 都要显式置 false：use_prebuilt_gki_set = kleaf flag OR //aosp legacy flag。
# KSU 依赖（KPROBES/EXT4_FS）在 gki_defconfig 里都是 y，Kconfig default y 自动启用。
exec tools/bazel run \
    ${parameters} \
    --config=stamp \
    --config=caimito \
    --//build/kernel/kleaf:use_prebuilt_gki=false \
    --//aosp:use_prebuilt_gki=false \
    --//build/kernel/kleaf:use_signed_prebuilts=false \
    //private/devices/google/caimito:zumapro_caimito_dist "$@"
