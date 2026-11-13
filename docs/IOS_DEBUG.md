# iOS 功能对齐与调试

规范源码位于 `uni_modules/HelloFace-Verify/utssdk/app-ios`。根 Vue 示例与独立 uvue 示例调用同一套公开 API，修改插件后执行 `npm run demo:prepare` 同步副本。

## 与 Android、鸿蒙的功能对应

| 功能 | iOS 当前实现 | 验证边界 |
| --- | --- | --- |
| 录入、1:1 验证及四种静默/动作组合 | 与共享 UTS 参数、四种动作及 SDK 判定一致 | iOS 真人识别与活体待验 |
| `detectLiveness` / `extractFaceFeature` / `getFaceStatue` | 独立活体始终静默，可叠加动作；纯图片提取不保存；状态查询只读返回 exists | 共享 API 合同通过；SDK、Keychain 真机待验 |
| 图片/特征同步、特征读写/删除、临时基准 | 已有；临时基准不读写本机，图片支持 PNG/JPEG、EXIF 矫正与相同限制 | iOS 图片提取与 Keychain 真机待验 |
| 录入确认、缺图保护、重拍及取消 | 居中小图确认；缺图不能确认，确认前不改写基准；重拍等待旧帧及相机会话停止 | UIKit 类型、生命周期状态检查；实机待验 |
| 录入稳定圆环与动作倒计时 | 三端均支持；稳定提示约 0.7 秒，动作按整个序列倒计时并显示秒数，换动作不重置 | iOS 状态及 UIKit 检查，真实动画待验 |
| 前后置、方向与镜像 | 竖屏预览，前置显示镜像；SDK 收到无镜像像素与前置标记 | AVFoundation 类型检查，实际画面待验 |
| 分辨率与实际帧约束 | 优先 VGA 640×480，不支持时用 medium；实际帧须为正偶数尺寸且符合 SDK 长短边上限，否则报相机错误 | 帧尺寸状态检查通过；实际设备协商待验 |
| 重复调用、旧事件、取消及后台退出 | 共用操作槽；SDK 与暂停回调使用同一代次门闩；关闭后不再重启 | 状态检查，真实权限/前后台时序待验 |
| 首次权限拒绝/提前取消 | 授权后才初始化 SDK；等页面弹出和资源关闭完成后回调 | 类型及状态检查，系统授权弹窗待验 |
| 会话中断、相机或 SDK 报错 | 监听系统通知；首个错误即停止送帧并阻止 resume，随后释放资源 | AVFoundation 类型检查，真实中断待验 |
| 满亮、退出恢复、保持常亮 | 确认/重拍保留原快照；后台、取消、报错及离页恢复 | iOS 真机待验 |

平台实现方式有必要差异：iOS 使用 AVFoundation、Keychain 和 UIScreen，Android 使用 CameraX、Keystore 和窗口亮度，鸿蒙使用 CameraKit、HUKS 和窗口亮度。统一的是业务接口和收尾行为，不将三端的系统组件或加密文件强行改成同一种格式。
三端确认照片仍由 SDK 0.8.11 提供固定 333×333 对齐预览。高清预览、确认后再提取特征属于共同的流程扩展，不是本次 iOS 功能缺项；SDK 已升级至 0.8.11；模型、阈值、用户 License 和存储格式保持不变。

## 本机能执行的检查

```sh
npm run check
npm run ios:check
npm run demo:prepare
```

`ios:check` 要求 macOS 和 Xcode，分四层输出结果：

1. 解析插件所有 Swift 文件。
2. 编译并实际执行 `HelloFaceVerifyCameraState.swift` 的纯状态检查，覆盖圆环、代次隔离、关闭顺序和帧尺寸；不模拟人脸采集或识别成功。
3. 用真实 iOS SDK 类型检查 UIKit 视图、圆环和状态代码，不替换识别 SDK。
4. 用仅供编译的 HiFace 边界声明检查全部 UIKit/AVFoundation/Keychain 接入代码。边界方法全部为 `fatalError`，位于 `tests/ios`，不会复制到插件或链接进 App；这一步不代表真实 HiFace SDK 已编译或运行。

选择兼容当前 SDK 的 Xcode 后，进一步执行：

```sh
xcodebuild -version
xcrun swiftc --version
npm run ios:check -- --full
```

`--full` 使用已安装的真实 HiFace/HiFaceNative framework 类型检查全部源码，失败会返回非零状态。2026-11-13 本机仍为 Xcode 15.2，不支持 SDK 所需的 Swift 6，完整 SDK 类型检查受阻。局部类型检查、UTS 转换、完整 App 链接/签名和真机验收分别记录，不能互相替代。

平台类型检查同时开启严格并发诊断，通知处理和 UTS 回调显式路由到主 actor，并保留 iOS 15 的最低版本。旧 iOS 17.2 SDK 的 `UIAccessibilityTraits.updatesFrequently` 与 `UIAccessibility.Notification.screenChanged` 声明仍触发共享全局状态警告；该读取在 UIKit 视图的主 actor 内，保留可访问性提示，待兼容新版 Xcode 的完整检查复核。

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
| `HelloFaceVerifyCameraView.updateCaptureProgress / updateActionCountdown` | 录入稳定与动作倒计时独立，重复阶段不重启，离页重置 |
| `HelloFaceVerifyCameraPipeline.configure` / `pause` / `emitError` / `close` | 实际帧尺寸、停止后重拍、会话中断及首次错误后拒绝帧/重启 |
| `ReferenceStore` / `FaceImageImporter` | Keychain 状态码、图片方向及真实 SDK 提取错误 |

Xcode 控制台和设备日志只记录阶段、状态码、时序；不要输出 HF1、原照片、Base64 或签名信息。分别检查相机拒绝、快速取消、重拍、连续调用、前后置、后台、锁屏/来电中断、亮度恢复、真人录入、本人/他人比对及动作活体。没有 iPhone 时这些项目保留待验收，不输出模拟识别成功。

平台接口依据：[相机会话中断](https://developer.apple.com/documentation/avfoundation/avcapturesession/wasInterruptedNotification)、[预览方向](https://developer.apple.com/documentation/avfoundation/setting-up-a-capture-session)、[相机连接镜像](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/isvideomirrored)。

重拍的暂停屏障依据 [AVCaptureSession.stopRunning](https://developer.apple.com/documentation/avfoundation/avcapturesession/stoprunning()) 的同步停止语义：在送帧串行队列停止会话，回主 actor 核对当前代次后才创建新请求。帧限制读取锁定 SDK 的 `HiFaceCameraFrame.maximumLongSidePixels / maximumShortSidePixels`，不改变采集预设、SDK 版本或业务阈值。
