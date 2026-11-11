# HelloFaceVerify 三端打包指南

本文面向本仓库的源码版 UTS 插件和示例，核对日期为 2026-11-09。当前工程包括 uni-app Vue2/Vue3 示例、uni-app x uvue 示例及三端插件源码。

## 是否必须用云服务器打包

**三端均可在本机完成原生构建，无需自建云服务器。** Android、iOS 可选择 DCloud 云打包，也可配置原生工程本地打包；鸿蒙使用本地 DevEco 工具链。

| 平台 | 本地构建环境 | 另一种选择 |
| --- | --- | --- |
| Android | HBuilderX 导出本地打包资源，使用 Android Studio / Gradle 集成对应 DCloud 原生 SDK 与 UTS 插件 | HBuilderX 的 Android 云打包 |
| iOS | Mac、兼容上游 SDK 的 Xcode、对应 DCloud iOS 原生 SDK和自己的签名配置 | HBuilderX 的 iOS 云打包，需验证云环境与 SDK 的工具链兼容性 |
| HarmonyOS 鸿蒙 | HBuilderX + DevEco Studio、SDK 和签名配置，在本机生成安装包 | 当前官方流程为本地打包 |

官方说明：[Android UTS 原生工程接入](https://doc.dcloud.net.cn/uni-app-x/native/use/androiduts.html)、[iOS UTS 原生工程接入](https://doc.dcloud.net.cn/uni-app-x/native/use/iosuts.html)、[鸿蒙本地构建](https://doc.dcloud.net.cn/uni-app-x/app-harmony/)。

本地打包需要配好原生宿主工程；当前仓库根目录是 HBuilderX 项目，不是可直接执行 Gradle、xcodebuild 或 Hvigor 的完整原生 App 工程。首次安装 SDK、下载工具和拉取依赖仍可能需要网络。

## 区分调试基座、插件检查和正式安装包

- **自定义调试基座**：用于真机调试，包含原生 SDK、UTS 插件、权限和相关资源。选择云端制作基座是一种操作路径；源码版也可通过本地原生工程集成和构建。
- **插件检查**：`npm run check` 校验 API、SDK 文件并将 UTS 转成三端代码。原生模块编译记录见 `VALIDATION.md`；这些检查都不等同于完整 App 打包成功。
- **正式安装包**：需要实际构建、链接和签名，产物例如 Android APK/AAB、iOS IPA、鸿蒙 APP/HAP。

本插件包含 AAR、xcframework、HAR、相机权限和原生源码。调试或正式构建的宿主必须包含这些内容。修改原生依赖、权限、资源或模型打包选项后，要重新构建相应原生产物。

## 通用准备

在仓库根目录执行：

```sh
npm ci --ignore-scripts
npm run sdk:install
npm run sdk:check
```

原生 SDK 由 `sdk-artifacts.json` 锁定到版本、上游 commit、SHA-256 和文件长度。也可仅安装单端：

```sh
python3 scripts/install_sdk.py --platform android
python3 scripts/install_sdk.py --platform ios
python3 scripts/install_sdk.py --platform harmony
```

要运行哪个示例：

| 示例 | HBuilderX 导入目录 | 前端配置 |
| --- | --- | --- |
| Vue3 | 仓库根目录 | 默认 `manifest.json` 的 `vueVersion: "3"` |
| Vue2 | 仓库根目录 | 将 `vueVersion` 改为 `"2"`，使用已有 `main.js` 条件编译入口 |
| uvue | 执行 `npm run demo:prepare` 后，导入 `examples/uni-app-x` | 使用其独立 `App.uvue`、`main.uts` 和 `manifest.json` |

根目录示例已配置本仓库演示用 AppID；独立 uvue 示例仍使用占位 AppID。集成到自己的应用时需配置自己的 AppID、包名和签名。插件唯一源码位于 `uni_modules/HelloFace-Verify`；修改后重新执行 `npm run demo:prepare`，把插件与已安装的原生依赖同步到 uvue 示例。

当前工程标识如下，DCloud AppID 与操作系统包名不是同一种标识：

| 平台 | 根目录 Vue 示例 | 独立 uvue 示例 |
| --- | --- | --- |
| Android 包名 | `dev.helloface.uniapp.demo` | `dev.helloface.uniappx.demo` |
| HarmonyOS Bundle Name | `dev.helloface.uniapp.demo` | 当前也为 `dev.helloface.uniapp.demo`，同时安装前应配置为不同标识 |
| iOS Bundle ID | 尚未在 manifest 固定，打包时按签名配置 | 尚未在 manifest 固定，打包时按签名配置 |

## Android

### 真机调试入口

根目录示例的包名为 `dev.helloface.uniapp.demo`，独立 uvue 示例为 `dev.helloface.uniappx.demo`。两者各自使用 AppID、签名和基座，共享规范插件源码。

1. 在 HBuilderX 配置有效 AppID、Android 包名和自己的调试签名。
2. 执行 `npm run android:base` 制作基座；手工制作时先执行 `npm run android:prepare`。
3. 连接手机并授权 USB 调试，执行：

```sh
npm run android:devices
npm run android:check
npm run android:run
npm run android:dev       # Vue 页面修改后自动重新同步
npm run android:logs -- --follow
```

Vue 默认由 App 进程替换页面资源，相同基座会自动跳过安装。`--device 序列号` 可明确选择设备；`--skip-install` 严格核对手机与本机 APK。`--hbuilder` 使用 HBuilderX 自身运行通道。uvue 使用 `--project examples/uni-app-x`，由 HBuilderX 原生编译运行；先配置自身 AppID、执行 `demo:prepare` 并制作对应基座。

这些命令行工具运行前检查 SDK、源码指纹、基座版本、AppID/包名、API/ABI、模型不压缩和 16KB 对齐，并在原生代码或宿主配置改变后要求重建。这是页面同步工具的保守策略；源码日常调试可直接使用 HBuilderX 本地联编，不必每次云打包。运行过程不卸载 App；本机录入数据保留。签名配置、断点操作、资源同步协议、缓存迁移、日志和排错见 [Android 调试与实现](ANDROID_DEBUG.md)。

脚本优先使用 `ANDROID_HOME` / `ANDROID_SDK_ROOT` 对应的有效 ADB，再尝试常见 SDK 目录和 PATH。`HBUILDERX_PATH` 指向 `Contents/HBuilderX`；macOS 默认使用 `/Applications/HBuilderX.app`。

更新 SDK 或原生桥接代码后，可运行 [Android 原生集成检查](../tests/android/README.md)，需要可调试基座及对应签名。

### 云端路径

在 HBuilderX 中配置 AppID、Android 包名和签名，选择 Android 云打包。调试时按运行流程生成包含本插件的自定义基座；发行时生成正式 APK/AAB。

### 本地路径

1. 使用 HBuilderX 的“本地打包 / 生成本地打包 App 资源”入口导出资源。
2. 准备与 HBuilderX 及渲染模式匹配的 DCloud Android 原生 SDK，按其文档配置 Android Studio 宿主工程。
3. 按 UTS 插件配置文档集成导出的插件模块、Kotlin 源码和原生依赖；`config.json` 中的 AndroidX / CameraX 依赖也必须加入对应模块。AAR 要同时进入需要它的插件编译与宿主打包依赖。
4. 合并相机权限和 `HelloFaceVerifyCameraActivity` 的清单声明，配置模型不压缩、ABI 和签名，通过 Gradle 构建。

本插件的额外要求：

- 最低 Android API 23，ABI 为 `arm64-v8a` / `armeabi-v7a`。
- `hiface-0.8.8.aar` 位于插件的 `utssdk/app-android/libs`。
- 宿主应用模块必须配置模型不压缩，供原生 SDK 映射读取：

```groovy
android {
    androidResources {
        noCompress += 'bphfm'
    }
}
```

HBuilderX 云端配置由 `manifest.json` 的 `aaptOptions: ["noCompress 'bphfm'"]` 提供：uni-app 位于 `app-plus.distribute.android`；uni-app x 位于 `app-android.distribute`。已有两个示例均包含此项。本地原生工程也需在宿主 Gradle 中显式设置。[Android UTS 配置](https://doc.dcloud.net.cn/uni-app-x/native/use/androiduts.html)

### 16KB 对齐检查

每次更新原生 SDK、宿主运行时或其他原生依赖，都要检查最终安装包：

```sh
npm run android:alignment
python3 scripts/check_android_alignment.py /本机路径/release.apk --report unpackage/validation/android-16kb.json
```

默认检查锁定版本的 SDK AAR 和 `unpackage/debug/android_debug.apk`。检查覆盖所有 ARM64 / x86_64 动态库的 ELF LOAD 对齐、虚拟地址与文件偏移的一致性、RELRO 是否与后续可写数据共用 16KB 页，以及 APK 内未压缩动态库的数据偏移。压缩存储的库仍必须通过 ELF 检查。`android:run` 在安装前执行同一检查，失败时停止安装。

根目录 uni-app 示例设置 `app-plus.distribute.android.enableOAID: false`，排除默认 OAID SDK。该 SDK 的 `lib39285EFA.so` 在旧基座中未通过 RELRO 检查；本示例的人脸采集、加密保存和 1:1 验证不依赖 OAID。本地打包也应从宿主移除未使用的 OAID AAR。独立 uni-app x 宿主以及业务 App 仍需检查各自最终 APK，插件 AAR 通过不代表整个 App 通过。[DCloud 官方说明](https://uniapp.dcloud.net.cn/tutorial/android-16kb.html#oaid)

还应使用 Android SDK Build-Tools 35+ 的 `zipalign -c -P 16 4 app.apk` 复核，随后在真实 16KB 环境中运行。用 `adb shell getconf PAGE_SIZE` 确认环境：`16384` 才是 16KB；`4096` 手机上的正常运行只能证明 4KB 环境下的兼容性。[Android 官方检查方法](https://developer.android.com/guide/practices/page-sizes)

## iOS

### 云端路径

在 HBuilderX 中配置 AppID、Bundle ID 和签名，选择 iOS 云打包或制作自定义基座。需要确认所选云环境能编译当前 SDK；当前验证记录未包含成功的云端 IPA 构建。

### 本地路径

1. 使用 Mac，安装能编译上游 Swift 6.1.2 SDK 的 Xcode；本项目记录的要求为 Xcode 16.3+。
2. 从 HBuilderX 导出本地打包资源，准备对应版本与模式的 DCloud iOS 原生 SDK，并按官方文档配置 Xcode 宿主及 UTS 插件工程。
3. 集成插件 Swift 源码、UTS 编译产物及 `HiFace.xcframework`、`HiFaceNative.xcframework`；保留 SDK 模型资源和隐私清单，按照依赖库类型完成链接/嵌入配置。
4. 合并插件 `Info.plist` 的相机用途描述，最低部署版本设为 iOS 15，并配置自己的签名、Archive / Export 生成 IPA。

本机当前为 Xcode 15.2。`npm run ios:check` 可执行 Swift 语法、真实 UIKit 视图类型及纯状态检查，并通过仅供编译的 SDK 边界检查平台接入类型；不能据此声称真实 SDK 已编译。选择兼容 Xcode 后执行 `npm run ios:check -- --full`，再完成完整 App 链接、签名和真机验证。功能对照、断点和验收清单见 [iOS 功能与调试](IOS_DEBUG.md)。[iOS UTS 原生工程配置](https://doc.dcloud.net.cn/uni-app-x/native/use/iosuts.html)

## HarmonyOS 鸿蒙

HBuilderX 官方鸿蒙流程在本机调用 DevEco 工具链完成构建，不需要提交到 Android/iOS 云打包队列。[鸿蒙运行与发行说明](https://doc.dcloud.net.cn/uni-app-x/app-harmony/)

1. 安装并在 HBuilderX 中配置 DevEco Studio。当前上游 SDK 使用 DevEco Studio 26，最低运行 API 20，ARM64。
2. 在目标示例中配置自己的 AppID、鸿蒙 Bundle Name 和签名。
3. 确认插件 `utssdk/app-harmony/libs/hiface-0.8.8.har` 已安装，`config.json` 能解析该依赖；相机权限及原因字符串由插件 `module.json5` 和 `resources` 提供。
4. 在 HBuilderX 中选择鸿蒙真机运行；正式打包使用“发行 → App-Harmony-本地打包 → 生成安装包”，完成本地编译和签名。

当前已完成根 Vue3 示例的完整 HAP 构建、签名、安装及鸿蒙 API 26 真机运行。本机匹配的调试签名配置在被 Git 忽略的 `harmony-configs/build-profile.json5`，其他电脑需配置自己的身份及匹配 Profile。独立 uni-app x 完整 App、HarmonyOS 6 实机及真人用例的验收边界见 [验证记录](VALIDATION.md)。两套示例的最低鸿蒙版本均固定为 `6.0.0(20)`，以满足真实 HAR 的 API 20 要求。

本工程的设备连接、签名匹配、CLI 运行、断点、日志和修改后重建步骤见 [鸿蒙真机运行与调试](HARMONY_DEBUG.md)。

## 发布前验证

```sh
npm run check
```

这条命令执行三端页面配置同步检查、API、示例、SDK 安装器和 Android 调试/对齐自动化测试、完整三端 SDK 文件校验和 UTS 转换。如果只安装了单端 SDK，可以单独执行 `python3 scripts/install_sdk.py --check --platform android` 等对应检查；完整 `npm run check` 需要三端 SDK 文件。

随后按所选平台实际构建安装包、安装到真机，验证录入、本人/他人识别、活体拒绝、权限拒绝、取消、后台释放和特征保存。已有结果及待验项见 [验证记录](VALIDATION.md)。
