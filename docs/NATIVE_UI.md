# 原生相机界面

Android、iOS、HarmonyOS 共用同一套视觉布局：浅色背景、圆形相机取景区、动态操作提示、采集建议和居中录入确认弹窗。界面参考 HelloFace 的圆形取景与录入确认流程，使用各平台原生控件实现。

## 三端共用配置

页面文案、配色、字号、布局尺寸、动作提示和警告阶段统一维护在插件的 [native-ui.json](../uni_modules/HelloFace-Verify/native-ui.json)。执行 `npm run ui:build` 生成 Kotlin、Swift、ArkTS 的 `HelloFaceVerifyPresentation`，再执行 `npm run demo:prepare` 同步独立 uvue 示例。三个原生页面直接使用生成的配置，调用方无需增加 UI 参数。

`npm run ui:check` 检查生成文件是否与配置一致，已加入 `npm run check`。修改页面时应先改配置并提交生成文件，避免单端文案或数值逐渐偏离；不需要接入方在打包时运行生成器。

三端统一使用“请左右摇头”“请缓慢点头”“请保持面部稳定”等引导。未生成预览时保留重新采集入口、禁用确认按钮；保存期间返回、重新采集、确认按钮全部禁用并使用相同透明度。预览和确认照片均等比显示，前置照片仅显示镜像。

业务调用、参数默认值、错误码、回调次数和结果字段由共用 UTS 层统一。录入只返回采集判定和已保存基准，相似度/活体分数为 `null`；读取/同步/删除/取消不返回识别判定或分数；身份验证返回 SDK 的相似度和活体分数，独立活体只返回活体分数；缺失或非有限数为 `null`。不根据分数改写 SDK 的 `passed`。

系统权限弹窗、状态栏安全区、字体渲染和相机硬件视角仍由操作系统/设备决定。统一的是插件可控的界面和行为，不能保证不同设备逐像素一致。

录入分为“人脸采集”和“确认保存”两步。采集完成后显示预览，可以重新采集或确认录入；没有有效预览时禁止确认，保存期间禁用返回和重复提交。只有确认后才加密保存特征，预览照片不持久化。

动态提示位于圆框上方，原固定说明已移除；三项采集建议统一使用 `tipsOffset: 73`。确认内容的显隐由 Dialog/遮罩层管理，不再逐个切换旧全屏确认控件。

确认弹窗照片下方的两条说明使用独立的 `dialogTextGap`，间距由 16 缩至 8；照片、标题和按钮区域仍沿用原有间距。三端滚动内容高度同步计算，避免缩小文字间距后留下多余空白。

识别过程中显示 SDK 当前阶段、动作要求和真实步骤数。SDK 完成后立即返回调用方，沿用原来的回调契约；业务页面负责展示通过或未通过。未增加延迟返回或额外的结果页。

圆形遮罩只影响显示，不裁切送入 SDK 的原始相机帧，也不改变 SDK 坐标或比对参数。前置相机的确认照片只在显示时镜像。重新采集会取消旧请求并隔离旧回调；退出时释放相机和预览资源。相机界面仅在自身显示期间保持屏幕常亮，iOS 与鸿蒙退出时恢复此前状态。

## 预览缩放

三端实时画面均按原比例居中容纳，避免为了铺满长屏而额外裁剪放大。不匹配的空余区域使用页面背景色；圆形取景遮罩仍保留，不会改变 SDK 的输入帧或验证配置。

| 平台 | 实时预览 | 录入确认照片 |
| --- | --- | --- |
| Android | `PreviewView.ScaleType.FIT_CENTER` | `ImageView.ScaleType.FIT_CENTER` |
| iOS | `AVCaptureVideoPreviewLayer.videoGravity = .resizeAspect` | `UIImageView.contentMode = .scaleAspectFit` |
| HarmonyOS | 按实际预览流旋转后的宽高比计算居中容纳区域，`RenderFit.RESIZE_CONTAIN` | `ImageFit.Contain` |

Android 使用 Kotlin 原生控件并设置 FIT_CENTER，iOS 使用 resizeAspect；配置含义见 [CameraX](https://developer.android.com/reference/androidx/camera/view/PreviewView.ScaleType) 和 [AVFoundation](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/videogravity)。

鸿蒙使用相机实际输出尺寸，在 90°/270° 时交换显示宽高，并使 XComponent 保持同一比例；不是单纯把相机表面拉伸到全屏。预览表面锁定旋转，与已有相机输出的旋转锁定配置一致，见 [鸿蒙预览说明](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/camera-preview/)。分析输出、NV21 格式和送帧旋转参数保持原样。

确认照片本身是 SDK 产生的对齐人脸区域，可能比实时预览紧凑；等比显示避免的是二次裁剪，不会把 SDK 人脸图还原为完整相机场景。

Android 的界面位于 `HelloFaceVerifyCameraView.kt`，iOS 位于 `HelloFaceVerifyCameraView.swift`，鸿蒙位于 `HelloFaceVerifyCamera.ets`。外部集成仍直接调用原插件 API，Vue/uvue 示例不增加界面封装层。调整共用配置后执行 `ui:build`，然后通过 HBuilderX 的相应平台本地工具链重新编译运行；已具备 SDK/依赖时无需仅为混编源码改动重新云打包。iOS 需要兼容的 Xcode，鸿蒙需要 DevEco。仅同步 Vue 页面资源不会更新原生界面；SDK、原生资源或 Manifest 变更仍需重建基座/宿主。

编译、设备及算法验收范围见 [验证记录](VALIDATION.md)。
