## 0.2.0 (2026-11-12)
- 身份验证和独立活体的每步动作默认超时调整为 3 秒；显式传入的 actionTimeoutMs 继续生效，范围仍为 2000–30000 毫秒。
- 新增 detectLiveness：无需基准的独立活体，默认静默，可叠加动作；沿用进度、取消与相机资源释放。
- 新增 extractFaceFeature：Base64 图片只提取，不保存或覆盖基准；复用现有图片限制与解码流程。
- 新增 getFaceStatue：只读返回 exists，不输出特征；缺少基准成功返回 false，读取错误仍走 fail。
- 三端复用参数校验、结果回调和错误码，旧接口兼容；新增原生方法需要重新联编/构建基座。

- 新增 syncFaceImage / syncFaceFeature：同步外部 Base64 图片或同模型 HF1 基准，无需本机重新录入；保留 setFaceFeature。
- 三端使用通用 extractFeature 图片入口，统一 PNG/JPEG、大小限制、EXIF 方向、覆盖保护和空判定字段；新增 107–109 图片短错误码。
- Vue/uvue 增加两个直接调用示例，使用同一张 200×200 AI 人脸和压缩后图片经 SDK 提取的特征，统一使用当前 faceID（默认 demo-user），同步显式覆盖演示基准。

- 三端统一增加 code/msg：0 成功、1xx 操作问题、2xx 识别未通过、3xx 运行异常，使用短提示；SDK 判定和回调语义保持不变。
- 原 errCode、sdkCode、outcome 保留兼容，fail 的 errMsg 缩短为“方法名:fail 短提示”，原始说明移至 detail。Vue/uvue 示例直接展示 code/msg。
- Android 系统栏改用 AndroidX enableEdgeToEdge / SystemBarStyle，移除直接使用的已弃用 systemUiVisibility、SYSTEM_UI_FLAG_* 与系统栏颜色设置。
- Android 11 及以上使用原生 WindowInsets.getInsets 读取系统栏和挖孔安全区，Android 6–10 保留独立兼容分支；最低 Android 版本仍为 6.0。

- 底层 SDK 更新至锁定的 0.8.11 Beta；优化三端录入确认弹窗、圆框进度、导航对齐，以及进入相机页满亮和退出恢复。
- Android 相机候选增加 SDK 尺寸约束；基准只读查询在密钥缺失时返回存储错误，不生成替代密钥；取消等待送帧与资源释放完成。
- Vue/uvue 默认共用一个 faceID，提供独立活体入口、四种验证组合、四动作勾选和结果模式快照；未录入时立即提示。
- 精简接入说明，补充本地/云端打包与调试文档，优化示例资源体积。升级后需重新联编或构建包含原生依赖的基座/完整 App，不能只刷新页面。
- 验证范围：鸿蒙完整 Release App 的相机入口、取消/后台恢复、无人脸超时、同步/持久化/删除及亮度恢复已实测；新版真人识别与动作通过仍待配合，Android 新版及 iOS 完整 App 的未验项见验证记录。
## 0.1.5 (2026-11-12)
- 修复 Android 云基座与 HBuilderX 本地编译使用不同 Kotlin 模块名时，跨文件 internal 方法生成不同 JVM 名称、可能触发 NoSuchMethodError 的问题。
- 稳定原生桥接的 JVM 访问名称，增加真实 UTS/Kotlin 编译产物的 ABI 检查；升级本版需要重制一次基座。
- 完善 HBuilderX 运行、断点和日志说明：已有 SDK/依赖后，日常 `.uts` / `.kt` 源码可本地联编，不必每次云打包；区分命令行页面同步的保守指纹策略。
## 0.1.4 (2026-11-10)

- 三端原生录入、验证页面共用 native-ui.json：统一文案、动作引导、配色、字号、布局尺寸和按钮状态；新增生成脚本及同步检查，接入方不需要额外配置。
- 鸿蒙预览转换失败时保留重拍入口，与 Android、iOS 一致；Android、iOS 屏蔽确认期间重复采集结果。
- 统一 UTS 结果的空值契约：分数仅用于验证，特征管理和取消不携带识别判定，非有限分数按 null 返回；保持原有接口调用方式和 SDK 判定。
- 本次涉及原生代码，需要重新制作自定义基座或完整打包。

## 0.1.3 (2026-11-10)

- 三端实时预览改为等比居中显示，避免为铺满长屏而裁剪放大；Android 使用 FIT_CENTER，iOS 使用 resizeAspect，鸿蒙根据旋转后的预览比例适配容器并使用 RESIZE_CONTAIN。
- 录入确认照片改为等比显示，不额外裁剪；SDK 原始送帧、特征和验证参数保持原有行为。

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
