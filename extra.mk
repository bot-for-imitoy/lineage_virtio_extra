#
# 第三方应用替换 / 预装配置
#
# 该文件在 lineage_virtio_x86_64.mk 的最后被 inherit。
#

# ---------------------------------------------------------------------------
# 1. 关于移除系统自带的同类应用
#
#    AOSP/Lineage 的 inherit-product 是"延迟展开"的：子产品被继承时只会留下
#    @inherit: 标记，真实包名要等 product_config.mk 阶段才展开，安装列表又是
#    从 PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES 节点快照里取的。
#    所以在本文件里对 PRODUCT_PACKAGES 做 filter-out 是无效的（实测一个都过滤
#    不掉），必须直接改添加这些应用的源 makefile：
#
#      Etar     -> vendor/lineage/config/common_mobile_full.mk
#      Jelly    -> vendor/lineage/config/common.mk
#      Contacts -> build/make/target/product/handheld_product.mk
#
#    对应的 provider（ContactsProvider、CalendarProvider 等）保持不动，
#    第三方应用仍然依赖它们。
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 2. 预装替换应用与工具
#    Calendula / ConnectYou : 替换系统自带同类应用
#    Obtainium / F-Droid / DAVx5 : 预装特权应用，用于静默安装与静默更新
#    GmsCore（microG）: 预装为特权应用，提供 GMS 兼容层
#    （特权权限白名单见 permissions/privapp-permissions-extra.xml）
#
#    本 ROM 不预装任何浏览器：Jelly 与 Firefox 均已移除，用户自行安装。
#
#    microG 之所以能直接用：LineageOS 23.2 的 frameworks/base 已含
#    "仅对官方签名 microG 开放"的签名伪装（ComputerEngine.isMicrogSigned /
#    generateFakeSignature），不需要任何第三方补丁。详见 Android.bp 里的说明。
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    Calendula \
    ConnectYou \
    Obtainium \
    F-Droid \
    F-DroidPrivilegedExtension \
    DAVx5 \
    GmsCore

# KernelSU-Next 管理器（presigned APK，内核按 EXPECTED_MANAGER_HASH 校验，
# 不能用本树密钥重签）。内核侧已把 CONFIG_KSU=y 编进 gs-6.1（见
# out-kernel/google/gs-6.1/private/devices/google/caimito/caimito_defconfig）。
PRODUCT_PACKAGES += \
    KernelSU-Next

# ---------------------------------------------------------------------------
# 3. 外观覆盖（RRO）
#    Calendula -> 显示名 Calendar / 日历，图标换成 LineageOS 自带日历 Etar 的图标
#    ConnectYou -> 显示名 Contacts / 联系人，图标换成 LineageOS 自带联系人的图标
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    CalendulaLabelOverlay \
    ConnectYouLabelOverlay

# ---------------------------------------------------------------------------
# 4. 特权应用权限白名单 + 电池优化白名单
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    vendor/extra/permissions/privapp-permissions-extra.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/privapp-permissions-extra.xml \
    vendor/extra/sysconfig/sysconfig-extra.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/sysconfig/sysconfig-extra.xml

# ---------------------------------------------------------------------------
# 5. ro.debuggable 与 microG 签名伪装无关（更正说明）
#
# 早期版本的这里写着"microG 签名伪装需要 ro.debuggable=1"，这个结论是错的：
#
#   ComputerEngine.isMicrogSigned() 第一句调用的 isDebuggable() 是一个 native
#   方法，实现是 services/core/jni/com_android_server_pm_ComputerEngine.cpp 里
#   的
#       #ifdef ANDROID_DEBUGGABLE
#           return true;
#       #else
#           return false;
#       #endif
#   也就是说它是**编译期宏**，对应的 cflag 由
#   frameworks/base/services/core/jni/Android.bp 的
#       product_variables: { debuggable: { cflags: ["-DANDROID_DEBUGGABLE"] } }
#   注入；而 soong 的 Debuggable 产品变量来自
#   build/make/core/soong_config.mk:
#       $(call add_json_bool, Debuggable, $(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
#   只要编的是 userdebug / eng，它就恒为 true。
#
#   而 ProductNotDebuggableInUserdebug（= PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG）
#   只被 build/soong/scripts/gen_build_prop.py 用来决定 build.prop 里的
#   ro.debuggable 和 persist.debug.dalvik.vm.core_platform_api_policy，
#   对上面这个宏没有任何影响。
#
# 实测确认：Debuggable=True 时 m.libservices.core_android_x86_64_sandybridge_static
# 的 cFlags 里带 -DANDROID_DEBUGGABLE。
#
# 因此 vendor/lineage/config/common.mk 里的
#   PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG := true
# 已恢复成 LineageOS 原样（userdebug 下 ro.debuggable=0）。若确实需要 adb root，
# 再自行注释掉那一行即可，与 microG 无关。
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 6. 关闭 "verify <uses-library>" 一致性校验
#
# Calendula / F-Droid / DAVx5 这些上游 APK 的 manifest 里声明了
#   <uses-library-not-required android:name="androidx.window.extensions"/>
#   <uses-library-not-required android:name="androidx.window.sidecar"/>
# 而 AOSP 构建系统里没有同名模块，无法对齐 manifest_check 的列表，会报
#   "mismatch or misordering in the <uses-library> tags"。
# 该校验的意义是保证 dexpreopt/AOT 的类加载上下文正确，而本产品已用
# DONT_DEXPREOPT_PREBUILTS 关掉预编译 APK 的 dexpreopt，因此直接关闭。
# ---------------------------------------------------------------------------
PRODUCT_BROKEN_VERIFY_USES_LIBRARIES := true
