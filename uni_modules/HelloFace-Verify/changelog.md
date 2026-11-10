## 0.1.2 (2026-11-10)

- 统一三端参数默认值、类型提示和运行时校验，补充完整接入说明；修正市场文档中过期的动作超时范围。
- verifyFace 增加可选 referenceFeature + featureSpaceID，直接传入业务基准且不改写本机数据；兼容原有 faceID 用法。
- 每次调用只触发一次终态与 complete；屏蔽迟到进度，损坏桥接结果返回 BRIDGE_ERROR，错误增加 faceID。
- complete 按官方 JS 桥接约定使用 any，分别在 success/fail 读取业务数据。
- cancel 支持省略参数；新增官方 UTS/Kotlin 编译检查，修正错误类属性初始化和默认参数的桥接类型兼容问题。
- iOS、鸿蒙取消等待资源释放后再回调成功，保存提交中保持 BUSY；Android 保证取消确认的收尾。
- 精简 Vue/uvue 示例为按钮列表和文本结果框。

- 完善 Android 调试：应用内页面资源替换、原生源码指纹与基座校验、一键制作基座、页面监听和按进程过滤的操作日志；调试入口只在可调试宿主中工作。
- 统一 Android、iOS、HarmonyOS 的原生录入与验证界面，增加圆形取景、动作提示、录入预览、重新采集及保存状态；保持插件 API 和示例调用简洁。
- 重新采集时隔离旧请求回调，确认前不保存基准；相机页面显示期间保持屏幕常亮，退出后释放资源并恢复状态。
- Android 示例排除不需要的默认 OAID SDK，新增 ELF LOAD、RELRO 和 APK ZIP 的 16KB 对齐检查，并在运行前拦截不合格基座。

## 0.1.1 (2026-11-09)
- 修复 Android 6 上 CameraX 分析器默认接口方法缺失导致的 `AbstractMethodError`；显式实现分析器接口，保持 API 23 支持。
- 修正 `actionTimeoutMs` 的校验范围为原生 SDK 要求的 2000–30000 毫秒，避免已通过插件校验的参数在 SDK 配置时失败。
- 修正三端实时送帧时将 SDK 临时 `BUSY` 误判为流程失败的问题；与 `NOT_READY` 一样跳过当前帧，真正的 SDK 错误和接口重复调用错误仍正常回传。
- 插件发布 ID 规范为 HelloFace-Verify（作者前缀 HelloFace，插件名 Verify），展示名称为 HelloFaceVerify；同步目录、导入、示例和安装脚本。
- 优化人脸识别、人脸比对、活体检测、离线人脸识别、鸿蒙五个关键词及市场介绍。
- 更正本机特征加密保存的隐私说明，补充独立插件文档与升级路径。
- 错误主题调整为 HelloFaceVerify；保留原有加密存储键，避免仅因更名而丢失已有基准。
## 0.1.0（2026-11-09）

- 基于 HelloFace 原生 SDK 0.8.8 的首版 UTS 1:1 封装。
- Android CameraX、iOS AVFoundation、HarmonyOS CameraKit 原生相机流程。
- 录入确认、按 faceID 验证、可选静默/动作活体、特征读取/同步/删除。
- Vue2 / Vue3 和 uvue 示例，统一类型、UniError、权限及取消处理。
- 原生 SDK 固定版本安装与 SHA-256 校验。
