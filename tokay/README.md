# tokay（Pixel 9）集成件

本目录是把 `vendor/extra` 这套定制扩展到 **Pixel 9（tokay，Tensor G4 / zumapro）**
目标时新增的文件。virtio_x86_64 目标不需要它们；两个目标共享 `vendor/extra`
本体（经 `product.mk` 全局接入，见根 README）。

## 内容

| 文件 | 放到 | 作用 |
|---|---|---|
| `KernelSU-Next-Android.bp` | `packages/apps/KernelSU-Next/Android.bp` | KernelSU-Next 管理器的 `android_app_import` 定义（presigned，装 `/product/app/`） |
| `keys.mk` | `vendor/lineage-priv/keys/keys.mk` | 自签证书集的 makefile 接线（**不含私钥**，证书需自生成，见下） |
| `build_caimito.sh` | 内核树 `build_caimito.sh`（覆盖同名脚本） | bazel 构建入口，强制 GKI 从源码构建（否则 KSU 改动静默无效） |
| `patches/0001-kernelsu-kbuild-version-fallback.patch` | KernelSU-Next 源码 `kernel/Kbuild` | 修正版本号 fallback（v0.0.1 → v3.4.2） |

## KernelSU-Next v3.4.2 内核集成

管理器 APK 用官方 v3.4.2 发布（`KernelSU_Next.apk`，presigned 不能重签——内核按
`EXPECTED_MANAGER_HASH` 校验签名证书哈希）。内核侧：

1. **源码布局**：KernelSU-Next 仓库的 `kernel/` 拷到内核树
   `drivers/kernelsu/`，仓库**根**的 `uapi/`（6 个 ABI 头文件）也要一起拷进去。
   直接 `cp -r` 会跟随符号链接拷错位，注意解包方式。
2. **接线**：`drivers/Kconfig` 加 `source "drivers/kernelsu/Kconfig"`；
   `drivers/Makefile` 加 `obj-$(CONFIG_KSU) += kernelsu/`。
3. **版本号补丁**：源码拷贝不是 git 仓库，`git describe` 检测必落空，落入
   `KSU_VERSION_FALLBACK=1 / TAG_FALLBACK=v0.0.1`——管理器会显示 **v0.0.1**
   且拒绝装模块。应用 `patches/0001-*.patch` 固定为
   `KSU_VERSION=33355 / KSU_VERSION_TAG=v3.4.2`（即 v3.4.2 = 3355 commits
   时 `30000 + git rev-list --count` 的计算结果）。
4. **GKI 源码构建**：tokay 的 `device.bazelrc` 默认 `--use_prebuilt_gki=true`，
   直接下载 CI 预编译内核，`drivers/kernelsu` 的改动只被 Kbuild 解析、
   **永远不会链进镜像**（产物 md5 与预编译件一模一样就是这个原因）。
   用 `build_caimito.sh` 里的全 label 形式强制翻转：

   ```
   --//build/kernel/kleaf:use_prebuilt_gki=false
   --//aosp:use_prebuilt_gki=false
   --//build/kernel/kleaf:use_signed_prebuilts=false
   ```

   注意必须用**全 label**：短 flag `--use_prebuilt_gki` 受
   [bazel #13463](https://github.com/bazelbuild/bazel/issues/13463) 影响
   不翻转 select（cquery 实测）。两个 flag 都要显式置 false
   （`use_prebuilt_gki_set = kleaf flag OR //aosp legacy flag`）。
5. **defconfig**：`CONFIG_KSU=y`（KPROBES/EXT4_FS 在 gki_defconfig 里已是 y）。

构建后核对：`strings Image | grep v3.4.2`（1 处）且 `v0.0.1` 为 0 处，
`ksu_get_version_tag_cmd` 符号在位。

## 签名密钥（keys.mk）

tokay 要求锁 Bootloader，因此整套 AVB/OTA/APK 签名用**自签密钥**：

- 证书集放 `vendor/lineage-priv/keys/`（不在任何上游仓库的 manifest 里，
  `repo sync` 不会覆盖）。`keys.mk` 把 `PRODUCT_DEFAULT_DEV_CERTIFICATE` 等
  指到这套证书，并修好蓝牙的 `@BLUETOOTH` 证书目录（否则 mac_permissions
  回落 AOSP 测试密钥 → seinfo 失配 → 蓝牙每 30 秒 FC）。
- **私钥（.pk8/.pem）不入库**，需自行生成（`openssl` 自签或
  `development/tools/make_key`）。全套 10 对：releasekey、platform、
  shared、media、networkstack、bluetooth、nfc、sdk_sandbox、cts_uicc_2021、avb。
- AVB：`AVB_CUSTOM_KEY_PATH=vendor/lineage-priv/keys/avb.pem` + `WITH_AVB=true`
  编译；`avb_pkmd.bin` 烧进 `avb_custom_key` 分区后
  `fastboot flashing lock`。

## Obtainium ABI 陷阱（已修，记录在此防复发）

`Obtainium.apk` 必须用官方发布的 **`app-arm64-v8a-release.apk`**。
通用 `app-release.apk` 是 x86_64 构建（virtio 时代遗留），arm64 设备的
Package Manager 会**整包跳过** ABI 不匹配的 APK——文件在 `/priv-app` 里
但"未安装"，系统应用列表和桌面都不会出现。反解核对：
`aapt2 dump badging Obtainium.apk | grep native-code` 应为 `arm64-v8a`。
