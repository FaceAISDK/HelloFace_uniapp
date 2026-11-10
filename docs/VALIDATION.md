# 验证记录

更新日期：2026-11-10。原生 SDK 0.8.8，上游提交 `572751458a3ea9d85ca422cecec56d115be71e4e`。

## 2026-11-10 三端一致性 0.1.4

原生录入与验证页面统一使用 `native-ui.json` 生成的 Kotlin / Swift / ArkTS 配置，包含文案、动作指导、警告阶段、颜色、字号、布局尺寸和禁用透明度。共用 UTS 层规范各接口的可空字段，验证只返回实际有限分数，不改写 SDK 判定。新增预览转换失败后的重拍处理与确认期间的重复结果保护；两套简单示例沿用原有调用方式。

- `npm run check` 通过：80 项检查（56 项 JS、24 项 Python），37 个 SDK 文件校验，三端 UTS 转换；新增检查覆盖六个 API 的字段范围、合法零分及非有限分数处理。`ui:check` 确认三端生成文件与共用配置一致。
- Android 官方 UTS + Kotlin / Dex 编译通过，分别检查 uni-app 和 uni-app x。包含新配置的本地原生 APK 构建通过。
- 小米 25098PN5AC / Android 17 上，独立原生宿主通过 20 项真实 SDK 集成检查，包含存储、忙碌、取消、重拍隔离、临时基准、真实无人脸超时及不持久化。测试包与临时宿主已清理，示例原有用户基准未修改；不代表真人比对准确率通过。
- 使用真实原生视图的独立界面预览，检查录入、动作验证、确认、预览缺失、保存五种状态；预览页面明确标注“无 SDK 调用”，确认/保存使用示意图片。自动操作验证预览缺失时确认不可用且可重拍、保存时三个操作按钮禁用。截图位于忽略目录 `unpackage/screenshots/consistency-*-xiaomi.png`，不作为识别成功凭据。
- 本地原生验收 APK 的 6 个 64 位库通过静态 16KB 对齐检查。小米为 4KB 页，不增加 16KB 运行验收结论。
- 鸿蒙使用真实 SDK 构建 HAR 成功；iOS 6 个 Swift 文件语法检查，以及生成配置 + UIKit 视图类型检查通过。尚无新增鸿蒙/iOS 真机验证；完整 iOS SDK 链接受本机 Xcode 15.2 限制。

当前 DCloud 账号仍无现有 AppID 的项目成员权限，完整 uni-app 示例需由有权限账号重制基座后运行，本轮未替换手机上原有完整示例。未修改 AppID 或 License。操作系统权限弹窗、字体渲染、安全区和设备镜头视角不属于插件可逐像素统一的范围。

## 2026-11-10 HiFaceUni 应用图标

使用用户指定图片制作顶部带红色小字 HiFaceUni 的母版，配置根 Vue 工程和独立 uvue 工程的 Android、iOS、HarmonyOS 应用图标。源文件与制作方式见 [图标说明](../app-icons/README.md)。

- 两套工程共 31 处平台图标引用通过已安装 HBuilderX 5.34 配置键、PNG 实际尺寸、透明通道和资源存在性校验。iOS 母版 1024×1024，全部 iOS 图标为无透明通道 PNG；鸿蒙前景保留透明边距，背景不透明。
- 图标只维护根目录一份，`demo:prepare` 复制到 uvue 示例；逐文件核对副本一致。资源生成脚本重复运行不改变图标内容。
- 77 项自动化检查通过（53 项 JS、24 项 Python）。新增的调试工具检查覆盖 Vue/uvue 图标内容变更导致宿主指纹变化，以及缺失图标时明确停止；Android 页面监听覆盖图标资源。

本次 HBuilderX 完整资源导出被 DCloud 拒绝，提示当前账号不是现有 AppID 的项目成员。未改动 AppID，未声称已替换手机图标或完成三端安装包验收；需要使用有权限账号重新打包或制作基座后生效。

## 2026-11-10 预览缩放 0.1.3

三端实时预览和确认照片改为等比居中显示，详见 [预览缩放](NATIVE_UI.md#预览缩放)。Android 使用 FIT_CENTER，iOS 使用 resizeAspect，鸿蒙按相机流旋转后的宽高比适配 XComponent 并使用 RESIZE_CONTAIN。未修改 SDK 输入帧、阈值、活体或特征存储流程。

- 76 项自动化检查、37 个 SDK 文件校验和三端 UTS 转换通过。
- Android 本地原生 APK 构建通过；在小米 25098PN5AC / Android 17 的独立原生宿主中打开真实 SDK 录入相机，预览正常显示，返回取消正常，未发现进程崩溃。没有确认保存或新增用户基准；未以此声称真人识别准确率或人脸大小测量通过。
- 鸿蒙真实 SDK HAR 构建通过，尚未新增真机验证；iOS 5 个 Swift 文件语法检查及 UIKit 相机视图类型检查通过，完整 SDK 链接限制继续适用。
- 本地原生验收 APK 的 6 个 64 位库通过静态 16KB 对齐检查；小米仍为 4KB 页。

本轮真机使用独立原生预览宿主。完整 uni-app/uni-app x 示例仍需重制含新原生代码的基座，单独刷新 Vue/uvue 页面不会更新预览缩放。

## 2026-11-10 接入接口 0.1.2

保留六个 API 与原有 faceID 调用方式，将三端默认值、校验和回调收尾集中到共享 UTS。新增可选 `referenceFeature` + `featureSpaceID`，仅使用调用方基准完成本次验证，不改写本机数据；错误增加 faceID；cancel 支持省略参数。完整说明见 [接入与 API](API.md)。

- 76 项自动化检查通过：36 项三端 API 契约、12 项示例交互、5 项鸿蒙操作协调器、23 项 Python 检查；另通过 37 个 SDK 文件校验与 Kotlin/Swift/ArkTS 转换。覆盖临时基准参数对、运行时校验、重复终态屏蔽、损坏响应、错误关联和取消收尾。
- Android Kotlin 编译、鸿蒙真实 SDK HAR 构建、5 个 iOS Swift 文件语法检查通过。鸿蒙协调器测试执行实际 ArkTS 调度代码，用可控权限/相机边界检查迟到授权隔离、保存保护和取消完成顺序，不模拟人脸识别成功。
- 小米 25098PN5AC / Android 17 上，本地独立原生宿主通过 20 项真实 SDK 检查，包含原有存储/取消/重新采集回归，以及无需本机录入的临时基准验证、真实 NO_FACE_TIMEOUT、无探测特征返回和不持久化。验收 APK 的 6 个 64 位库通过静态 16KB 对齐检查，设备仍为 4KB 页。临时验收宿主、测试 App 和测试基准已清理；未改动示例原有用户基准。
- 实际 UTS/Kotlin 编译发现并修正了错误类属性初始化、匿名函数默认参数及空对象默认值的桥接类型问题。新增 `android:uts-check`；uni-app 与 `--uni-app-x` 两种导出桥接均通过 HBuilderX 5.34 的本地 Kotlin/Dex 编译，而非仅转换源码。

云端制作完整 uni-app 基座时，DCloud 拒绝当前登录账号使用现有 AppID；未修改 AppID，也未把旧基座冒充新版。手机原有 uni-app 基座不含本轮接口改动，运行工程前应由拥有该 AppID 权限的账号重新制作。上述 20 项真机检查来自本地独立宿主，不代表新版完整 uni-app App 已联合运行。iOS 完整链接仍受本机 Xcode 版本限制，鸿蒙和 iOS 尚未增加真机验收；未增加真人比对准确率的结论。License 保持不变。

## 2026-11-10 简洁调用示例

Vue 与 uvue 示例改为四个功能按钮和文本结果框：相机录入、静默活体验证、动作活体验证、确认删除。页面直接调用插件 API，动作模式同时开启静默活体，识别阈值仍为 0.80。结果展示 SDK 的 `passed` 与 `outcome`，不保存或打印原始特征。

- `npm run check`：30 项 JS 测试、23 项 Python 测试、37 个 SDK 文件校验和三端 UTS 转换通过。示例测试覆盖两种验证参数、重复点击拦截、删除确认及弹窗失败收尾、错误码展示、离页取消和浏览器提示。
- uvue：HBuilderX 5.34 的 SFC 脚本编译、Kotlin/Swift 模板生成和 Android/iOS/HarmonyOS CSS 检查通过；不代表完整原生 App 链接或三端真机验收。
- 小米 25098PN5AC / Android 17：Vue3 页面资源编译、同步和启动通过，新布局正常显示；点击验证进入真实原生识别页，无脸时返回 `passed: false / NO_FACE_TIMEOUT` 并显示在结果框。删除弹窗取消后恢复按钮可用。

本轮未修改插件 API、原生相机或 License，未增加真人比对及活体准确率的验收结论。

## 2026-11-10 Android 调试通道

新增 [Android 调试与实现](ANDROID_DEBUG.md) 中的基座构建、源码指纹、App 内页面同步、监听和操作日志。包含这些能力的新基座由 `android:base` 构建并校验成功，APK SHA-256 为 `27a45214709c7cfc5b83386b4b0156ff8e06f6612f2ccd85c784c6800f2ab8e4`。

在小米 25098PN5AC / Android 17 / API 37 上完成：

- 默认 `android:run` 同步 18 个资源文件并启动，连续运行自动跳过相同 APK 的安装。
- `android:dev` 依次完成首次同步、Vue 页面修改同步、恢复源码同步；没有因 HBuilderX 写入元数据而产生重复构建。示例源码已逐字节恢复。
- 修改原生源码或宿主 Android 配置时，只读检查拒绝旧基座；恢复原文件后重新通过。
- 录入相机运行中请求同步返回忙碌，原生相机继续保持前台；返回取消后，日志包含操作、结果码和耗时，不含 faceID 或 HF1 特征。
- 构造 shell 创建的旧 AppID 缓存后，脚本迁移已知页面缓存，新资源目录由 App UID 创建。未知业务目录会停止自动迁移。
- 独立原生宿主拒绝越界 ZIP 与缺少必需文件的资源包，现有页面清单哈希保持不变；同源码的 release 宿主拒绝 INFO/SYNC，资源不变。
- 新基座内通过 17 项真实 SDK 集成检查，验证无脸超时、加密特征往返、取消及重新采集等行为；临时基准已删除。

发现 MIUI Greezer 会拦截发给缓存后台进程的显式广播；脚本在必要时将示例置于前台再同步，同时优先检查活跃人脸操作。调试 receiver 受 `DUMP` 权限和宿主 `FLAG_DEBUGGABLE` 双重限制，不增加插件对外 API。

本轮自动化检查为 51 项：28 项 JS 测试、3 项安装器测试、8 项对齐检查测试和 12 项调试工具测试；另通过 37 个 SDK 文件校验和三端 UTS 转换。原生 Kotlin 与 HBuilderX 本地原生源码编译通过。uvue 生成的插件副本与规范源码指纹一致；uvue 仍走 HBuilderX 原生通道，本轮页面监听验证针对 Vue3。

设备仍为 4KB 页，未增加真实 16KB 环境或真人识别准确率的验收结论。License 与 Vue/uvue 示例业务调用代码保持不变。

## 2026-11-10 原生界面与 16KB 检查

三端原生相机界面已统一，详见 [界面说明](NATIVE_UI.md)。本轮 `npm run check` 通过 39 项检查（28 项 JS 测试、3 项 SDK 安装器测试、8 项对齐检查测试）、37 个 SDK 文件校验及三端 UTS 转换。对齐测试包含 4KB LOAD、错误地址偏移、RELRO 共页、压缩库、正确与错误的未压缩 ZIP 偏移，以及无有效 64 位库等情况。

| 检查 | 结果与范围 |
| --- | --- |
| Android 构建 | 新界面通过 Kotlin 原生构建及 HBuilderX 5.34 完整云打包；另通过本地 UTS 原生源码编译。系统栏与安全区改用 API 23 起可用的平台接口，避免本地检查器解析较旧 AndroidX Core 声明时编译失败 |
| 鸿蒙构建 | 更新后的原生 ArkTS、重新采集及回调隔离逻辑通过真实 0.8.8 HAR 的 `assembleHar`；未签名，尚未真机验收 |
| iOS 检查 | 5 个 Swift 文件语法检查通过；新增 UIKit 相机界面在 iOS 17.2 SDK 下类型检查通过。完整 SDK 链接仍受本机 Xcode 15.2 限制，尚未真机验收 |
| SDK 16KB | `hiface-0.8.8.aar` 的 2 个 ARM64 动态库通过 ELF LOAD、地址偏移与 RELRO 检查 |
| 整包 16KB | 自定义基座及完整页面安装包的 18 个 ARM64 动态库全部通过 ELF LOAD、地址偏移与 RELRO 检查；未压缩动态库的 ZIP 数据偏移检查通过，另由 SDK Build-Tools 36 的 `zipalign -c -P 16 4` 复核通过 |
| 问题修复 | 旧基座的 `lib39285EFA.so` 存在 RELRO 与可写数据共用 16KB 页的问题。按 DCloud 官方配置关闭不需要的默认 OAID SDK，重建后不再包含该库与 `libsecsdk.so`；相机、特征保存和比对不依赖 OAID |
| 安装包完整性 | 签名通过 API 23 校验；6 个 `.bphfm` 模型均未压缩。完整安装包 31,584,132 字节，SHA-256 为 `944ac1f92f78462383200160b4161cf9ef50bfca6288ca3c92ef4a6bd40b5418` |
| 小米运行 | 25098PN5AC / Android 17 / API 37，安装完整页面 APK 后首页与原生录入预览正常显示，已检查取景区、提示及返回取消。录入确认界面另外使用明确标注“无 SDK 调用”的头像预览宿主检查布局，未伪造真人录入 |
| 原生集成回归 | 小米上包含新界面的自定义基座通过 17 项检查：加密保存/读取、覆盖保护、真实 SDK `NO_FACE_TIMEOUT`、忙碌拦截、取消、相机窗口常亮、重新采集后的旧回调隔离、确认前基准不变及删除；临时基准已清理。新增确认状态由测试注入，不代表真人采集成功 |

小米实测 `getconf PAGE_SIZE` 为 `4096`。上述 16KB 结果是 SDK 和最终 APK 的静态对齐验证；本轮尚未在 `PAGE_SIZE=16384` 的环境完成运行验收，也不代表本人比对或活体效果已通过。

Android 17 上复现了手工 ADB 同步首次创建 shell 所有的资源目录后，App 无权读取页面的问题。完整 APK 使用自身提取的资源目录已正常显示；运行脚本现在会在 Android 11+ 检查目录归属，拒绝创建这种目录，并提示改用 HBuilderX 标准同步或完整 APK。Android 6 的既有同步路径保留。

插件 0.1.1 的发布 ID 为 `HelloFace-Verify`，展示名称为 `HelloFaceVerify`。本次 ID 迁移后重新通过 31 项自动化检查、37 个 SDK 文件校验和三端 UTS 转换，并核对了目录、示例导入、5 个关键词和版本一致性。原生源码与存储键未因本次 ID 迁移改变；此前的 Android Kotlin 编译、鸿蒙 HAR 构建与 iOS Swift 语法检查记录见下表。以下 iOS 完整编译与真机验收限制继续适用。

## 已通过

| 检查 | 结果与范围 |
| --- | --- |
| 插件 ID | `HelloFace-Verify` 符合“作者 ID-插件名”结构，目录与导入一致。HBuilderX 5.34 官方解析器确认新旧 ID 映射为相同 Kotlin/Swift 命名空间；插件市场的 ID 占用与发布结果仍需服务端确认 |
| `npm test` | 18 项 API 契约测试、10 项示例交互测试和 3 项 SDK 安装器测试通过 |
| 示例页面 | Vue 示例通过 HBuilderX 5.34 的 H5 构建；uvue 脚本与 Kotlin/Swift 模板编译、三端 CSS 检查通过。浏览器预览只检查布局与交互，不代表真机识别验收 |
| SDK 文件校验 | 37 个文件均通过锁定的 SHA-256 和长度校验 |
| 官方 UTS 转换 | HBuilderX 5.34 的 UTS 编译器成功生成 Kotlin、Swift、ArkTS；不是最终 App 链接验证 |
| Android 完整自定义基座 | HBuilderX 5.34 云端构建成功，APK 约 30.8 MB；相机 Activity、ARM64/ARMv7 动态库和 6 个未压缩模型均已确认，签名通过 API 23 校验，并已安装到华为 GRA-UL00 / Android 6.0 |
| Android 运行入口 | `npm run android:check` 在已授权的 Android 6.0 / API 23、ARM64 设备上通过；检查真实 AppID、包名、基座版本、SDK 与模型打包，错误 AppID、不完整基座和压缩模型均被拦截 |
| Android Vue3 真机运行 | HBuilderX 5.34 导出当前页面资源成功，`android:run -- --skip-install --sync-resources` 完成同步并启动（`Status: ok`）。已安装包含修复的完整基座，首页与录入页正常，未录入时验证返回 `NOT_FOUND`，取消正确回调并返回示例。真人确认录入、本人/他人比对和活体效果尚未验收 |
| Android 原生 SDK 集成 | 华为 GRA-UL00 / Android 6.0 上，修复后的独立原生宿主及完整 uni-app 自定义基座均通过 12 项真实调用检查；SDK 返回 `NO_FACE_TIMEOUT`，未再出现相机绑定的 `AbstractMethodError`。最终 APK 的 DEX 确认包含新的超时校验及分析器四个显式接口方法，签名、模型和原生库校验通过 |
| Android 原生编译 | 将插件原生 Kotlin 源码直接加入临时 Android Library，`compileDebugKotlin` 成功；AGP 8.13.1、Kotlin 1.9.22、JDK 17、compileSdk 36、CameraX 1.5.2、真实 0.8.8 AAR |
| 鸿蒙原生构建 | 将原生 ArkTS 源码加入临时 HAR 模块，DevEco Studio 26 / Hvigor 的 `assembleHar` 成功，使用真实 0.8.8 HAR，未签名 |
| iOS Swift 语法 | `swiftc -frontend -parse` 检查所有原生 Swift 文件通过；不代表类型检查或链接通过 |

实时送帧的错误分类按上游 0.8.8 [采集 Demo](https://github.com/FaceSDKPro/HelloFace/blob/572751458a3ea9d85ca422cecec56d115be71e4e/platforms/Android/demo/src/main/java/com/hiface/sdk/demo/search/uvc/UVCCameraFaceEnrollmentActivity.java#L218) 修正：`NOT_READY` 与临时 `BUSY` 只跳过当前帧，其他 SDK 错误仍保留原始错误码并结束操作。Android、iOS、HarmonyOS 均采用此策略；接口重复调用的 `BUSY` 行为不变。修改后的 Kotlin 原生编译、鸿蒙 HAR 构建和 Swift 语法检查已通过。

进一步进行 Android 原生验证时复现了两处接入错误：`actionTimeoutMs: 1000` 虽通过插件校验，却被 SDK 要求的 2000–30000 毫秒范围拒绝；Android 6 上 CameraX 分析器在绑定相机时出现 `getDefaultTargetResolution()` 的 `AbstractMethodError`。已分别修正共享参数校验与文档，并显式实现分析器的默认接口方法。

修改后的真实 Kotlin 源码与 SDK 0.8.8，在独立 Android 调试宿主和重新云打包的完整 uni-app 基座中均通过 12 项真机集成检查，包括 Android Keystore 加解密、特征往返与覆盖保护、真实 SDK 返回 `NO_FACE_TIMEOUT`、接口 `BUSY`、取消后继续调用和删除。复查入口为 [Android 原生集成检查](../tests/android/README.md)。这组检查使用上游公开测试特征，随机测试基准及崩溃期间遗留的测试基准均已清理；不代表真人识别或活体效果验收。

API 测试执行实际 UTS 入口及共享校验/回调代码，使用轻量的 JS 环境适配 UTSJSONObject。原生调用在测试中被捕获，**不会伪造识别成功作为算法测试**。覆盖默认参数、非法输入拦截、特征空间不匹配、未通过活体时保留业务拒绝、空分数、取消错误、原始 SDK 错误和 complete 回调行为。

安装器测试覆盖：同长度文件篡改、LFS 指针误用、只校验模式不创建文件、安装失败保留已有文件和清理临时文件。

示例交互测试执行 Vue/uvue 页面的实际脚本，用替身捕获插件调用，检查活体参数、重复点击拦截、删除确认、失败收尾、离页取消，以及高相似度但 `passed: false` 时仍显示未通过。页面不保存或展示原始人脸特征；浏览器预览只提示真机运行。

## 本机环境限制

本机 Xcode 为 15.2，无法完整编译 Swift 6.1.2 构建的上游 iOS SDK。需使用兼容新版 Xcode，或在满足 SDK 工具链要求的云打包环境中完成 iOS 编译和链接。

本机已安装 Android 原生运行扩展并生成 Android 自定义基座。HBuilderX 5.34 的“已安装基座”CLI 在本次环境停在启动阶段，使用 `appResource` 导出和 ADB 同步页面后，完成上述 Vue3 页面与录入相机检查。Vue2、uvue 的完整基座联合运行仍待验收。

本次仅连接并操作 Android 真机；相机首次授权和录入预览已检查，尚不能据此声称真人识别效果、加密存储持久化和跨设备特征互通已通过验收。iOS、HarmonyOS 的真机流程仍待验证。

## 复查命令

```sh
npm ci --ignore-scripts
npm test
python3 scripts/install_sdk.py --check
node scripts/check_uts.cjs
```

可通过 `HBUILDERX_PATH` 指定 HBuilderX 的 `Contents/HBuilderX` 目录。原生源码位于插件的 `utssdk/app-android`、`app-ios`、`app-harmony`；独立原生构建直接引用这些文件和安装器获取的真实 SDK，未引入算法替代实现。

工程也提供 `npm run check` 顺序执行自动化测试、SDK 文件校验和 UTS 转换。它不生成正式安装包；本地与云端构建路径见 [三端打包指南](BUILDING.md)，接口定义见 [API 参考](API.md)。

## 待真机验收

在 Android、iOS、HarmonyOS 上，分别使用 Vue2、Vue3、uvue 宿主完成以下用例，并记录 OS、HBuilderX、原生 SDK 版本与设备型号：

1. 首次拒绝相机权限、再次授权、永久拒绝后的失败返回。
2. 首次录入、确认前取消、确认后重启 App 仍可验证；覆盖录入需 `overwrite: true`。
3. 未录入的 faceID、本人、他人、照片/屏幕攻击、多脸、无人脸和动作超时。
4. 默认静默活体、启用眨眼/点头、关闭可选活体时的 1:1 流程。
5. 快速重复调用返回 BUSY，取消后立即启动新任务，旧结果不进入新任务；相机任务进入后台后释放。
6. 退出录入确认界面不会保存；确认保存过程中不会报告“取消但已写入”。
7. 读取并同步同一特征空间的 HF1，拒绝旧插件特征；删除已有/不存在/损坏的本地基准。
8. 调整前后置相机；横竖屏、锁屏和来电后的恢复；SDK 原始授权错误原样传递。
