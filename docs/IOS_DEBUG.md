# iOS 功能对齐与调试

规范源码位于 `uni_modules/HelloFace-Verify/utssdk/app-ios`。根 Vue 示例与独立 uvue 示例调用同一套公开 API，修改插件后执行 `npm run demo:prepare` 同步副本。

## 与 Android、鸿蒙的功能对应

| 功能 | iOS 当前实现 | 验证边界 |
| --- | --- | --- |
| 录入、静默验证、四种动作及组合 | 已有，默认参数与 SDK 判定保持一致 | 真实识别与活体待真机 |
| 图片/特征同步、特征读写/删除 | 已有，与三端共享参数校验和返回码 | UTS 合同检查通过；iOS Keychain 与图片提取待真机 |
| 显式临时基准 `referenceFeature` | 已有，验证不读写本机基准 | API 合同检查通过，待真机 |
| 录入确认、预览缺失、重拍、确认前取消 | 已有，预览缺失时禁止确认 | UIKit 类型与状态检查通过，待真机 |
| 录入稳定圆环 | 本次补齐：HOLD_STILL 时 0.7 秒蓝色圆环；异常阶段/重拍/退出重置，不触发识别成功 | 真实 UI 类型及状态检查通过，动画观感待真机；与鸿蒙对应，Android 目前仍为静态圆框 |
| 前后置、方向与镜像 | 本次显式配置预览方向和镜像；送入 SDK 的帧保持无镜像并附前置镜像标记 | AVFoundation 类型检查通过，实际画面待真机 |
| 分辨率协商 | 仍优先 VGA 640×480，设备不支持时尝试系统 medium 预设，无法配置则报错 | 能力检查已补；具体设备尺寸待真机 |
| 重复调用、迟到回调、取消、后台退出 | 已有互斥和代次隔离；本次补齐弹出动画未完成时取消/拒绝权限的收尾等待 | 状态检查覆盖两种完成顺序及重复终态，实际弹出/关闭待真机 |
| 首次权限拒绝/提前取消 | 本次调整为授权后创建 SDK 管线；未创建管线时直接收尾，不为关闭页面额外初始化 SDK | 平台代码类型检查通过，系统授权弹窗待真机 |
| 相机被占用、会话中断或运行异常 | 本次补齐通知监听并返回错误/取消，统一释放资源 | AVFoundation 类型检查通过，实际系统中断待真机 |
| 页面满亮、退出恢复、保持常亮 | 已有；确认/重拍保留原始亮度快照，后台及离页恢复 | iOS 待真机，不能沿用 Android/鸿蒙的真机结果 |

三端确认照片仍由 SDK 0.8.8 提供固定 333×333 对齐预览。高清预览、确认后再提取特征属于共同的流程扩展，不是本次 iOS 功能缺项；本次未更换 SDK、模型、阈值、License 或存储格式。

## 本机能执行的检查

```sh
npm run check
npm run ios:check
npm run demo:prepare
```

`ios:check` 要求 macOS 和 Xcode，分四层输出结果：

1. 解析插件所有 Swift 文件。
2. 编译并实际执行 `HelloFaceVerifyCameraState.swift` 的 20 项纯状态检查；不模拟人脸采集或识别成功。
3. 用真实 iOS SDK 类型检查 UIKit 视图、圆环和状态代码，不替换识别 SDK。
4. 用仅供编译的 HiFace 边界声明检查全部 UIKit/AVFoundation/Keychain 接入代码。边界方法全部为 `fatalError`，位于 `tests/ios`，不会复制到插件或链接进 App；这一步不代表真实 HiFace SDK 已编译或运行。

选择兼容当前 SDK 的 Xcode 后，进一步执行：

```sh
xcodebuild -version
xcrun swiftc --version
npm run ios:check -- --full
```

`--full` 使用已安装的真实 HiFace/HiFaceNative framework 类型检查全部源码，失败会返回非零状态。2026-11-11 本机仍为 Xcode 15.2，不支持 SDK 所需的 Swift 6，完整 SDK 类型检查受阻。局部类型检查、UTS 转换、完整 App 链接/签名和真机验收分别记录，不能互相替代。

平台类型检查同时开启严格并发诊断，通知处理和 UTS 回调显式路由到主 actor，并保留 iOS 15 的最低版本。旧 iOS 17.2 SDK 的 `UIAccessibilityTraits.updatesFrequently` 声明仍触发一条共享全局状态警告；该读取在 UIKit 视图的主 actor 内，保留可访问性提示，待兼容新版 Xcode 的完整检查复核。

## 构建与断点

1. 使用兼容 SDK 的 Xcode；在 HBuilderX 配好当前 AppID、iOS Bundle ID 和自己的签名。保留已有标识与 License，权限说明来自插件 `Info.plist` 的 `NSCameraUsageDescription`。
2. 通过仓库已有的 [本地或云端构建流程](BUILDING.md#ios) 制作含真实两个 xcframework 的完整 App/自定义基座；仅刷新 Vue 页面不能更新 Swift 原生源码。
3. 用 Xcode 打开按该流程准备的原生宿主工程，连接、信任并授权自己的 iPhone，选择 debug 构建，保留数据更新安装。
4. 在 Vue/uvue 回调处看 `code / msg / passed`；在 `app-ios/index.uts` 看原生方法和参数。在 Swift 中按以下位置设断点：

| 位置 | 观察内容 |
| --- | --- |
| `HelloFaceVerifyOperation.invoke` | activeID、重复调用、临时基准、当前前台 presenter |
| `HelloFaceVerifyCameraController` 的权限回调 / `presentationDidFinish` / `finish` | 权限晚到、快速取消、资源关闭与弹出动画的先后顺序 |
| 同文件 `progress` / `result` / `confirm` | SDK 的真实阶段/结果、确认前不保存、重拍隔离 |
| 同文件 `maximizeBrightness` / `restoreBrightness` | 原屏幕亮度快照及前后台恢复 |
| `HelloFaceVerifyCameraView.updateCaptureProgress` | 圆环重复阶段不重启，异常阶段及离页重置 |
| `HelloFaceVerifyCameraPipeline.configure` / `reportSessionError` / `close` | 实际相机规格、前后置方向、会话中断、关闭后拒绝帧和重启 |
| `ReferenceStore` / `FaceImageImporter` | Keychain 状态码、图片方向及真实 SDK 提取错误 |

Xcode 控制台和设备日志只记录阶段、状态码、时序；不要输出 HF1、原照片、Base64 或签名信息。分别检查相机拒绝、快速取消、重拍、连续调用、前后置、后台、锁屏/来电中断、亮度恢复、真人录入、本人/他人比对及动作活体。没有 iPhone 时这些项目保留待验收，不输出模拟识别成功。

平台接口依据：[相机会话中断](https://developer.apple.com/documentation/avfoundation/avcapturesession/wasInterruptedNotification)、[预览方向](https://developer.apple.com/documentation/avfoundation/setting-up-a-capture-session)、[相机连接镜像](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/isvideomirrored)。
