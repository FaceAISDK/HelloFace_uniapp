# 2026-11-12 官方规范核对

核对基线：提交 `151904f`，HBuilderX 5.34、CameraX 1.5.2、DevEco Studio 26，锁定 FaceSDK 0.8.11 Beta（`dc60c7b15ebf8038fb73a752bcea3590bbd86eaf`）。前一轮 Demo 精简检查已完成，开始时 Git 工作区干净。本轮未升级依赖或改变公开 API、License、AppID、签名、阈值、存储键及覆盖语义。

## 已调整

Android 的 `ResolutionStrategy` 原本只设置 640×480 偏好及回退顺序，没有排除 SDK 不支持的候选。新增 CameraX `ResolutionFilter`，仅保留正偶数尺寸、长边 ≤1920、短边 ≤1080，保留 CameraX 已排好的顺序；没有合规绑定组合时沿用相机异常收尾。未放大分析图、改变默认采集目标或压缩确认图。

这是本插件满足锁定 SDK 输入约束的修复，并非 CameraX 要求所有应用使用同一分辨率。[CameraX 分辨率选择](https://developer.android.com/reference/androidx/camera/core/resolutionselector/ResolutionSelector)说明策略与过滤器的作用及无可用组合时的绑定异常；[ResolutionFilter](https://developer.android.com/reference/androidx/camera/core/resolutionselector/ResolutionFilter)允许过滤不适用尺寸；[锁定 SDK Android 指南](https://github.com/FaceSDKPro/HelloFace/blob/dc60c7b15ebf8038fb73a752bcea3590bbd86eaf/platforms/Android/docs/SDK.md#initialization-and-live-detection)明确要求偶数尺寸及 1920/1080 上限。

修正 [API 文档](API.md)中“faceID 始终必填”的概括，明确独立活体、纯图片提取不需要它，补齐结果表的 `exists` 及空 faceID 说明。插件 readme 补充三端分析尺寸的偏好和设备回退边界。

Android 读取已保存密文时，旧的共用密钥函数在密钥缺失后也会尝试生成新密钥。现在区分读写用途：读取仅取现有密钥，缺失直接进入既有 STORAGE_ERROR；只有保存分支允许新建。保证 getFaceStatue/getFaceFeature/验证前读取不会创建替代密钥。正常已录基准、保存行为、别名和密文格式不变。这是对插件“只读查询”契约的修复，不是新的加密方案。[Android Keystore 官方说明](https://developer.android.com/privacy-and-security/keystore)分别描述密钥生成与读取已有条目。

API 23 真机还暴露调试脚本误判：该厂商 shell 没有 sha256sum/getconf，报错文本却随返回码 0 到达。摘要现在校验格式后再接受，命令缺失则用公开 APK 字节核对；内存页从 getconf 或 smaps 实际读取，无法读取则显示未知。新增回归覆盖旧 shell 的假成功、有效摘要和不可读页大小；该修复依据本轮实测，不将厂商命令缺失描述为官方要求。详见 [旧系统调试](ANDROID_DEBUG.md#旧厂商系统的调试命令)。

## 已核对并保留的实现

| 范围 | 源码核对结论与官方依据 |
| --- | --- |
| UTS 类型和导出 | 十一个公开方法都有 options 类型；错误实现继承 UniError，保留已有错误主题和兼容码。complete 使用 any，只作收尾。[DCloud 插件规范](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-plugin.html)、[错误规范](https://doc.dcloud.net.cn/uni-app-x/err-spec.html)、[complete 桥接限制](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-uni-api.html#异步api中complete回调函数中的参数是any类型)。 |
| 参数与终态 | 共享层统一默认值、校验和结果归一化；终态先标记 ended，再调用业务回调，并在 finally 执行 complete。取消、权限和错误走 fail；正常识别拒绝保留 SDK 的 passed/outcome，不能因高相似度放行。该判定来自 SDK 流程契约；exactly-once 是插件既有回调契约。 |
| 三个新增接口 | detectLiveness 不读取基准，SDK 的独立入口始终包含静默活体；actions 只叠加动作。extractFaceFeature 复用图片导入器，不读写基准；getFaceStatue 只读/解密后返回 exists，存储异常不伪装成不存在。保留用户指定的 getFaceStatue 名称。[SDK Android 流程](https://github.com/FaceSDKPro/HelloFace/blob/dc60c7b15ebf8038fb73a752bcea3590bbd86eaf/platforms/Android/docs/SDK.md#static-images-capture-liveness-and-verification)、[iOS API](https://github.com/FaceSDKPro/HelloFace/blob/dc60c7b15ebf8038fb73a752bcea3590bbd86eaf/platforms/iOS/SDK/API.md)、[Harmony SDK](https://github.com/FaceSDKPro/HelloFace/blob/dc60c7b15ebf8038fb73a752bcea3590bbd86eaf/platforms/Harmony/SDK.zh-CN.md)。 |
| 相机权限 | 三端在主动启动相机流程时申请相机权限，纯提取/存储不申请；Android Manifest、iOS NSCameraUsageDescription、鸿蒙 module.json5 含用途声明。[Android 相机权限](https://developer.android.com/training/permissions/requesting)、[Apple 相机授权](https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:))、[DCloud 鸿蒙配置](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-for-harmony.html#module-json5)。 |
| Android 送帧 | 单分析线程、KEEP_ONLY_LATEST；同步 processFrame 返回后在 finally 关闭 ImageProxy，不直接关闭其内部 Media.Image。只解绑插件拥有的 UseCase。[CameraX 图像分析](https://developer.android.com/media/camera/camerax/analyze)。 |
| iOS 线程 | AVFoundation 配置、start/stop、送帧和 close 都在串行队列，避免同步 startRunning 阻塞主界面；SDK MainActor 回调用于 UI，迟到事件受代次/ended 限制。[Apple startRunning](https://developer.apple.com/documentation/avfoundation/avcapturesession/startrunning())、[锁定 SDK iOS 线程/帧所有权](https://github.com/FaceSDKPro/HelloFace/blob/dc60c7b15ebf8038fb73a752bcea3590bbd86eaf/platforms/iOS/SDK/API.md#live-detection-and-frame-ownership)。 |
| 鸿蒙资源 | NV21 分量 slice 为独立缓冲后释放源 Image；processFrame Promise 完成前保留副本，停止时等待在途帧再释放 receiver。授权后及异步启动边界检查 generation。ArkTS 原生桥保留显式对象类型。[ImageReceiver.release](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-image-imagereceiver)、[DCloud ArkTS 类型边界](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-for-harmony.html)。 |
| 满亮与恢复 | Android 保存窗口亮度（含跟随系统）；iOS 保存屏幕原值并在失活/离页时恢复；鸿蒙设置与恢复串行，避免快速取消的迟到操作覆盖原值。满亮是本项目需求，非平台要求。[Apple brightness](https://developer.apple.com/documentation/uikit/uiscreen/brightness)、[鸿蒙 setWindowBrightness](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-window-window)。 |
| 基准与取消 | 存储/图片/相机共用操作槽；取消只作用于相机，提交保存期间返回 BUSY；相机释放后确认取消。Android AES-GCM、iOS Keychain、鸿蒙 HUKS 的既有存储格式未变；读取/解密异常仍返回存储错误。没有迁移、覆盖或删除用户基准。 |
| Vue/uvue | 导入/调用受 APP 条件编译保护，uvue 使用事件和回调类型及 active-background-color；样式使用当前版本支持的属性。保留两个独立开关、四种组合、默认静默开/动作关、模式快照及直接 API 调用；未发现有价值的进一步封装。[switch 属性](https://doc.dcloud.net.cn/uni-app-x/component/switch.html)、[uvue CSS](https://doc.dcloud.net.cn/uni-app-x/css/)。 |

以上将官方明确的约束与本插件自己的契约分开记录；没有把代码风格、函数数量或行数作为官方规范。

## 验证边界

本轮实际检查和未验项记录在 [VALIDATION.md](VALIDATION.md)。源码核对、受控边界测试、原生模块编译、完整 App 与真人验收分别记录；不沿用旧版本真人结果，不把 iOS 编译边界替身当成真实 SDK。Demo 默认仍为一个 `demo-user`，同步文案及已移除的底部说明保持现状。
