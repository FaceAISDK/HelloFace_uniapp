# HelloFace 离线人脸识别与活体检测

为你的 uni-app / uni-app x 应用接入人脸录入、1:1 身份比对与活体检测，一套 UTS API 面向 Android、iOS、鸿蒙，适配 Vue2、Vue3、uvue。

自带原生采集、录入确认和动作引导界面；静默与动作活体按需组合，也可只验真人而不比对身份。支持导入已有的同模型人脸基准，减少重复录入，适合账号本人确认、签到核验与人员验证流程的技术评估。

功能介绍、接入示例和接口列表见 [插件使用说明](uni_modules/HelloFace-Verify/readme.md)。插件 ID：`HelloFace-Verify`；底层 SDK：HelloFace 0.8.11 Beta。

## 运行示例

1. 从插件市场导入完整插件和示例，确认 `uni_modules/HelloFace-Verify` 含目标平台 SDK；源码中缺失的 SDK 可按 [开发维护](#开发维护)说明补齐。
2. 用 HBuilderX 导入根目录，配置自己的 AppID、包名和签名，按 [打包指南](docs/BUILDING.md)运行到真机。默认 Vue3；Vue2 将 `manifest.json` 的 `vueVersion` 改为 `"2"`。
3. uni-app x 示例需把根目录的 `uni_modules/HelloFace-Verify`、`app-icons`、`demo`、`static` 及公开配置 `harmony-configs/entry`、`harmony-configs/AppScope` 复制到 `examples/uni-app-x` 对应目录，再单独导入并配置。可选用 `npm run demo:prepare` 自动同步，该辅助命令需要 Python；私有签名配置单独维护。

Android / iOS 可选云端制作基座或完整本地构建，鸿蒙使用本地 DevEco 工具链。运行产物必须包含真实 SDK；Android 模型不压缩配置见 [插件接入说明](uni_modules/HelloFace-Verify/readme.md#接入)。修改 SDK、依赖、权限或资源后需重建。
**集成到应用后一个CPU架构仅新增10MB左右体积(Android可以配置仅支持ARM64位CPU)**
**使用完整插件运行 Demo 不需要 Python，也不强制在线制作自定义基座。**

## 环境要求

| 项目 | 要求 |
| --- | --- |
| HBuilderX | 5.34+，安装对应 UTS 原生运行扩展 |
| Android | Android 6.0 / API 23+，ARM64 / ARMv7 |
| iOS | iOS 15+；本地构建需兼容 Swift 6.1.2 的 Xcode（16.3+） |
| HarmonyOS | API 20+，ARM64，DevEco Studio 26 |

Web、小程序不支持此插件。各平台实际编译与真机结果见 [验证记录](docs/VALIDATION.md)；iOS 尚未完成真实 SDK 完整编译和真机验证。

## Demo 与接入

所有演示操作共用当前 `faceID`，默认 `demo-user`。1:1 验证用两个独立开关演示静默/动作的四种组合，默认静默开、动作关。动作开启后可勾选眨眼、张嘴、摇头、点头，默认眨眼和点头，至少保留一项。独立活体无需基准，始终包含静默活体，动作单独勾选。

“同步演示人脸图片”和“同步演示人脸特征”使用内置 [AI 演示基准](demo/README.md)，会覆盖当前 `faceID` 的本机基准。

业务工程集成安装完成的 `uni_modules/HelloFace-Verify`，从 `@/uni_modules/HelloFace-Verify` 导入。最小调用及 11 个 API 见 [插件 README](uni_modules/HelloFace-Verify/readme.md)，完整参数与错误码见 [API 参考](docs/API.md)。

## 开发维护

以下为源码开发维护流程，使用完整插件接入业务或运行 Demo 无需执行这些脚本。

GitHub 仓库不附带大型 SDK 二进制。开发者可使用 Python 3.9+、curl 和网络安装、校验 SDK：

```sh
python3 scripts/install_sdk.py
python3 scripts/install_sdk.py --check
```

仅安装单端可加 `--platform android`、`--platform ios` 或 `--platform harmony`；也可按 `sdk-artifacts.json` 手动放置对应 SDK 文件。

插件只维护根目录 `uni_modules/HelloFace-Verify`。修改后执行 `npm run demo:prepare` 同步 uvue 副本；修改共用原生页面配置 `native-ui.json` 后，先执行 `npm run ui:build`。

```sh
npm ci --ignore-scripts
npm run check               # 页面配置、测试、SDK 校验与三端 UTS 转换
npm run android:alignment   # SDK AAR / 最终 APK 的 16KB 对齐检查
```

这些检查不代替完整 App 构建或真机验收。更多说明：[代码结构](docs/CODE_STRUCTURE.md)、[原生页面](docs/NATIVE_UI.md)、[应用图标](app-icons/README.md)、[Android 调试](docs/ANDROID_DEBUG.md)、[iOS 调试](docs/IOS_DEBUG.md)、[鸿蒙调试](docs/HARMONY_DEBUG.md)。

## 体验与联系

- 🌍 **网站说明**：[HelloFace SDK](https://helloface.dev/)
- 📧 **EMAIL**：[FaceAISDK.Service@gmail.com](mailto:FaceAISDK.Service@gmail.com)
- 📱 **APK 下载**：[下载体验 APK](https://www.pgyer.com/HelloFace)

## 许可

The wrapper and example code are provided for technical exchange and evaluation purposes only. See [LICENSE](LICENSE). The native SDK, models, and resources remain subject to the upstream `Hello Face Test Only` terms. Upstream currently states that its models are not intended for children under 12 or financial use.
