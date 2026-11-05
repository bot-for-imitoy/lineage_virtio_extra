#
# 让 vendor/extra 的改动对所有产品生效。
#
# vendor/lineage/config/common.mk 第 2 行有：
#     $(call inherit-product-if-exists, vendor/extra/product.mk)
# 所以本文件会被每个 Lineage 产品（virtio、tokay 等）继承。
#
# 之前 virtio 是在 device/virt/virtio_x86_64/lineage_virtio_x86_64.mk 末尾
# 直接 inherit vendor/extra/extra.mk，那只对该设备生效。改到真机目标
# （lineage_tokay）后，设备树是 LineageOS 上游的、不该去改，因此把继承
# 点放在这里。
#

$(call inherit-product, vendor/extra/extra.mk)
