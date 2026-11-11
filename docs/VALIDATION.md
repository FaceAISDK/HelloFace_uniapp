# 验证记录

更新日期：2026-11-11。原生 SDK 0.8.8，上游提交 `572751458a3ea9d85ca422cecec56d115be71e4e`。

## 2026-11-11 iOS 功能对齐（未做真机验证）

- 核对八个公开 API、临时基准、图片/特征同步、返回码、确认/重拍、互斥/取消、Keychain、满亮与恢复：iOS 已有对应实现，本次保留参数、SDK 0.8.8、阈值、License、存储键及格式。三端固定 333×333 确认预览未改成高清流程。
- 补齐与鸿蒙对应的录入稳定圆环：Core Animation 在 HOLD_STILL 阶段显示 0.7 秒进度；重复阶段不重启，偏头/晃动/丢脸、确认、重拍及离页会重置。满圈只更新显示，仍由 SDK 返回真实采集结果。
- 统一显式配置竖屏方向和前置预览镜像，输出给 SDK 的帧保持无镜像、携带原有镜像标记。优先 VGA 640×480，不支持时尝试系统 medium 预设；没有支持的配置时返回相机错误。
- 补齐相机会话中断和运行错误通知；后台中断返回取消，其他中断返回相机错误。配置、帧处理、暂停、关闭在同一串行队列；关闭时解除观察者、帧代理、输入和输出，关闭后的排队任务不能再启动或分析帧。
- 修复权限拒绝/快速取消可能先于弹出动画完成的收尾窗口：同时等弹出完成和管线关闭，再关闭页面并交还调用槽，避免空白相机页残留或过早重入。SDK 改为授权后创建，拒绝授权或提前取消时不为收尾额外初始化 SDK。补上 Swift 6 所需的通知主 actor 路由与 UTS 回调传递包装，公开回调签名保持不变。
- 新增 `npm run ios:check`。8 个真实 Swift 文件语法检查通过；20 项直接编译执行的相机状态检查通过；真实 UIKit 视图/圆环类型检查通过。全部 UIKit/AVFoundation/Keychain 接入类型通过编译用 HiFace 边界检查；该边界全部为 `fatalError`，仅在临时检查模块使用，不打入插件或 App，不能作为真实 SDK、识别或活体结果。
- 通用 `npm run check` 通过 106 项（81 项 JS、25 项 Python）、37 个 SDK 文件校验及三端 UTS 转换。规范 iOS 源码和 uvue 插件副本同步；Demo 接入代码无需修改。

**仍未验收**：用户明确暂不做 iOS 真机验证；相机画面、方向/镜像观感、圆环、权限弹窗、系统中断、亮度恢复、真人录入、本人/他人比对及活体均待真机。真实 SDK 的 `ios:check -- --full` 仍被本机 Xcode 15.2 阻塞（不支持 `-swift-version 6`）；没有新增完整 IPA 构建或链接通过结论。旧 iOS 17.2 SDK 的 `UIAccessibilityTraits.updatesFrequently` 在严格并发诊断下仍有一条共享全局状态警告，使用点位于主 actor 的 UIKit 视图；需在兼容 Xcode 上复核完整检查。

功能差异、构建、断点和待验收清单见 [iOS 功能与调试](IOS_DEBUG.md)。日志为忽略目录 `unpackage/validation/ios-parity-*.log`；纯状态检查不模拟人脸识别成功。

## 2026-11-11 三端原生相机亮度管理

- 录入（含确认与重拍）、静默验证和动作验证共用原生相机页，进入时自动调到最亮，完成、取消、异常、离页和进入后台时恢复。Android 保存本 Activity 的 `screenBrightness`，iOS 保存所在 `UIWindowScene.screen` 的亮度，鸿蒙保存主窗口 `brightness`；Android/鸿蒙保留 `-1` 跟随系统策略。存储、同步等没有相机页面的接口不调亮，Demo 无新增调用。
- 鸿蒙将设置和恢复串行化，覆盖快速取消发生在异步调亮之前或期间的情况；后台即使处于保存提交阶段也恢复亮度。新增 4 项真实流程方法的回归测试，覆盖默认/自定义/已满亮原值、恢复幂等、快速取消及后台提交场景。`npm run check` 共 106 项通过（81 项 JS、25 项 Python），37 个 SDK 文件校验和三端 UTS 转换通过；uvue 插件副本已同步。
- Android 的 uni-app、uni-app x 官方 UTS/Kotlin/DEX 编译及桥接 ABI 检查均通过。Samsung SM-S9210 / API 36 使用设备上已有完整 0.1.5 基座，经 HBuilderX 原生联编后，真实录入窗口的系统属性为 `sbrt=1.0`；取消后恢复宿主窗口默认策略，重复进入再次为 1.0；进入后台及回到宿主后均无满亮覆盖。未卸载应用或改动基准。
- 鸿蒙完整签名 HAP 于 17:49:24 构建成功，17:49:26 安装成功；产物 22,169,788 字节，SHA-256 `5c53c8ac13fc9ca316ba6a8d62ea118c2b7ccacb9d0925e553b0fc79133b7445`。Mate 60 Pro / API 26 依次打开录入、静默验证、动作验证，并分别取消或切后台；原生窗口日志实测亮度顺序为 `1 → -1 → 1 → -1 → 1 → -1`，各次返回 `result: 0`，当前进程无 Fatal 条目。本轮是亮度及退出回归，不新增真人身份/活体判定结论。
- iOS 已同步功能，7 个 Swift 文件语法检查及真实亮度方法的 UIKit 类型检查通过。按用户指示，没有真机时先保留待验收；未将局部类型检查记为完整 SDK 链接、IPA 构建或 iOS 真机通过。现有 Xcode 15.2 对当前 SDK 的完整链接限制仍在。

证据位于忽略目录 `unpackage/validation/brightness-*.log`、`brightness-android-device-20261111.json`、`brightness-receipt-20261111.json`。原有用户数据、SDK、License、识别阈值和公共 API 均保留。

## 2026-11-11 鸿蒙录入圆环与真人回归

- 核对当前 SDK 的引导录入稳定窗口为 700 毫秒，原生鸿蒙 Demo 也用同一时长绘制稳定提示。单人、面部大小、正脸和稳定性须先满足 SDK 条件，检测及特征提取仍需时间，不能把它描述为打开相机后固定 1 秒完成。
- 插件鸿蒙相机页新增 `HOLD_STILL` 阶段的蓝色圆环进度，使用单调时钟、33 毫秒重绘；相同阶段不重复起表，偏头、晃动、丢脸等阶段重置。确认、重拍和离页会清理计时器；满圈仅为视觉提示，仍由 SDK 结果触发确认页。Demo 无新增封装或调用参数，识别和活体参数、存储均不改变。
- 新增真实圆环控制方法的回归检查，覆盖 700 毫秒进度、重复事件、姿态/丢脸重置、验证模式隔离及离页清理。`npm run check` 通过 102 项（77 项 JS、25 项 Python）、37 个 SDK 文件校验及三端 UTS 转换，uvue 插件副本已同步。
- HBuilderX 5.34 / DevEco 26 于 17:37:15 制作完整运行包成功，17:37:17 安装成功。当前签名 HAP 为 22,170,828 字节，SHA-256 `91fce04e3fe0c1a0592f3aade50bd0332969f33de805ec1274e80c7cce5371eb`。在同一 Mate 60 Pro / API 26 打开真实录入相机，操作者反馈“动画清楚，正常进入确认页”。没有保存真人相机或确认照片。
- 使用此前录入的 `demo-user` 在更新后打开静默活体身份验证，设备页面实际返回 `code: 0 / msg: 验证通过 / passed: true / similarity: 0.929 / livenessScore: 1.000`；操作者也确认本人验证通过。这同时确认更新后原有基准仍可读取，且圆环结束/离开后能继续调用验证。
- 动作活体先有一轮未检测到人脸，返回 203 / `passed: false`；后续由操作者完成动作，页面实际返回 `code: 0 / msg: 验证通过 / passed: true / similarity: 0.918 / livenessScore: 1.000`，操作者确认动作验证通过。示例调用配置为 `blink / nodHead`，保留默认静默活体。失败轮次未算作通过，最终成功页面证据为 `harmony-ui-human-action-verification-confirmed.json`。

本轮真人回归已完成：确认照片颜色正常、录入保存、圆环及确认页、本人静默验证、本人动作验证均通过。尚未测试他人比对；这些结果不代表识别准确率或活体攻击防护评测。未新增 HarmonyOS 6 实机或独立 uvue 完整 App 验收。构建日志、UI 文本证据及不含照片/特征的构建收据在忽略目录 `unpackage/validation/harmony-capture-ring-*`、`harmony-ui-human-*`。

## 2026-11-11 匹配签名与完整 Vue3 示例真机验证

- 在 AGC 注册 `HelloFaceVerify Demo`，Bundle Name 为 `dev.helloface.uniapp.demo`；新调试 Profile `HelloFaceVerifyUniappDebug20261111` 匹配该应用及当前已注册设备，沿用现有开发证书和私钥。DCloud AppID、SDK、License 均未改变。私有签名配置仅保存在被忽略的 `harmony-configs/build-profile.json5`；证书和 Profile 不进入仓库。
- HBuilderX 5.34 / DevEco 26.0.0.851 于 17:14:30 报告完整运行包制作成功，17:14:33 安装成功。真实设备为 Mate 60 Pro / ALN-AL80，API 26，系统 `OpenHarmony-7.0.0.111`；安装版本 0.1.5 / 105。已签名 HAP 为 22,165,838 字节，SHA-256 `007612bc55bbf2c19a164d8edb52698e8879a420072b3b10475f8b36058d0f88`。日志为忽略目录下 `unpackage/validation/harmony-signed-run-20261111.log`。
- 实际操作返回：缺少基准 105；相机拒绝 102；授权后原生预览入口及取消 103；外部 AI 示例图片与特征同步各为 0。App 强制停止再启动后，直接验证 `external-demo` 能进入原生相机，证明该测试基准持久化；无人脸超时为 203 / `passed: false`。
- 动作验证打开后切到后台再恢复，返回取消 103，页面可继续操作；连续双击验证仅出现一个原生相机对话框，取消后恢复。该双击验证的是 Demo 的防重入，不代表已在真机覆盖原生并发 BUSY 104。
- 删除外部测试基准时取消确认，后续仍可打开验证；确认删除后返回 0，再验证返回 105。只删除本轮创建的 `external-demo` 测试基准。当前 App 进程未发现 Fatal 日志；未据此推断所有进程或长期运行无崩溃。
- 真人操作者已进入录入确认页，并报告照片偏蓝。定位为 SDK `alignedRgba` 是 RGBA，而 `image.createPixelMap` 默认按 BGRA 读取源缓冲区。补充 `srcPixelFormat: RGBA_8888`，仅修复确认照片显示；不改变相机 YUV 转换、特征、活体、阈值或存储。新增真实确认方法的合成红/绿/蓝/白像素回归检查，不保存真人照片。
- 修复后 `npm run check` 通过 99 项（74 项 JS、25 项 Python）、37 个 SDK 文件校验和三端 UTS 转换。17:28:39 完整运行包制作成功，17:28:41 安装成功；新签名 HAP 为 22,165,764 字节，SHA-256 `d1f497da668ba4343b427de3d994f5881e2e8e9ae7a85979d3a2c426a0c9d7c6`，已核对生成工程包含输入格式修复。重新打开录入相机，当前进程 Fatal 日志为零。日志为 `unpackage/validation/harmony-preview-rgba-{check,run}-20261111.log`，构建收据为同目录 `harmony-preview-rgba-receipt-20261111.json`。

操作者随后明确反馈“颜色正常，已确认录入”，据此记录颜色修复和真人确认保存通过；后续本人验证见最新一节。当前真机结果仅对应根 Vue3 示例和上述 API 26 设备；无 HarmonyOS 6 实机结果，独立 uvue 完整 App 仍未验收。历史签名阻塞已解除；下面保留当时记录供排错。

## 2026-11-11 鸿蒙完整 HAP：最低 API 与 ArkTS 空值修复

- 用户的完整宿主构建暴露 `00306004`：默认 `compatibleSdkVersion` 为 API 13，而真实 hiface HAR 要求 API 20。根 Vue 与独立 uvue 的 `manifest.json` 均持久设置 `app-harmony.distribute.compatibleSdkVersion: "6.0.0(20)"`。HBuilderX 重新生成工程后，default/release 两个 product 都为 20；未降低 SDK 的兼容版本声明。
- 原 `MergeProfile` 错误消除后，完整 ArkTS 编译发现共享分发器的可选链值可能为 undefined，与公开接口的 `string | null` / `boolean | null` 不匹配。`action / feature / passed / outcome` 缺失值显式归一为 null，保持接口约定和 SDK 判定；新增三端缺失动作/录入特征的回归检查。
- 先前重试中出现并发 Hvigor 占用和旧插件 ID 缓存；停止重试后，以 `--cleanCache true` 单次运行重新生成工程，旧 `@uni_modules/hellofaceverify` 依赖已移除。当前仅保留规范的 `@uni_modules/helloface-verify`。
- HBuilderX 5.34 / DevEco 26 在 16:45:38 报告“运行包制作成功”，完整 Vue3 示例的未签名 HAP 为 `unpackage/dist/dev/app-harmony/entry/build/default/outputs/default/entry-default-unsigned.hap`，21,927,576 字节，SHA-256 `6c01315bcfee1910b7423019b52323e56590068cd829054f691eb63a455b8ea8`。包内包含真实 `libs/arm64-v8a/libhiface.so`；鸿蒙 SDK 采用该原生库，不能用 Android 的库名或外置模型清单判断是否打入 SDK。
- 修改后 `npm run check` 通过 98 项检查（73 项 JS、25 项 Python）、37 个 SDK 文件校验及三端 UTS 转换。日志位于忽略目录 `unpackage/validation/harmony-api20-*.log`。
- uni-app 与 uni-app x 的官方 UTS/Kotlin/DEX 编译和桥接 ABI 复验均通过；HAP 内的 `libhiface.so` 与锁定 HAR 中的原生库逐字节一致。

安装阶段明确返回“没有签名无法安装”，尚未新增完整鸿蒙示例的相机或真人识别验收。仍需为 `dev.helloface.uniapp.demo` 配置匹配设备的调试签名。API 20 对应 HarmonyOS 6.0.0，作为最低版本时不支持鸿蒙 5；HarmonyOS NEXT 从 5 开始属于原生鸿蒙体系，这与当前 SDK 的最低支持版本是两个概念。

## 2026-11-11 定时鸿蒙验证（代码整理前）

- HDC 检测到 Mate 60 Pro / ALN-AL80，系统 API 26；HBuilderX 5.34 的 `devices list --platform app-harmony` 也识别到同一设备。`sdk:check` 单端校验真实 0.8.8 HAR 的哈希与长度通过。
- `bm dump -n dev.helloface.uniapp.demo` 未查询到已安装应用。本机已有两个调试 Profile 的包名为 `com.hiface.sdk.public`、`com.hiface.sdk.debug`，均不匹配本示例；未改包名、借用其他应用 Profile 或卸载任何应用。缺少匹配 Bundle Name 和当前设备的签名配置，是完整真机运行的阻塞。
- 尝试 HBuilderX 的鸿蒙 CLI 运行、仅编译和本地打包；运行/仅编译停在版本信息，本地打包在 16:03:32 报告“项目 HelloFace_uniapp 编译成功”，但未产生本轮可安装的签名 HAP。已结束这些尝试。生成目录仍有 11 月 9 日的旧 0.1.1 工程，前端编译成功不能当成本轮 0.1.5 完整原生构建成功的证据。
- 界面控制服务两次启动失败，无法继续检查 HBuilderX/DevEco 的签名窗口。未进入当前完整示例的权限、相机、录入或验证流程，未新增真人识别/活体验收结论。

本次状态记录位于忽略目录 `unpackage/validation/harmony-scheduled-20261111.json`；具体签名准备、断点、日志和重建步骤见 [鸿蒙调试说明](HARMONY_DEBUG.md)。第一阶段在记录以上阻塞后结束，再开始插件代码整理；整理后的检查另行记录。

## 2026-11-11 插件整理与简洁 Demo（第二阶段）

- 三端 `index.uts` 统一使用 `shared.uts` 的 `invokeFaceMethod`，集中创建分发器、参数校验及序列化。各端只保留获取上下文和原生调用的适配器；八个公共 API 的参数、回调与返回语义保持兼容。
- Vue/uvue 按钮继续直接调用插件 API，复用页面结果/错误/complete 收尾方法，省略默认阈值与静默活体参数。保留重复点击拦截、删除确认和离页取消；动作活体仍保留默认静默活体，页面不保存或显示原始特征。
- 补充三端原生操作槽、迟到回调、取消确认、保存提交、帧释放及加密格式的必要中文注释。新增 [代码结构与维护](CODE_STRUCTURE.md)，精简 README 接入示例并补全八个 API 清单。SDK 0.8.8、License、阈值及存储键未改动。
- 整理后 `npm run check` 通过 95 项检查（70 项 JS、25 项 Python）、37 个 SDK 文件校验和 Kotlin/Swift/ArkTS 转换。测试仍检查未通过判定、非法参数、重复终态、取消及同步覆盖保护。
- 整理后的 uni-app 与 uni-app x 官方 UTS/Kotlin/DEX 编译均通过，并再次通过桥接 JVM 名称 ABI 检查；Android 6.0 的最低版本提示保留。平台适配器使用函数值传入共享调用链，避免把 Kotlin 普通函数声明直接当作函数值。
- 真实 0.8.8 SDK 的原生 ArkTS `assembleHar` 构建通过；这是不可单独安装的 HAR，不代表完整 HAP 或真机验收。
- HBuilderX 5.34 的 Vue3 示例资源导出成功；uvue SFC 脚本编译与 Kotlin/Swift 模板生成通过，不代表 uvue 整页原生编译或完整 App 链接。uvue 插件副本的 41 个源码/配置/说明文件逐一与规范目录核对一致。

本轮检查日志位于忽略目录 `unpackage/validation/cleanup-*.log`。鸿蒙完整示例及整理后真机相机回归仍受第一阶段签名问题阻塞；iOS 完整链接仍受现有 Xcode 版本限制。未把整理前结果当成整理后真人识别或活体验收。

## 2026-11-11 外部图片与特征同步

- Android / iOS / HarmonyOS 新增 `syncFaceImage`、`syncFaceFeature`，三端共享参数校验、默认值与结果归一化；保留 `setFaceFeature`。图片使用公开 `extractFeature` 入口，仅提取基准，不依赖较新的多人图片采集或对齐预览接口。
- AI 虚构人脸裁近并输出为 200×200 PNG，TinyPNG 压缩由 59846 字节降至 26255 字节（约 56%）。首版同尺寸图片在真实 SDK 返回 IMAGE_FACE_TOO_SMALL，裁近后重新压缩才通过；未放宽 SDK 人脸尺寸门槛、活体或比对参数。
- 小米 722875bd / Android 17 在独立原生宿主通过 12 项真实图片导入检查：200×200 最终 PNG 提取、HF1 与无身份判定、读取、覆盖保护、无效图片/无脸/人脸过小、失败保留原基准，以及外部特征同步往返一致。该次真实提取值用于 Demo 外部特征，JSON 记录图片哈希和 SDK 版本；准备脚本拒绝不匹配数据。
- `npm run check` 通过 95 项自动化检查（70 项 JS、25 项 Python），37 个 SDK 文件校验与三端 UTS 转换；官方 uni-app 和 uni-app x UTS/Kotlin/DEX 编译及桥接 ABI 检查通过。两个示例均直接调用同步接口，不要求本机先录入；示例使用独立 `external-demo`。HBuilderX 5.34 的 Vue3 与 Vue2 完整示例资源导出均编译成功，工程配置恢复为 Vue3。
- 鸿蒙使用真实 SDK 的 HAR 原生编译通过；iOS 7 个 Swift 文件语法检查通过，完整 SDK 链接仍受本机 Xcode 15.2 限制。未新增 iOS / 鸿蒙真机同步验收，Android 结果不代表三端真机全部验收，也不表示活体或身份验证通过。
- Android 显式声明 ExifInterface 1.3.2 以处理照片方向；版本与 CameraX 现有运行时依赖一致，无新增原生库或最低版本变化。新增 API/源码需要 HBuilderX 原生联编，单独刷新 Vue 页面不会更新接口；依赖不同的旧基座需重建。

## 2026-11-11 返回码与短提示

三端共用 `utssdk/status.uts`，统一新增 `code / msg`：0 为方法成功，1xx 操作问题、2xx 识别未通过、3xx 运行异常。`errCode`、`sdkCode`、原始 `outcome` 保留；fail 的 `errMsg` 使用短提示，原始说明放在 `detail`。Vue/uvue 示例改为直接展示 code/msg，不展开底层长文案。

- 87 项检查通过（62 项 JS、25 项 Python），37 个 SDK 文件校验、三端 UTS 转换通过；uni-app 和 uni-app x 的真实 UTS/Kotlin 编译及桥接 ABI 检查通过。
- 三端 API 合同检查覆盖全部已定义业务结果、操作错误、运行错误、SDK 授权错误及未知码回退；确认高分不能改写 false 判定，未知/不一致的失败结果返回 299，原有回调次数与 legacy errCode 保持兼容。
- 新增共享 UTS 文件的指纹检查，确认 status.uts 的新增和修改都会使源码指纹变化。两套示例继续使用同一插件副本。

此轮不更换 SDK、原生依赖或清单；新增返回字段需要通过 HBuilderX 本地联编插件，单独刷新 Vue 页面不能更新原生 UTS 代码。未新增 iOS/HarmonyOS 真机验收，iOS 完整链接限制继续适用。License 未修改。

## 2026-11-11 Android 系统栏弃用警告

原生相机 Activity 改用已有 AndroidX Activity 1.9.3 的 `enableEdgeToEdge` / `SystemBarStyle`，移除 `systemUiVisibility`、`SYSTEM_UI_FLAG_*`、`statusBarColor` 和 `navigationBarColor` 的直接调用。Android 11 及以上使用系统 `WindowInsets.getInsets` 合并系统栏与挖孔安全区；Android 6–10 只在独立兼容函数中读取旧安全区字段，保持原有布局。

- 真实 HBuilderX uni-app 与 uni-app x UTS/Kotlin 编译和桥接 ABI 检查通过，日志中不再出现本次系统栏弃用警告；uni-app 的旧 AndroidX Core 类型索引差异通过使用系统 `WindowInsets` 解决。两种编译检查使用独立缓存目录，避免混用不同运行时的编译产物。
- 80 项自动化检查、37 个 SDK 文件校验和三端 UTS 转换通过；没有新增依赖或提高最低系统版本。
- `需在 Android 6.0 版本及以上方可正常使用` 仍是 `minSdkVersion: 23` 对应的兼容性提示，不是编译错误。此次未新增云基座或 Android 6 真机验收；已有依赖基座可通过 HBuilderX 本地联编应用源码改动。

## 2026-11-11 完整 Android 示例与本地联编 0.1.5

用户切换到有现有 AppID 权限的 HBuilderX 账号后，完整自定义基座云打包成功；AppID 保持 `__UNI__DC2611F`。小米已从 0.1.1 更新到完整 uni-app 示例 0.1.5（versionCode 105），使用更新安装而非卸载重装。

- 排查到旧调试产物与云基座混用时，Kotlin 跨文件 `internal` 访问器分别带有 `$main`、`$HelloFace_Verify_release` 后缀，曾触发 `NoSuchMethodError`。桥接成员加 `@PublishedApi` 保持 JVM 名称稳定；旧本地产物和旧云 DEX 被新增 ABI 检查拦截，修复后的 uni-app、uni-app x 本地 DEX 与新云基座均通过。
- `npm run check` 通过 80 项检查、37 个 SDK 文件校验及三端 UTS 转换；两个 Android 官方 UTS/Kotlin 编译检查通过，并检查真实 DEX 的桥接名称。
- 新基座 SDK、模型不压缩、源码指纹、16KB 静态对齐校验通过；APK SHA-256 为 `457fb2668175de757ea999b56ec1d27f7c1a0b262aa93a6c47b638e898f63e7e`，原生指纹为 `hfv1:6330b73fee6187b284b6d461477983bc3f3f355908adc58ed23c07812bccd65d`。设备仍为 4KB 页，不增加真实 16KB 页运行结论。
- 在完整示例中打开真实录入相机。用户操作后的页面观察到 `enrollFace:ok / passed: true / PASSED`；本轮不据此推导人脸比对准确率或活体攻击防护效果。
- 临时将 `HelloFaceVerifyCameraView.kt` 的页脚改成“本地源码调试”，经 HBuilderX 真机运行后，真实原生相机页面显示该文字；本地 DEX 也包含该标识，期间 APK 哈希不变，未再次云打包。随后逐字节恢复正式源码，确认重编译 DEX 不再包含临时标识。这证明已有依赖基座后，混编 Kotlin 源码可本地更新。
- 正式文案恢复后，完整 Vue 示例通过 UTS 打开录入和验证页面，取消录入正常收尾；在镜头未检测到人脸时，验证正常返回 `verifyFace:ok / passed: false / NO_FACE_TIMEOUT`。当前进程未发现 `FATAL EXCEPTION`，未把无人脸超时当成身份验证成功。
- 最终截图保存在忽略目录 `unpackage/screenshots/xiaomi-0.1.5-*.png`，本地联编证据为 `xiaomi-0.1.5-local-probe.png`；截图和用户特征不提交到 Git。原始相机画面、阈值、活体设置和 License 未修改。

本轮仅确认鸿蒙设备 ALN-AL80 / API 26 的 HDC 连接，尚未将完整鸿蒙示例安装到该设备；iOS 完整构建的工具链限制继续适用。

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
