# LineageOS 23.2 · virtio_x86_64 的 `vendor/extra`

一个跑在 QEMU / virtio 平台上的 LineageOS 23.2（Android 16，userdebug）个人构建里，
用来替换系统自带应用、预装 microG 生态的那部分配置。**只包含 `vendor/extra`
本身**，改动到的上游仓库以补丁形式放在 `patches/`，预编译 APK 不入库（见
[`apps/README.md`](apps/README.md)）。

- 设备：`lineage_virtio_x86_64-trunk_staging-userdebug`
- 基线：LineageOS 23.2（`refs/heads/lineage-23.2`）
- 构建产物：`lineage-23.2-*-UNOFFICIAL-virtio_x86_64.{iso,img,zip}`

## 改动一览

| 分类 | 内容 |
|---|---|
| 日历 | 移除 Etar，改用 **Calendula**；显示名改为 `Calendar / 日历`，**图标换成 Etar 的原始图标** |
| 联系人 | 移除 AOSP `Contacts`，改用 **Connect You**；显示名改为 `Contacts / 联系人`，**图标换成 AOSP Contacts 的原始图标** |
| 浏览器 | **不预装任何浏览器**（Jelly 与 Firefox 都已移除，由用户自行安装） |
| GMS | 预装 **microG GmsCore**（`com.google.android.gms`，特权应用），依赖 LineageOS 自带的、仅对官方签名 microG 开放的签名伪装 |
| 工具 | 预装 **F-Droid** + **F-Droid Privileged Extension** + **DAVx⁵** + **Obtainium**，均装为特权应用以获得静默安装 / 静默更新 |
| 系统 | 特权权限白名单 16 条、Doze 白名单 5 个包、关闭预编译 APK 的 dexpreopt |

> 说明：本仓库替换掉了 LineageOS 的日历与联系人，但**保留了各自的 provider**
> （`CalendarProvider`、`ContactsProvider`、`ContactsPicker`）。第三方应用仍然依赖
> 这些 provider，删掉会连带打断同步和共享。

## 目录结构

```
Android.bp                    预编译 APK 的 android_app_import 定义
extra.mk                      PRODUCT_PACKAGES / PRODUCT_COPY_FILES，被设备树 inherit
apps/                         放置 7 个上游 APK（不入库），含 SHA256SUMS
overlays/calendula/           静态 RRO：显示名 + 图标
overlays/connectyou/          静态 RRO：显示名 + 图标
permissions/                  特权权限白名单（privapp-permissions-extra.xml）
sysconfig/                    电池优化白名单（sysconfig-extra.xml）
patches/                      对上游仓库的改动，逐个仓库一个补丁
local_manifests/              把本仓库挂到 vendor/extra 的 repo local manifest
tools/verify-apps.sh          校验 apps/ 下 APK 的 SHA-256
```

## 快速开始

```bash
# 1. 已经 repo sync 好 LineageOS 23.2 源码树
# 2. 把本仓库挂到 vendor/extra
mkdir -p .repo/local_manifests
cp local_manifests/vendor-extra.xml .repo/local_manifests/
repo sync vendor/extra

# 3. 放好 7 个预编译 APK（来源见 apps/README.md），然后校验
tools/verify-apps.sh

# 4. 打上游补丁（三个仓库各一个）
repo start virtio-extra vendor/lineage build/make device/virt/virtio_x86_64
git -C vendor/lineage            am -3 $PWD/vendor/extra/patches/0001-vendor_lineage-drop-Etar-and-Jelly.patch
git -C build/make                am -3 $PWD/vendor/extra/patches/0002-build_make-drop-Contacts.patch
git -C device/virt/virtio_x86_64 am -3 $PWD/vendor/extra/patches/0003-device_virt_virtio_x86_64.patch

# 5. 编译
source build/envsetup.sh
lunch lineage_virtio_x86_64-trunk_staging-userdebug
m -j4 isoimage-install
```

## 补丁说明

| 补丁 | 目标仓库 | 做了什么 |
|---|---|---|
| `0001-vendor_lineage-drop-Etar-and-Jelly.patch` | `LineageOS/android_vendor_lineage` | `config/common_mobile_full.mk` 去掉 `Etar`；`config/common.mk` 去掉 `Jelly`；`PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG` 保持 LineageOS 原样 |
| `0002-build_make-drop-Contacts.patch` | `LineageOS/android_build` | `target/product/handheld_product.mk` 去掉 `Contacts` |
| `0003-device_virt_virtio_x86_64.patch` | `LineageOS/android_device_virt_virtio_x86_64` | 在 `lineage_virtio_x86_64.mk` 末尾 inherit `vendor/extra/extra.mk`；加 `DONT_DEXPREOPT_PREBUILTS` |

为什么必须在**源头**删包，而不是在 `extra.mk` 里 `filter-out`：`inherit-product`
是延迟展开的，子产品被继承时只留下 `@inherit:` 标记，真实包名要等
`product_config.mk` 阶段才展开，而安装列表是从
`PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES` 的快照节点里取的。在 `extra.mk`
里对 `PRODUCT_PACKAGES` 做 `filter-out` 实测一个都过滤不掉。

## 提交与分支

改动分别落在三处，都能直接看到 diff：

| 位置 | 分支 | 提交 |
|---|---|---|
| 本仓库 | `main` | `vendor/extra: 应用替换 + microG + 外观覆盖` |
| `bot-for-imitoy/android_vendor_lineage` | `lineage-23.2-virtio-extra` | [`4b0634b`](https://github.com/bot-for-imitoy/android_vendor_lineage/commit/4b0634b7f42ea1cfa896b43254e41dcb48bb7db5) 移除 Etar / Jelly |
| `bot-for-imitoy/android_build` | `lineage-23.2-virtio-extra` | [`9e57395`](https://github.com/bot-for-imitoy/android_build/commit/9e573954acc7745a20097fff7cbc5a8dbdf20870) 移除 Contacts |
| `bot-for-imitoy/android_device_virt_virtio_x86_64` | `lineage-23.2-virtio-extra` | [`a7a4e7b`](https://github.com/bot-for-imitoy/android_device_virt_virtio_x86_64/commit/a7a4e7ba4a4708c9ec2fee9c961391e3451030c6) inherit vendor/extra、关掉预编译 dexpreopt |

仓库里的 `patches/` 与上面的提交内容是同一份改动，两种方式任选：
已经 clone 了上游仓库就用 `git am`；想直接对照就看提交。

## 依赖仓库与 Fork

预编译 APK 全部是上游**原版签名**包，因此本仓库一个字节的二进制都不收录，
只记录来源、版本与 SHA-256。下表同时列出 Fork（在本账号下，用于跟踪上游异动
和提交本地补丁）：

| 依赖 | 上游 | Fork | 用途 |
|---|---|---|---|
| Calendula | [codeberg.org/jlmakiola/calendula](https://codeberg.org/jlmakiola/calendula) | — （Codeberg 上的项目，GitHub 无法 Fork） | 日历应用 |
| Connect You | [you-apps/ConnectYou](https://github.com/you-apps/ConnectYou) | [bot-for-imitoy/ConnectYou](https://github.com/bot-for-imitoy/ConnectYou) | 联系人应用 |
| microG GmsCore | [microG/GmsCore](https://github.com/microG/GmsCore) | [bot-for-imitoy/GmsCore](https://github.com/bot-for-imitoy/GmsCore) | GMS 兼容层 |
| DAVx⁵ | [bitfireAT/davx5-ose](https://github.com/bitfireAT/davx5-ose) | [bot-for-imitoy/davx5-ose](https://github.com/bot-for-imitoy/davx5-ose) | CalDAV / CardDAV 同步 |
| Obtainium | [ImranR98/Obtainium](https://github.com/ImranR98/Obtainium) | [bot-for-imitoy/Obtainium](https://github.com/bot-for-imitoy/Obtainium) | 从上游发布页跟进更新 |
| F-Droid | [f-droid/fdroidclient](https://github.com/f-droid/fdroidclient) | [bot-for-imitoy/fdroidclient](https://github.com/bot-for-imitoy/fdroidclient) | F-Droid 客户端 |
| F-Droid Privileged Extension | [gitlab.com/fdroid/privileged-extension](https://gitlab.com/fdroid/privileged-extension) | — （GitLab） | 静默安装后端 |
| Etar（图标来源） | [LineageOS/android_packages_apps_Etar](https://github.com/LineageOS/android_packages_apps_Etar) | [bot-for-imitoy/android_packages_apps_Etar](https://github.com/bot-for-imitoy/android_packages_apps_Etar) | 日历图标 |
| Contacts（图标来源） | [LineageOS/android_packages_apps_Contacts](https://github.com/LineageOS/android_packages_apps_Contacts) | [bot-for-imitoy/android_packages_apps_Contacts](https://github.com/bot-for-imitoy/android_packages_apps_Contacts) | 联系人图标 |
| vendor/lineage | [LineageOS/android_vendor_lineage](https://github.com/LineageOS/android_vendor_lineage) | [bot-for-imitoy/android_vendor_lineage](https://github.com/bot-for-imitoy/android_vendor_lineage) | 补丁 0001 的目标 |
| build/make | [LineageOS/android_build](https://github.com/LineageOS/android_build) | [bot-for-imitoy/android_build](https://github.com/bot-for-imitoy/android_build) | 补丁 0002 的目标 |
| 设备树 | [LineageOS/android_device_virt_virtio_x86_64](https://github.com/LineageOS/android_device_virt_virtio_x86_64) | [bot-for-imitoy/android_device_virt_virtio_x86_64](https://github.com/bot-for-imitoy/android_device_virt_virtio_x86_64) | 补丁 0003 的目标 |

## 几个关键点

### microG 为什么能直接装成特权应用

LineageOS 23.2 的 `frameworks/base` 自带"仅对官方签名 microG 开放"的签名伪装，
不需要任何第三方补丁或 Xposed。判定在 `ComputerEngine.isMicrogSigned()`：

1. `isDebuggable()` —— **编译期宏** `ANDROID_DEBUGGABLE`，不是读 `ro.debuggable`。
   cflag 来自 `services/core/jni/Android.bp` 的
   `product_variables: { debuggable: { cflags: ["-DANDROID_DEBUGGABLE"] } }`，
   而 soong 的 `Debuggable` 变量是
   `$(filter userdebug eng,$(TARGET_BUILD_VARIANT))`，userdebug 恒为 true；
2. 包名是 `com.google.android.gms` 或 `com.android.vending`；
3. 真实签名逐字节等于框架内置的 `MICROG_REAL_SIGNATURE`（753 字节 DER）；
4. manifest 的 `fake-signature` 等于 `MICROG_FAKE_SIGNATURE`（2190 字符）。

所以 `ro.debuggable=0` 完全不影响签名伪装——`PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG`
只影响 `build.prop` 里的 `ro.debuggable`。装好后 microG 自检的
`System spoofs signature` 会直接打勾。

### 特权权限白名单：拼错一个字母 = 开不了机

Android 16 起，`AppIdPermissionPolicy.onSystemReady` 对"申请了 signature|privileged
权限但没进 allowlist"的包**直接抛 `IllegalStateException`**，不再是旧版本那种
打条警告继续跑。`system_server` 会在 `PackageManagerService.systemReady` 阶段被
终止，init 只能不停重启 zygote，表现为**开机动画无限循环**——完全看不到
"权限错误"这几个字。

写白名单时注意平台里的真实名字：

- `WATCH_APPOPS`（不是 `WATCH_APP_OPS`）
- `UPDATE_APP_OPS_STATS`（这个倒是有 `APP_OPS`）
- `SYSTEM_ALERT_WINDOW`、`INTERACT_ACROSS_PROFILES` 虽是 `signature*` 但**不含
  privileged 标志**，写进 privapp 白名单反而会报错

本仓库的 16 条（含 F-Droid Privileged Extension 的 2 条）已经与 APK 申请逐项对齐。

### 图标覆盖（RRO）

`overlays/*/res/mipmap-*/ic_launcher.xml` 覆盖目标包的 `mipmap/ic_launcher`。
图标本体是从 `packages/apps/Etar` 与 `packages/apps/Contacts` 的
`res/drawable/ic_launcher_{background,foreground,monochrome}.xml` 原样拷过来的
自适应图标（纯矢量，无外部引用），版权归 The LineageOS Project（Apache-2.0）。

两个目标包对自适应图标的存放位置不同，所以对齐了两套配置：

- Calendula 把 `mipmap/ic_launcher` 放在 `anydpi`（无 `-v26`）下，且同时声明
  `android:icon` 与 `android:roundIcon` → 覆盖 `anydpi` 与 `anydpi-v26` 两套，
  `ic_launcher` 与 `ic_launcher_round` 都换；
- Connect You 只声明 `android:icon`，配置在 `anydpi-v26` 下 → 只覆盖一套。

### 预编译 APK 的三个开关

- `presigned: true` —— 保留上游签名，否则应用再也无法自己更新自己；
- `preprocessed: true` —— APK 已 zipalign + v2 签名，构建系统别再动它；
- `skip_preprocessed_apk_checks: true` —— 特权应用有一条"classes.dex 必须未压缩"
  的检查（原本为就地 dexpreopt 服务），这些上游包 dex 都是 Deflate 的，而本产品
  已用 `DONT_DEXPREOPT_PREBUILTS` 关掉预编译 APK 的 dexpreopt，跳过即可。

## 构建与验证

```bash
lunch lineage_virtio_x86_64-trunk_staging-userdebug
m -j4 isoimage-install
```

发布物里的 `.iso` / `.img` 只是**安装介质**，真正的系统在 OTA zip 的
`payload.bin` 里。核对产物内容用构建出来的 `ota_extractor` 直接解分区
（不需要 root、不需要挂载）：

```bash
unzip -o lineage-23.2-*-UNOFFICIAL-virtio_x86_64.zip payload.bin -d /tmp/ota
out/host/linux-x86/bin/ota_extractor --payload=/tmp/ota/payload.bin \
    --output_dir=/tmp/ota/img --partitions=product,system
debugfs -R "dump /etc/permissions/privapp-permissions-extra.xml /tmp/p.xml" /tmp/ota/img/product.img
debugfs -R "ls -l /priv-app" /tmp/ota/img/product.img
```

## 已知问题

- **Bluetooth 每 30 秒崩溃一次**（与本次改动无关）：`selinux_android_setcontext`
  匹配不到 `default:privapp:targetSdkVersion=10000:partition=system:complete`
  这个 key，`seapp_contexts` 缺条目，fork 阶段就被 SELinux 打死。
  `com.google.android.gms` 同为 privapp 却能正常 fork，说明是这条 key 缺策略，
  待单独补 sepolicy。
- **安装 ISO 在无网卡 QEMU 下会落到 recovery 菜单**：安装器需要网络，
  给 `-nic user,model=virtio-net-pci`；或者直接用 kernel + combined ramdisk +
  `androidboot.install=1` 那条路。
- 首次启动 `surfaceflinger` 可能因找不到 EGL 实现 abort 一次，init 重启后即正常
  （本设备 minigbm 只编了 `-DRV_I915 -DRV_XE`，面向 Intel 显卡直通）。

## 许可

- 本仓库的配置与脚本：Apache-2.0
- `overlays/*/res/drawable/ic_launcher_*.xml` 与 `mipmap-anydpi*/ic_launcher*.xml`
  来自 The LineageOS Project，Apache-2.0
- `patches/` 中的补丁作用于 Apache-2.0 的 AOSP / LineageOS 代码
- 预编译 APK 各自遵循其上游许可（GPL-3.0 / Apache-2.0 / 等），本仓库不再分发
