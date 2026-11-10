# 原生相机界面

Android、iOS、HarmonyOS 共用同一套视觉布局：浅色背景、圆形相机取景区、动态操作提示、设备端处理标识、底部采集建议和隐私说明。界面参考 HelloFace 的圆形取景与录入确认流程，使用各平台原生控件实现。

录入分为“人脸采集”和“确认保存”两步。采集完成后显示预览，可以重新采集或确认录入；没有有效预览时禁止确认，保存期间禁用返回和重复提交。只有确认后才加密保存特征，预览照片不持久化。

识别过程中显示 SDK 当前阶段、动作要求和真实步骤数。SDK 完成后立即返回调用方，沿用原来的回调契约；业务页面负责展示通过或未通过。未增加延迟返回或额外的结果页。

圆形遮罩只影响显示，不裁切送入 SDK 的原始相机帧，也不改变 SDK 坐标或比对参数。前置相机的确认照片只在显示时镜像。重新采集会取消旧请求并隔离旧回调；退出时释放相机和预览资源。相机界面仅在自身显示期间保持屏幕常亮，iOS 与鸿蒙退出时恢复此前状态。

## 预览缩放

三端实时画面均按原比例居中容纳，避免为了铺满长屏而额外裁剪放大。不匹配的空余区域使用页面背景色；圆形取景遮罩仍保留，不会改变 SDK 的输入帧或验证配置。

| 平台 | 实时预览 | 录入确认照片 |
| --- | --- | --- |
| Android | `PreviewView.ScaleType.FIT_CENTER` | `ImageView.ScaleType.FIT_CENTER` |
| iOS | `AVCaptureVideoPreviewLayer.videoGravity = .resizeAspect` | `UIImageView.contentMode = .scaleAspectFit` |
| HarmonyOS | 按实际预览流旋转后的宽高比计算居中容纳区域，`RenderFit.RESIZE_CONTAIN` | `ImageFit.Contain` |

Android 原生 XML 中应使用 `app:scaleType="fitCenter"`，对应命名空间为 `http://schemas.android.com/apk/res-auto`；`android:scaleType` 不能代替 PreviewView 的自定义属性。本工程使用 Kotlin 创建控件，直接设置 scaleType。默认的 FILL_CENTER 会在容器与源画面比例不一致时裁剪，见 [CameraX 官方说明](https://developer.android.com/reference/androidx/camera/view/PreviewView.ScaleType)。iOS 对应配置见 [videoGravity](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/videogravity)。

鸿蒙使用相机实际输出尺寸，在 90°/270° 时交换显示宽高，并使 XComponent 保持同一比例；不是单纯把相机表面拉伸到全屏。预览表面锁定旋转，与已有相机输出的旋转锁定配置一致，见 [鸿蒙预览说明](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/camera-preview/)。分析输出、NV21 格式和送帧旋转参数保持原样。

确认照片本身是 SDK 产生的对齐人脸区域，可能比实时预览紧凑；等比显示避免的是二次裁剪，不会把 SDK 人脸图还原为完整相机场景。

Android 的界面位于 `HelloFaceVerifyCameraView.kt`，iOS 位于 `HelloFaceVerifyCameraView.swift`，鸿蒙位于 `HelloFaceVerifyCamera.ets`。外部集成仍直接调用原插件 API，Vue/uvue 示例不增加界面封装层。修改这些原生文件后须重建相应基座；仅同步页面资源不会更新原生界面。

编译、设备及算法验收范围见 [验证记录](VALIDATION.md)。
