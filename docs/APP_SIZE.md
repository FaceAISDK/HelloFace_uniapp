# Demo 安装包体积与发行配置

本文针对 APK、IPA、HAP，和插件市场的源码示例 ZIP 分开统计。调试基座包含调试能力，不能直接代表发行包大小；最终数据以完整构建并签名后的产物为准。SDK 仍锁定 0.8.11，模型、License、接口、阈值和存储保持原样。

## 查看体积构成

```sh
npm run size:inspect -- /path/to/app.apk /path/to/app.hap --report unpackage/validation/app-size.json
```

也支持 IPA。报告列出 ZIP 实际压缩体积、原生库架构、代码、模型和源码映射等组成。下载体积、解压大小和设备安装占用是不同指标。

## Android

两套 Demo 显式开启 `enableResourceOptimizations`，保留 ARM64 / ARMv7 双架构。HBuilderX 5.34 已默认开启该资源名称优化，显式配置用于固定行为，不能将它计作本轮新增的减包收益。[DCloud 配置说明](https://uniapp.dcloud.net.cn/collocation/manifest-app.html#enableresourceoptimizations)

根 Vue 工程沿用本机已有签名构建正式 APK：

```sh
npm run android:release
# 需要保护 JS 源码时可选择 DCloud JS 原生混淆：
npm run android:release -- --confuse
```

此命令使用 HBuilderX 云打包，正式包在 `unpackage/release/apk`，不覆盖调试基座、不安装或卸载设备 App。签名配置沿用 [Android 调试说明](ANDROID_DEBUG.md)，日志仅留在本机。uvue 工程使用自身 AppID、签名，通过 HBuilderX 发行。

`--confuse` 是 JS 原生混淆，不能当成 R8 的 Kotlin/Java 裁剪；其目的主要是源码保护，是否减小 APK 必须比较实际产物。发行模式的压缩、调试代码移除和按需依赖通常更直接。

本地 Android 原生宿主可在 Release 中启用 R8：

```groovy
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
            '/path/to/HelloFace_uniapp/android-configs/proguard-rules.pro'
    }
}
```

[桥接保留规则](../android-configs/proguard-rules.pro)仅保留本插件的 UTS 桥接类；SDK AAR 已自带 JNI consumer rules。宿主还需保留 DCloud 运行时自身的官方规则，不能通过只保留插件代替整个宿主的配置。该示例不影响 HBuilderX 云端的 R8 设置。[Android 官方优化说明](https://developer.android.com/topic/performance/app-optimization/enable-app-optimization)

`.bphfm` 模型继续不压缩，构建后检查模型、SDK 原生库及 16KB 对齐。更小的单 ABI APK 可作为额外分发版本，但直接改为仅 ARM64 会失去本工程旧 ARMv7 手机的兼容性，因此通用版仍保留双架构。

已有正式通用包后，可直接生成单独分发的 ARM64 副本，无需再次排队云构建：

```sh
npm run android:variant -- unpackage/release/apk/HelloFace-Demo-0.1.5-release.apk
```

工具仅移除其他 ABI 库，重新进行 16KB ZIP 对齐并用原证书签名；逐项校验保留的代码、资源、模型及证书，成功后才发布副本，原通用包不变。需要 Android SDK Build-Tools 35+ 及原包签名配置；脚本按数值版本选择工具，跳过低于 35 的版本。该副本用于直接分发；商店多架构分发按相应 AAB / 渠道规则处理。

本机当前结果：双架构正式 APK 为 31,777,772 字节，ARM64 副本为 25,054,129 字节；原调试包为 32,383,813 字节。旧 32 位手机使用通用包，ARM64 副本不代表仍兼容 ARMv7。通用包虽传入 JS 原生混淆选项，但不能据此声称所有 JS / Kotlin 或 SDK 均已混淆；本轮主要减包收益来自发行构建和独立的 ABI 副本。

## HarmonyOS

公开配置位于 `harmony-configs/entry`，在 HBuilderX 生成工程时覆盖到对应模块，仅对 Release 启用：

- 剥离 SO 调试符号，排除本插件不支持的 x86_64 库，保留 ARM64。
- 开启默认局部变量/参数混淆、代码压缩与注释移除；保留属性、导出和文件名称，兼容 Vue / UTS 动态桥接。
- 保留错误日志；混淆映射、源码映射和符号留在本机构建目录，最终 HAP 不携带源码映射。

`harmony-configs/AppScope/app.json5` 明确图标和名称资源引用，修复本机生成工程缺失这两个必填字段的问题。Bundle Name、版本和图标资源仍由 manifest 提供。`demo:prepare` 同步这些公开配置到 uvue，不复制根目录私有签名文件。

```sh
/Applications/HBuilderX.app/Contents/MacOS/cli pack app-harmony --project /path/to/HelloFace_uniapp
```

正式发行需要配置自己的发行证书和 Profile。若本机仅有调试签名，HBuilderX 可先生成未签名产物；制作测试用 Release HAP 时，在 DevEco 选择有现有签名的 product，同时将 Build Mode 设为 release。不要把 Build Mode 的 release 和名为 release 的 product 混为一谈。

本机 CLI 等价操作（不安装到手机）：

```sh
# 在 unpackage/dist/build/app-harmony 目录执行；product 名称以已有签名配置为准。
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p product=default -p module=entry@default -p buildMode=release assembleHap --no-daemon
```

本机测得签名 HAP 从 22,180,901 降至 17,539,009 字节，约减少 20.93%。这是现有 Debug 包与当前 Release 包的实测对比，前后页面版本不同，并非只切换混淆的单变量实验。SDK 原生库哈希和证书链一致，已验证签名；不等于本轮真机识别验收。详细结果见 [验证记录](VALIDATION.md)。

依据：[DCloud 鸿蒙扩展配置](https://uniapp.dcloud.net.cn/tutorial/harmony/runbuild.html)、[华为混淆配置](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-build-obfuscation/)、[原生库构建配置](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-hvigor-cpp/)。二进制 HAR 中已经编译的代码不会因宿主混淆开关再次混淆，不能声称整个 SDK 或所有运行时都已重新混淆。

## iOS

根 Vue 的 iOS 目标架构固定为 SDK 支持的 ARM64。本地 Xcode 宿主可在 Release 配置中引用 [Release.xcconfig](../ios-configs/Release.xcconfig)，启用体积优化、无用代码剔除和产物符号剥离，dSYM 单独保留用于崩溃还原。此文件不由 HBuilderX 云打包自动读取，也不能重新优化已经预编译的 SDK。

使用 iPhoneOS Archive / Export，让 Xcode 选择真机 slice，不把整个 xcframework 或模拟器 slice 复制进 IPA；IPA 不放入 dSYM、源码和构建缓存。App Store 分发还可使用 App Thinning。保留 SDK 模型及隐私清单，不重命名 UTS/Objective-C 动态调用入口。[Apple 体积优化说明](https://developer.apple.com/documentation/xcode/reducing-your-app-s-size)

本机 Xcode 15.2 无法完整编译 Swift 6.1.2 SDK，且没有已完成构建签名的 IPA，因此没有本轮 IPA 前后体积或真机结果；需兼容 Xcode、完整原生宿主及相应签名后实测。
