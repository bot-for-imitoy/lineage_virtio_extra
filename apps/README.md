# 预编译 APK 目录 / Prebuilt APKs

本目录**不收录二进制文件**。这些 APK 全部是上游项目发布的原始签名包，
体积从 45 KB 到 108 MB，既不适合进 Git（GitHub 单文件上限 100 MB），
也没有必要——它们应当来自各自的发布渠道。

请把下面 7 个文件放到本目录（文件名必须一致），再运行 `tools/verify-apps.sh`
校验 SHA-256：

| 文件名 | 包名 | 版本 | 来源 |
|---|---|---|---|
| `Calendula.apk` | `de.jeanlucmakiola.calendula` | 2.23.0 (2230099) | [Codeberg](https://codeberg.org/jlmakiola/calendula) / [F-Droid](https://f-droid.org/packages/de.jeanlucmakiola.calendula/) |
| `ConnectYou.apk` | `com.bnyro.contacts` | 12.0 (35) | [you-apps/ConnectYou](https://github.com/you-apps/ConnectYou) / [F-Droid](https://f-droid.org/packages/com.bnyro.contacts/) |
| `DAVx5.apk` | `at.bitfire.davdroid` | 4.5.21-ose | [bitfireAT/davx5-ose](https://github.com/bitfireAT/davx5-ose) / [F-Droid](https://f-droid.org/packages/at.bitfire.davdroid/) |
| `F-Droid.apk` | `org.fdroid.fdroid` | 2.0.2 (2000052) | [f-droid.org](https://f-droid.org/packages/org.fdroid.fdroid/) |
| `F-DroidPrivileged.apk` | `org.fdroid.fdroid.privileged` | 0.2.14 (2140) | [Privileged Extension](https://gitlab.com/fdroid/privileged-extension) / [F-Droid](https://f-droid.org/packages/org.fdroid.fdroid.privileged/) |
| `Obtainium.apk` | `dev.imranr.obtainium` | 1.7.3 (23611) | [ImranR98/Obtainium](https://github.com/ImranR98/Obtainium) |
| `microG.apk` | `com.google.android.gms` | 0.3.17.252432 | [microG/GmsCore releases](https://github.com/microG/GmsCore/releases) |

> `microG.apk` 必须用 **microG 官方发布（官方签名）** 的 APK。LineageOS 的签名伪装
> 只对 `MICROG_REAL_SIGNATURE` 逐字节匹配的包生效，换成自己重签的版本会直接失效。

校验：

```bash
tools/verify-apps.sh          # 会在 apps/ 下执行 sha256sum -c SHA256SUMS
```

版本升级时，替换文件、更新 `apps/SHA256SUMS` 与本表格即可。
