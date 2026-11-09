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

## Android

### 真机调试入口

根目录示例的 Android 包名为 `dev.helloface.uniapp.demo`；独立 uvue 示例使用 `dev.helloface.uniappx.demo`，便于在同一手机安装两套示例。两套工程均关闭 uni统计；各自的 AppID、签名和原生基座按宿主工程配置。

1. 在 HBuilderX 的 `manifest.json` 可视化界面获取自己的真实 AppID 并保存，不能使用占位值 `__UNI__HELLOFACE` 制作云端基座。
2. 在 HBuilderX 的 Android 打包配置中选择制作自定义调试基座，包名与该工程的 `manifest.json` 一致，使用自己的调试证书或已配置的云端证书。新应用不支持旧公共测试证书；签名文件与密码不要提交 Git。
3. 确认产物保存到该工程的 `unpackage/debug/android_debug.apk`。连接手机、授权 USB 调试，然后执行：

```sh
npm run android:check
npm run android:run
# 多台设备时指定序列号：
npm run android:run -- --device 设备序列号
# 基座已经安装时，只同步和启动：
npm run android:run -- --skip-install
# 检查独立 uvue 工程（需先配置其 AppID 并制作对应基座）：
npm run android:check -- --project examples/uni-app-x
```

检查失败时不会退回标准基座。`android:check` 只读取配置、APK 和设备信息；`android:run` 安装完整 APK，并通过 HBuilderX 的“已安装基座”入口同步页面和启动。部分设备会显示系统安装确认，需要在手机上允许；取消或超时后脚本会结束，不会重复触发安装。

如果“已安装基座”启动命令停住，或者直接打开基座提示 `__uniappview.html` 无法打开，说明需要检查页面资源是否同步。根目录 Vue 示例提供备用命令：

```sh
npm run android:run -- --skip-install --sync-resources
```

此命令使用 HBuilderX 的 `appResource` 导出入口重新编译，核对资源 AppID 后，通过 ADB 同步到该示例包名的外部应用目录，再启动示例。已在华为 GRA-UL00 / Android 6.0 上验证页面资源同步；若设备拒绝写入该目录，需使用 HBuilderX 常规真机运行。此入口仅适用于 uni-app Vue2/Vue3，uvue 仍走其原生编译与运行流程。原生代码、SDK 或权限有变化时，仍须重建并安装自定义基座。

脚本使用 PATH 中的 `adb`，也可通过 `ANDROID_HOME` / `ANDROID_SDK_ROOT` 指定 Android SDK。`HBUILDERX_PATH` 使用与 UTS 检查相同的 HBuilderX 根目录；macOS 默认识别 `/Applications/HBuilderX.app`。

HBuilderX 的 Android UTS 开发配置还需要有效的 JDK、Android SDK 和 Gradle。当前 5.34 的依赖解析器支持 Gradle 7.5–8.x；配置的 Gradle 程序必须能正常执行 `--version`。文件存在但分发包缺少 JAR 时仍不能使用。修改路径可用 HBuilderX 设置界面或 CLI 的 `config set --key uts-development-android.gradleHome --value Gradle程序路径`。修改原生 SDK、依赖或权限后重新制作基座。

更新 SDK 或原生桥接代码后，可运行 [Android 原生集成检查](../tests/android/README.md)。该检查在已安装基座内执行真实 SDK 调用，覆盖加密存储、验证超时、忙碌与取消；需要连接真机及基座对应的调试签名。

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

## iOS

### 云端路径

在 HBuilderX 中配置 AppID、Bundle ID 和签名，选择 iOS 云打包或制作自定义基座。需要确认所选云环境能编译当前 SDK；当前验证记录未包含成功的云端 IPA 构建。

### 本地路径

1. 使用 Mac，安装能编译上游 Swift 6.1.2 SDK 的 Xcode；本项目记录的要求为 Xcode 16.3+。
2. 从 HBuilderX 导出本地打包资源，准备对应版本与模式的 DCloud iOS 原生 SDK，并按官方文档配置 Xcode 宿主及 UTS 插件工程。
3. 集成插件 Swift 源码、UTS 编译产物及 `HiFace.xcframework`、`HiFaceNative.xcframework`；保留 SDK 模型资源和隐私清单，按照依赖库类型完成链接/嵌入配置。
4. 合并插件 `Info.plist` 的相机用途描述，最低部署版本设为 iOS 15，并配置自己的签名、Archive / Export 生成 IPA。

本机此前检测到 Xcode 15.2，因此当前 iOS 仅完成 UTS 转换和 Swift 语法检查。升级 Xcode 后还需执行完整类型检查、链接、签名和真机验证。[iOS UTS 原生工程配置](https://doc.dcloud.net.cn/uni-app-x/native/use/iosuts.html)

## HarmonyOS 鸿蒙

HBuilderX 官方鸿蒙流程在本机调用 DevEco 工具链完成构建，不需要提交到 Android/iOS 云打包队列。[鸿蒙运行与发行说明](https://doc.dcloud.net.cn/uni-app-x/app-harmony/)

1. 安装并在 HBuilderX 中配置 DevEco Studio。当前上游 SDK 使用 DevEco Studio 26，最低运行 API 20，ARM64。
2. 在目标示例中配置自己的 AppID、鸿蒙 Bundle Name 和签名。
3. 确认插件 `utssdk/app-harmony/libs/hiface-0.8.8.har` 已安装，`config.json` 能解析该依赖；相机权限及原因字符串由插件 `module.json5` 和 `resources` 提供。
4. 在 HBuilderX 中选择鸿蒙真机运行；正式打包使用“发行 → App-Harmony-本地打包 → 生成安装包”，完成本地编译和签名。

当前已通过独立原生 HAR 模块构建，完整 uni-app / uni-app x App 及相机真机流程仍需验收。

## 发布前验证

```sh
npm run check
```

这条命令执行 31 项自动化测试、完整三端 SDK 文件校验和 UTS 转换。如果只安装了单端 SDK，可以单独执行 `python3 scripts/install_sdk.py --check --platform android` 等对应检查；完整 `npm run check` 需要三端 SDK 文件。

随后按所选平台实际构建安装包、安装到真机，验证录入、本人/他人识别、活体拒绝、权限拒绝、取消、后台释放和特征保存。已有结果及待验项见 [验证记录](VALIDATION.md)。
