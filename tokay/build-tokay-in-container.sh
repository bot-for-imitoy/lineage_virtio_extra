#!/bin/bash
# 在 lineage-builder 容器内执行：lunch lineage_tokay-userdebug + m bacon
#
# 注意：lunch 这一步不只是设置环境变量。device/google/caimito/device-tokay.mk 里
#   TARGET_KERNEL_PLATFORM_SOURCE := google/gs-6.1
# 会让 envsetup 在 lunch 期间调用 build_kernel()：
#   1) 在 out-kernel/google/gs-6.1 里做嵌套 repo init/sync
#      （manifest = android_kernel_google_gs-6.1_manifest，分支 lineage-23.2）
#   2) 跑该目录下的 build_caimito.sh 编内核
#   3) 把产物（Image.lz4 / dtbo.img / *.ko / boot.img）拷进
#      device/google/caimito-kernels/6.1/
# 所以内核编译的进度也会出现在本日志里，且耗时可能有一小时量级。

set -o pipefail
cd /src || exit 1

export LC_ALL=C
export TMPDIR=/work-tmp/scratch
mkdir -p "$TMPDIR"

JOBS=${JOBS:-6}
# 构建变体：userdebug（调试版）或 user（最终用户版）。由宿主侧 docker -e 传入。
VARIANT=${VARIANT:-userdebug}

# 容器是 --rm 的，每次都是干净的 HOME；repo/git 需要身份才能init
git config --global user.email "builder@localhost" 2>/dev/null
git config --global user.name "builder" 2>/dev/null
git config --global --add safe.directory '*' 2>/dev/null

# 容器里没有 repo 命令，build_kernel() 的嵌套 repo init/sync 会失败。
# 源码树自带 repo 工具（.repo/repo/repo，python3 启动器），挂进 PATH 即可。
export PATH="/src/.repo/repo:$PATH"
command -v repo >/dev/null || { echo "repo 仍然不可用，无法同步内核源码"; exit 1; }

# android.googlesource.com 在本网络直连必断（TLS reset），内核 manifest 的
# aosp remote 全部改写到 TUNA 的 AOSP 镜像（仓库齐全）。
git config --global url."https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/".insteadOf "https://android.googlesource.com/"
git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
# github 直连也常断，经 ghproxy 走；只用环境变量作用域，避免污染全局 git
# 配置（否则以后 git push 也会被改写到代理）。
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="url.https://ghproxy.net/https://github.com/.insteadOf"
export GIT_CONFIG_VALUE_0="https://github.com/"

# 内核产物（Image.lz4 等）已由 tmp/kernel-sync-build.sh 单独编好时，
# 让 lunch 跳过 build_kernel()，否则每次 lunch 都会重同步 + 重编内核。
if [ -f /src/device/google/caimito-kernels/6.1/Image.lz4 ]; then
    export SKIP_KERNEL_BUILD=1
    echo "=== 检测到内核产物，跳过内核编译 ==="
fi

source build/envsetup.sh >/dev/null 2>&1

# 这个分支是 AOSP 26.x 的分支命名，lunch 必须是三段式 <product>-<release>-<variant>，
# 光写 lineage_tokay-userdebug 会报 "Invalid lunch combo"。release 用 trunk_staging
# （build/release/release_configs/trunk_staging.textproto），与 virtio 那轮一致。
#
# 注意：lunch 的输出**不能**用管道接 tee —— `lunch ... | tee` 会让 lunch 在子 shell
# 里执行，export 出来的 TARGET_PRODUCT/TARGET_RELEASE/TARGET_BUILD_VARIANT 全部丢失，
# 随后的 m 会报 "No release config set for target"。用进程替换（> >(...)）可以既
# 实时打印、又留在当前 shell。
echo "=== LUNCH START $(date '+%F %T')  (含内核编译，可能较久) variant=$VARIANT ==="
lunch lineage_tokay-trunk_staging-$VARIANT > >(tee "$TMPDIR/lunch.log") 2>&1
lunch_rc=$?
if [ "$lunch_rc" -ne 0 ]; then
    echo "=== LUNCH FAILED rc=$lunch_rc ==="
    exit "$lunch_rc"
fi
echo "=== LUNCH END $(date '+%F %T') ==="

echo "=== BUILD START $(date '+%F %T') target=$(get_build_var TARGET_PRODUCT) jobs=$JOBS ==="
echo "=== kernel prebuilts: $(ls device/google/caimito-kernels/6.1/ | tr '\n' ' ') ==="

# ---------------------------------------------------------------------------
# AVB 自签名 + 启用真实 verified boot（为锁 Bootloader 准备）
#
# device/google/zumapro/BoardConfig-common.mk 留了官方钩子：
#   ifneq (,$(AVB_CUSTOM_KEY_PATH)) → 全套 AVB key 换成外部指定（含 chained：
#   boot / init_boot / vbmeta_system / vbmeta_vendor）；否则默认 AOSP 测试密钥。
#   ifneq ($(WITH_AVB),true) → vbmeta 加 --flags 3（HASHTREE_DISABLED |
#   VERIFICATION_DISABLED），即验证实际关闭。锁 Bootloader 时 ABL 不接受
#   locked + verification_disabled，必须 WITH_AVB=true。
#
# 密钥是 vendor/lineage-priv/keys/avb.pem（RSA-4096，由 gen-keys.sh 生成）。
# 环境变量 + make 命令行变量双重传入（BoardConfig 的 else 分支不会覆盖已定义
# 的变量；命令行变量优先级最高）。
# ---------------------------------------------------------------------------
export AVB_CUSTOM_KEY_PATH=vendor/lineage-priv/keys/avb.pem
export AVB_CUSTOM_ALGORITHM=SHA256_RSA4096
export WITH_AVB=true
echo "=== AVB: key=$AVB_CUSTOM_ALGORITHM $AVB_CUSTOM_KEY_PATH WITH_AVB=$WITH_AVB ==="

(nice -n 10 m -j"$JOBS" bacon \
    AVB_CUSTOM_KEY_PATH="$AVB_CUSTOM_KEY_PATH" \
    AVB_CUSTOM_ALGORITHM="$AVB_CUSTOM_ALGORITHM" \
    WITH_AVB=true)
rc=$?

echo "=== BUILD END $(date '+%F %T') rc=$rc ==="
exit $rc
