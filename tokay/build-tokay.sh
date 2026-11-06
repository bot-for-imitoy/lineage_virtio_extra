#!/bin/bash
# 在 lineage-builder 容器内构建 Pixel 9 (tokay) 的 LineageOS 23.2。
# 必须在宿主真实 shell 里跑：agent 沙箱的批量文件操作守卫会打断 soong 分析。
#
# 用法：setsid nohup ./build-tokay.sh >/dev/null 2>&1 < /dev/null &

set -o pipefail

LOG=/mnt/vdb/lineage/tmp/build-tokay.log
: > "$LOG"

# 构建变体：userdebug（默认）| user（最终用户版）
VARIANT=${VARIANT:-userdebug}

echo "=== HOST BUILD START $(date '+%F %T %Z') target=tokay variant=$VARIANT ===" >> "$LOG"

sudo docker run --rm --network host \
    -v /mnt/vdb/lineage/lineage:/src \
    -v /mnt/vdb/lineage/tmp:/work-tmp \
    -v /mnt/vdb/lineage/docker/build-tokay-in-container.sh:/build.sh:ro \
    -e JOBS=6 \
    -e VARIANT="$VARIANT" \
    -w /src \
    lineage-builder:26.04 \
    bash /build.sh >> "$LOG" 2>&1

rc=$?
echo "=== HOST BUILD END $(date '+%F %T %Z') rc=$rc ===" >> "$LOG"
exit $rc
