# 验证记录

更新日期：2026-11-13。当前原生 SDK 0.8.11 Beta，上游提交 `dc60c7b15ebf8038fb73a752bcea3590bbd86eaf`；下方旧版本记录按当时版本保留。

## 2026-11-13 三端动作倒计时

- Android、iOS、鸿蒙的 `verifyFace`（含动作）和 `detectLiveness` 原生页面新增剩余秒数及逐渐缩短的圆环。对照上游 Android `FaceFlowUi` / iOS `FaceActionCountdown`，总时限为 `actionTimeoutMs × stepCount`；默认两动作显示约 6 秒。重复进度、换动作和携带 action 的短暂丢脸不重启；无动作/正脸稳定阶段、确认、重拍、取消和离页清理。仅为视觉提示，SDK 超时、判定、参数、存储及回调不变。
- `npm run check` 通过 153 项检查（114 JS、39 Python）、37 个 SDK 文件及三端 UTS 转换。新增鸿蒙真实方法计时回归覆盖重复事件、换动作、短暂丢脸、自定义时长、归零不重启和迟到定时回调；iOS 39 项纯状态检查通过。Android uni-app / uni-app x 官方 UTS、Kotlin、DEX、ABI 和现有编译后边界检查通过。
- 鸿蒙使用真实 0.8.11 HAR，清理本机生成模块后重新 `assembleHar` 通过；这不是完整 HAP 或真机验收。iOS 8 个 Swift 语法、真实 UIKit 和 AVFoundation/编译用 SDK 边界类型检查通过；本机 Xcode 15.2 无法全量编译上游 Swift 6 SDK，完整 IPA 和 iOS 真机仍未验。
- 三星 SM-S9210 / API 36 已用 HBuilderX 5.34 官方“已安装自定义基座”通道同步、启动根 Vue 示例，加载真实 SDK 0.8.11 及本轮本地编译原生 DEX。运行时只读 DEBUG_INFO 指纹为 `hfv1:4ba263d2060abcf53f0f9948c9fe494fd70bea22fd6572fab78a34d3b8900aed`，与本轮源码一致，busy=false。没有安装临时同包名宿主、卸载或清数据；UID、基准加密文件 SHA-256 前后完全一致，采样 App 日志未见原生崩溃。随后在三星独立活体（静默 + 眨眼、点头）实际运行，页面采样显示 `code=0 / passed=true / livenessScore=0.973`；用户明确确认“圆环和秒数正常，动作切换后继续计时”。真人检查后再次核对 UID 与基准加密文件摘要一致，任务结束 busy=false，日志未见原生崩溃。本轮未重新验证 1:1 身份匹配、其余动作组合或鸿蒙/iOS 真人效果；共用原生页面不等于这些用例均已实测。
- 规范插件、说明及 uvue 副本已同步。证据日志位于忽略目录 `unpackage/validation/action-countdown-20261113/`；不包含原始基准、特征或人脸照片。

## 2026-11-13 录入确认弹窗说明间距

- 照片下方两条说明新增独立的 `dialogTextGap: 8`，将原 16 的间距减半；照片、标题和操作栏仍使用原间距。Android/iOS/鸿蒙同步调整文本布局与滚动内容高度，uvue 插件副本及 Android 原生源码指纹已同步，未改识别、存储或回调行为。
- `npm run check` 通过 151 项检查、37 个 SDK 文件校验及三端 UTS 转换；Android 官方 UTS/Kotlin/DEX 与边界检查通过，鸿蒙当前原生 UI 配合真实 0.8.11 SDK 的 `assembleHar` 通过。iOS 8 个 Swift 语法、20 项状态、真实 UIKit 与编译用 SDK 边界类型检查通过；这不代表 iOS 真实 SDK 全量编译通过。
- 日志位于 `unpackage/validation/dialog-text-gap-20261113/`。本轮没有构建安装完整 App 或操作真机相机，最终设备观感需重新编译运行后确认；HAR、类型检查及界面布局检查不计作真人识别验收。

## 2026-11-12 0.2.0 代码整理与提交检查

- 归档本轮累计的三端原生页面、Demo 活体组合/动作勾选、图标、发行体积工具及发布/真机文档。根 manifest 恢复统一 JSON 缩进，字段和值保持不变；Android UTS 检查脚本共用 JDK 工具路径与运行时 classpath，修正检查说明的章节层级。
- 修复单 ABI 打包工具按字符串选择 Build-Tools、可能把 9.x 选在 36.x 前面且接受低于 35 版本的问题。新增两项回归在修复前均失败，修复后通过；当前机器正确选择 36.0.0 的 zipalign / apksigner。此修复仅影响维护工具，插件文件与保留的 0.2.0 发布包本地副本逐文件一致，未变更已发布业务实现。
- `npm run check` 通过 151 项检查（112 JS、39 Python）、37 个 SDK 文件校验及三端 UTS 转换。Android uni-app / uni-app x 两种模式均通过官方 UTS/Kotlin/DEX、稳定桥接 ABI、真实编译类的存储和取消协调器边界检查；这些边界检查不等于手机验收。日志为 `unpackage/validation/commit-0.2.0-{check,android-uts,android-uts-x}.log`。本轮未安装设备 App、变更签名或新增真人验收；既有未验项继续保留。

## 2026-11-12 插件 0.2.0 发布

- 插件、根工程与独立 uvue 示例版本同步为 0.2.0，Demo versionCode 为 200；更新日志归档至 0.2.0，保留“仅测试-”名称前缀、SDK、License、AppID 和签名配置。隐私声明仅保留实际数据处理行为，移除没有验收依据的泛化合规/上架承诺。
- `npm run check` 通过 149 项检查（112 JS、37 Python）、37 个 SDK 文件校验及三端 UTS 转换；HBuilderX 官方 CLI 的发布校验和 dry-run 均通过。完整插件包含三端真实 SDK，包内未发现签名资料、构建缓存或真机生物特征测试证据；示例包按既有规则排除 SDK 二进制，由市场完整插件提供依赖。
- 已通过 HBuilderX 5.34 `uni_modules --publish` 实际提交插件、示例及一张不含人脸的真实首页截图，返回 `success: true` / `outcome: published`。随后用未登录浏览器打开[公开插件页面](https://ext.dcloud.net.cn/plugin?name=HelloFace-Verify)，确认显示版本 0.2.0、更新日期 2026-11-12 及本次更新日志，不只是上传成功或待确认状态。
- 发布回执中的插件 ZIP 为 29,361,662 字节，示例 ZIP 为 2,189,485 字节。CLI 会清理临时 ZIP，故使用同一 HBuilderX 打包实现按提交后的源码保留本地副本，字节长度与回执一致；没有声称已对服务器 ZIP 做哈希比对。本地产物在 `unpackage/release/plugin-0.2.0/`，校验/检查/提交回执在 `unpackage/validation/plugin-0.2.0-*.log`。
- 本轮是版本整理与发布，没有新增真人或平台验收。下方鸿蒙真机结果来自发布前同一业务实现，测试 App 当时版本为 0.1.5；Android 新正式包、iOS 完整 App、真人识别/动作通过及独立 uvue App 的未验边界继续保留。升级须重新联编或重建包含原生依赖的运行产物。本轮没有自行提交或推送 Git。

## 2026-11-12 优化后完整 App 真机主流程回归

本轮针对根 Vue3 示例；没有安装临时预览宿主，没有卸载或清除数据。以下结果不包含真人识别通过，也不沿用此前版本的真人反馈。

- **鸿蒙完整 Release App 已实际运行**：HBuilderX 5.34 导出当前资源，DevEco 26 / Hvigor 以 `product=default`、`buildMode=release` 构建并沿用原本开发签名，覆盖安装到 Mate 60 Pro / ALN-AL80 / API 26。系统确认 `debug=false`，UID、首次安装时间、AppIdentifier 和签名叶证书保持一致。该身份用于本机验证，不代表已取得应用市场发行签名。签名 HAP 为 17,539,010 字节，SHA-256 `1a00a0c88978bd4882072d9fdc216f3b6af4d23e051be91f3773498e70536679`。
- **未录入提示与操作恢复**：不存在的临时 faceID 发起验证，立即出现“请先录入或同步人脸”Toast，结果 code 105；后续操作可继续。录入、1:1 验证、独立活体均能打开实际原生相机页；返回取消得到 code 103，后续可重新进入。录入期间回桌面再返回，任务已取消，页面解除忙碌。连续双击独立活体按钮只出现一个原生检测页。
- **验证与活体的真实超时分支**：独立活体两次、1:1 默认静默模式和静默加眨眼/点头模式各一次，实际采集后返回 code 203“未检测到人脸”、`passed: false`，界面可继续调用；动作模式结果快照保留“静默 + 动作活体 · 眨眼、点头”。这些结果证明真实采集的无人脸超时分支，不代表真人活体或动作通过；本轮没有受控的真人/照片攻击场景。
- **Demo 交互**：真机切换显示仅静默、静默加动作、仅动作、仅人脸比对四种组合；四动作可全选、按固定顺序展示，取消到最后一个动作时仍保留该项。重启后恢复静默开/动作关与默认眨眼、点头选择。以上是交互验证，未声称四种模式均完成真人验收。
- **同步、持久化与清理**：仅向本轮不存在的临时标识同步内置 AI 演示图片及特征，两种方式均返回 code 0。重启 App 后该临时基准仍能解密并进入验证；删除确认选择取消时保留记录，确定后删除成功。整个过程逐条比较既有加密记录的键/密文摘要：原有 1 条记录逐字节不变，临时记录已全部清理。未导出或保存原始基准特征、采集照片。
- **资源与日志**：捕获到窗口亮度进入设为 `1`、退出/后台/超时恢复 `-1`（跟随系统），结果均为 0；所捕获应用日志没有 FATAL、JsError 或 Unhandled 标记。系统 faultlogger 目录拒绝读取，因此没有将系统崩溃目录检查记作通过。
- **Android 本轮尚未完成新版验收**：GRA-UL00 / API 23 / ARM64 已连接。25,054,129 字节 ARM64 正式包与原 App 证书相同，但覆盖安装在华为系统确认页要求确认读写 SD 卡权限，未代用户确认。核对发现旧/新 Manifest 均声明这两项权限，不能称为新版新增声明。已取消该次安装，并恢复为安装准备而暂存的原始生成页面缓存；原 APK、UID、两条基准密文聚合摘要和密钥存在状态保持不变。`android:check` 判定现有旧调试基座与当前源码不匹配，因此没有把原基座运行记作本轮新版通过。需要用户决定允许当前安装，或先去除多余权限并重建。
- **仍需配合/条件**：最新版本的真人确认录入、本人 1:1 通过、所选动作实际通过，以及他人/照片拒绝均未完成；每步 3 秒的真人动作可用性尚未验收。iOS 没有连接设备且仍受现有 Xcode/SDK 工具链限制；独立 uvue 完整 App 本轮未测。本轮未发现需要修改插件业务源码的问题，仅补充实际验证记录，没有自行提交推送。

本轮私有本地证据位于忽略目录 `unpackage/validation/mainflow-20261112/`：`harmony-tested-artifact.json`、安装前后包信息、`hm-*-result.json` / `hm-*-timeout*.json`、`harmony-*-references.json`、`harmony-final-live-log.txt`，以及 Android 安装确认页布局、缓存恢复和前后只读审计。当前测试 HAP 位于 `unpackage/dist/build/app-harmony/entry/build/default/outputs/default/entry-default-signed.hap`。

## 2026-11-12 Demo 安装包体积与发行配置

- 仅优化 Demo 的 APK / IPA / HAP，未改锁定 SDK、License、签名身份、API、阈值和存储。Android 资源名称优化显式开启（5.34 已默认开启，不能算新增收益），通用包保留 ARM64 / ARMv7；iOS 根 Vue 固定 SDK 支持的 ARM64，并提供仅供本地宿主使用的 Release.xcconfig。详细构建方式、混淆边界和工具见 [安装包体积](APP_SIZE.md)。
- Android 云端正式构建成功，保留版本 0.1.5、包名和原证书，关闭 debuggable：通用 APK 31,777,772 字节，原调试基座 32,383,813 字节。随后从同一正式包生成 ARM64 直接分发副本 25,054,129 字节，通用包未修改；保留文件逐项哈希一致。两个 APK 均通过签名、SDK 原生库哈希、模型不压缩和 16KB 检查。正式 CLI 只返回临时下载地址，构建工具已补齐保密下载与异常响应校验，3 项回归覆盖 ANSI 链接、误取推广链接和过期 HTML，不重复提交云构建。
- 鸿蒙通过 HBuilderX 正式资源编译、Hvigor Release 完整 HAP 构建及原有本机调试身份签名，`app.debug=false`。签名 HAP 从 22,180,901 降至 17,539,009 字节（-20.93%）；无源码映射或 x86_64 库，存在混淆映射。SDK libhiface.so 哈希及证书链与原包一致，hap-sign-tool 验证通过。保留属性、导出和文件名称，仅默认局部混淆/压缩；已编译二进制 HAR 不会再次混淆。AppScope 增加必要 icon/label 引用，修复生成工程必填字段缺失。
- iOS 仍受 Xcode 15.2 无法完整编译 Swift 6.1.2 SDK、原生宿主/签名未完成等条件限制，没有本轮 IPA 前后体积或真机结果。以上 APK / HAP 未安装到手机，未新增真人识别或压缩后版本的真机回归，也未卸载/清数据。前后 Debug / Release 页面版本不同，不是单独切换混淆的对照实验。
- `npm run check` 通过 149 项检查（112 JS、37 Python）、37 个 SDK 文件校验及三端 UTS 转换。证据：`unpackage/validation/app-size-{before,after}.json`、`app-size-harmony-result.json`、`app-size-harmony-{pack,sign,verify}.log`；正式 APK 与变体在 `unpackage/release/apk`，签名 HAP 为 `unpackage/validation/HelloFace-Demo-release.hap`。`app-size-check.log` 保存本轮检查结果。

## 2026-11-12 每步动作默认超时 3 秒

- `verifyFace` 和 `detectLiveness` 的共享默认 `actionTimeoutMs` 改为 3000，Android 直接读取共享参数，iOS/鸿蒙原生缺省值同步为 3000。显式配置仍优先，2000–30000 毫秒范围和等待人脸超时保持不变；接口注释、API、README、更新日志及 uvue 副本已同步。
- `npm run check` 通过 146 项检查（112 JS、34 Python）、37 个 SDK 文件校验及三端 UTS 转换；iOS 相机控制器 Swift 语法检查通过。日志：`unpackage/validation/action-timeout-check.log`。本轮未构建安装完整 App 或新增真机计时验收，设备需重新编译运行后使用新的默认值。

## 2026-11-12 Demo 四种动作勾选

- Vue/uvue 的身份验证与独立活体分别提供眨眼、张嘴、摇头、点头勾选，默认眨眼、点头；保留静默开/动作关和身份验证四种组合。动作开启时至少保留一项，最后一项禁止取消，提交处也校验非空；关闭开关保留选择但不传动作。按列表顺序调用，忙碌时锁定选项，结果快照包含本次动作名称。公共 API、SDK、存储及阈值未改动。
- 28 项页面行为检查通过，覆盖两类流程全部 15 种非空动作组合、顺序归一化、空选择拦截、独立选项、忙碌锁定及提交快照。HBuilderX 5.34 Vue3 App 资源导出与 Web 编译成功；uvue SFC 脚本、Kotlin/Swift 模板生成及 Android/iOS/HarmonyOS CSS 检查通过。
- Web 实际交互确认最后一个动作无法取消，四项可全选，两类流程独立。四项同一行、字号 12px、点击高度 44px；320px 窄屏下两组四项的纵坐标一致。证据位于 `unpackage/validation/action-checkboxes-{web-preview.jpg,layout.json,css.json,demo-tests.log}`。预览后恢复默认选项；未安装 App、调用真机相机或新增真人识别验收，模板/CSS 检查不代表完整 uvue 原生 App 验收。

## 2026-11-12 返回箭头视觉对齐与无基准 Toast

- 用户指出文字和箭头仍未垂直对齐：先前只核对控件边界，未能证明字形的视觉中心一致。本轮三端移除字体字符箭头，改用原生图形路径，保持返回按钮点击范围和取消语义。鸿蒙真机进一步发现 Path 坐标使用像素而组件尺寸为 vp，已使用 UIContext.vp2px 统一坐标，并仅对图形作 1vp 的汉字视觉中心补偿。
- 华为 Mate 60 Pro 上，最终原生录入页顶部裁剪图的箭头/标题墨迹中心差为 0px（按本次截图像素测量），验证文件为 nav-toast-20261112-harmony-header-pixels.json。只保留顶部图，获取它所用的整屏临时图已删除；未保留人脸画面。页面检查后返回 Demo，没有确认保存。
- Vue/uvue 在现有 fail 回调收到 code 105 时立即 Toast“请先录入或同步人脸”，保留结果区与 complete 收尾，不增加状态预读 API。新增两套 Demo 的回归检查覆盖提示内容、解除 busy 后重试，以及取消不弹无基准提示。华为 Mate 60 Pro 没有基准时实际点击 1:1 验证，最终版本截图确认 Toast 立即出现；未通过删除已有基准来制造条件，偏好目录原本为空。
- 140 项现有检查（106 JS、34 Python）、37 个 SDK 文件、三端 UTS 转换通过；Android uni-app / uni-app x 官方 UTS/Kotlin/DEX/ABI 通过；Vue3 App 资源编译、uvue SFC 脚本及 Kotlin/Swift 模板生成通过。iOS Swift/状态、UIKit 与编译边界检查通过，真实 SDK/IPA 和真机未验。鸿蒙最终完整签名 App 构建、同身份覆盖安装成功，并重新验证了标题栏和 Toast。
- Android GRA-UL00 已更新到本轮本地编译指纹 hfv1:ec0ed81a7fcec391f2583bca52eeacaedb53e53836e4eb00716ff375a791df92；但标题像素截图抓到页面切换过程，随后设备自动锁屏，未将该中间截图或未完成的临时 faceID 测试记作最终实机通过。本轮最终实机验收以 Mate 60 Pro 为准；三星按用户后续指示未继续部署这两项最终修复。
- GRA 的只读记录在本轮期间由 1 条增至 2 条，UID 和密钥条目仍在；无法仅凭聚合摘要判断原记录是否逐条相同。本轮自动操作没有调用保存/删除接口或确认保存，未自动删除或回滚这些记录；已重启 Demo 清除临时输入。该情况没有记录为“基准逐字节不变”。SDK、License、阈值、存储语义及签名身份未改。

证据位于忽略目录 unpackage/validation/nav-toast-20261112-*。Vue/uvue 与规范插件同步，未提交推送。

## 2026-11-12 原生 UI 复查优化及设备运行

- 复查精简页后，将三端导航标题从固定 96 宽改为使用返回按钮右侧剩余空间，保持单行并支持尾部省略；返回按钮点击区域由 44 扩为 48，Android 去掉箭头字体的额外上下留白。清除仅由旧布局遗留的 headingWidth、captureReserve、buttonOffset、confirmationOffset 配置，不改变识别/活体、存储或 SDK。
- 138 项现有检查（104 JS、34 Python）、37 个 SDK 文件及三端 UTS 转换通过；Android uni-app / uni-app x 官方 UTS/Kotlin/DEX、ABI 和已有边界回归通过。iOS 8 个 Swift 语法、20 项状态、真实 UIKit 与编译边界检查通过；真实 SDK 全量编译、IPA 和真机仍未完成。
- 鸿蒙重新清理电脑生成工程的 entry 构建输出，使用当前原生源码和真实 SDK 构建完整签名 App。安装前核对 Profile、公钥及 AppIdentifier；同身份 install -r 更新成功，UID、首次安装/安装时间保持一致，已启动新版 Demo。实际打开独立活体页，原生 UI 树确认标题位于返回按钮右侧且同高居中（按钮 [39,149][195,305]、标题 [208,149][1182,305]），指定文案均已移除；随后返回 Demo。未记录真人活体通过。
- Android 使用现有完整 SDK 0.8.11 基座，加载本轮官方工具链编译的本地 UTS/Kotlin DEX；不是新的完整 APK。华为 API 23 的辅助包安装未完成，因此未执行计划中的离屏组件预览。改为该已核对 API 23 设备的外部开发资源同步：确认包、SDK、AppID 和当前 APK 后，将 20 个页面/DEX 文件写入独立暂存目录，原子替换并完整保留原 www 备份；没有写入私有基准目录。这是该旧系统的现场回退，不适用于 Android 11+ 的受限目录，也未放宽脚本的基座校验。
- Android 已实际启动，运行指纹为 hfv1:f355b55917063c12f40d357e63dc65c412bed9c2539d75745f96bff26d438fa8，与本次本地编译一致。实际打开录入页并取消；原生 UI 树确认标题 [192,96][1008,240] 紧随返回按钮 [36,96][180,240]，两者垂直中心一致，且没有“本机处理”和底部品牌文字。本轮没有拍摄/保存相机截图或确认保存；打开页面不等同于真人录入/身份验证通过。
- 本轮开始前发现用户基准密文已与更早记录不同，因此重新只读采样作为本轮基线，未沿用旧摘要。更新后及实际录入页取消后均核对原 1 条基准、相同密文摘要、Keystore 密钥及 UID，没有确认覆盖或同步演示基准。当前 Android App 启动采样日志未见原生崩溃或脚本异常。
- 三星 SM-S9210 始终未恢复连接；按本次“运行到设备”指示，已运行到在线的华为 GRA-UL00 和鸿蒙 Mate 60 Pro，没有改为操作其他在线手机。三星与 iOS 的本轮界面实机验收仍未完成。

证据位于忽略目录 unpackage/validation/native-ui-review-20261112-*；原生相机页面仅保存 UI 层级文字/坐标，不保存人脸图像。规范插件和说明已同步至 uvue，未提交推送。

## 2026-11-12 原生页面精简与标题左移

- 三端录入、身份验证和独立活体共用页移除“本机处理”徽标及底部“人脸处理在本机完成 / HelloFaceVerify”两行；同步删除对应控件、布局和共用配置中的无用项。导航标题紧跟返回按钮，采用同一高度并垂直居中，动态引导提示保持原位。
- 预览开孔向外扩大 7dp/vp/pt 至原灰色外圈的位置，只绘制一条状态轮廓；录入进度弧沿相同圆周绘制。SDK、相机分辨率、识别/活体参数、确认保存与取消逻辑均未改变。
- npm run check 通过 138 项（104 JS、34 Python）、37 个 SDK 文件和三端 UTS 转换。Android uni-app / uni-app x 的官方 UTS/Kotlin/DEX、ABI 及现有编译产物边界检查通过；本轮本地编译指纹为 hfv1:147401e022baf9f472359de2496989b62eb6989d5fe7764d052907b2d2b613d3。iOS 8 个 Swift 语法、20 项状态、真实 UIKit 与编译边界检查通过；真实 SDK/IPA 和 iOS 真机仍未验。
- 鸿蒙真实 HAR 编译通过；初次完整 App 增量构建仍复用了旧 entry 缓存，随后清理生成工程的 entry 构建输出并重建完整签名 App 成功，已检查 entry 新编译代码含 circleExpansion/headingGap，且不再包含 localLabel。清理范围仅为电脑上的生成构建目录，没有清理手机 App 数据。
- 用户要求优先运行到三星：曾检测到 SM-S9210，但读取设备/应用信息前即从 ADB 列表断开，后续复查仍未连接，已请求重新连接并授权。新 Demo 与官方编译的原生 DEX 已准备好，尚未在三星安装、运行或进行本轮界面实机验收；未改为部署到其他手机，未触碰已有基准。本轮不将此前版本截图或真人结果当作新版 UI 验收。

证据位于忽略目录 unpackage/validation/native-ui-simple-20261112-*；规范插件及说明已同步至 uvue 副本，未提交推送。

## 2026-11-12 最新版重新运行到连接设备

- 鸿蒙 Mate 60 Pro / API 26：重新导出完整 Vue3 示例，并用现有 debug 身份构建签名 HAP。核对 Profile Bundle、AppIdentifier 和 EC 公钥与已安装应用一致，手动 hdc install -r 覆盖安装成功；保留 UID 20020223、firstInstallTime、installTime 和签名身份。11:04 启动后实机显示最新绿色验证卡片、独立活体入口；HAP 内 UniApp 图标层已检查。偏好目录更新前后均为空，没有写入演示基准。当前进程采样日志未见崩溃或脚本错误。
- Android GRA-UL00 / API 23：新基座于 11:17:56 构建成功，SDK/模型、源码指纹及 16KB 静态检查通过。证书与原包相同，11:19:31 覆盖安装成功，保留 UID 10118 及首次安装时间 2026-11-09 19:38:18。安装后和页面同步后均只读复核：原 1 条基准、密文 SHA-256 及 Keystore 密钥均保持不变。APK 内放大并下移的 UniApp 图标已检查。
- Android 发现旧 www 中 UTS 热更新 DEX 使运行指纹仍为旧版，且 HBuilderX CLI 未下发新页面。采用独立包名、相同证书且无 Activity 的 instrumentation 暂存纯页面 ZIP，再调用既有 DEBUG_SYNC，19 个文件更新，旧 www 移至备份。重启后实际运行指纹为 hfv1:9c0bc7a1b26d0a0b7ffa195e56f45654bca187bfff5a3ac9f9ef23d7fca11f88，与新 APK 一致；实机截图确认绿色边框、白底验证按钮及独立活体卡片，App 保持前台运行。
- 实测修复 API 23 am 不支持 --receiver-foreground，以及厂商 pidof 忽略包名的问题；20 项调试脚本检查通过，实际进程过滤已复核。当前 Android App 主进程/JS 子进程采样日志未见 FATAL EXCEPTION、脚本异常或页面加载失败。
- 本次只验证完整更新、启动、页面与图标资源、运行原生版本和数据保留，没有调用相机、录入、同步演示基准或新增真人识别/活体验收；iOS 无连接设备，未运行。证据位于忽略目录 unpackage/validation/device-run-20261112-*，未提交推送。

## 2026-11-12 全局扫描与 UniApp 图标

- 扫描三端公开入口、共享参数/结果分发、原生互斥、权限、帧处理、取消/重拍、亮度与存储，以及 Vue/uvue 接入。保留 SDK 0.8.11、公共 API、阈值、签名、License、存储格式和已有工作；两套 Demo 保留单一标识、四种验证组合、独立活体入口及直接 API 调用，没有增加多余封装。
- 修复 Android clearAnalyzer 后立即关闭 SDK/释放操作槽的时序：停止接收旧帧，在串行分析队列排入屏障，等待 ImageProxy finally 后再解绑、关闭或重拍。取消确认等待释放；重复取消共用收尾，首个终态不被覆盖，迟到结果不能结束重入的新任务。依据 CameraX 图像分析和锁定 SDK 的缓冲借用契约，见 [官方核对](OFFICIAL_REVIEW.md)。
- 三端共享分发器拒绝 passed=true 但 outcome 不是 PASSED 的矛盾响应，返回 BRIDGE_ERROR，fail/complete 各一次，不修改合法 SDK 结果。API 文档纠正了“UTS 已检查特征数值内容”的过度描述：共享层只查长度、字符集、空间，实际比对由 SDK 完成。
- npm run check 通过 135 项（104 JS、31 Python）、37 个 SDK 文件及三端 UTS 转换；Android uni-app / uni-app x 的官方 UTS/Kotlin/DEX、桥接 ABI、3 项存储边界和 4 组实际编译协调器时序回归通过。后者使用可控主循环/Activity 释放边界，不代表真实 CameraX 帧或真人识别。DevEco 使用本次共享层官方 ArkTS 输出及真实 0.8.11 SDK 构建 HAR 成功。
- iOS 8 个 Swift 语法、20 项纯状态、真实 UIKit 和编译用 SDK 边界类型检查通过，保留旧 UIKit 并发警告；Xcode 15.2 仍未完成真实 Swift 6.1.2 SDK 编译、完整 IPA 或真机验证。本轮未安装 App、调用相机或读写用户基准；Android 新的取消/重拍帧收尾、三端当前版本真人主流程和更新后桌面图标观感待真机复验，旧结果不计入本轮。
- 图标以保留的最初底图重新添加红色 UniApp，文字约为旧版两倍，并按用户反馈再下移约 16px，保留头发上方空隙。母版 1024×1024，无 alpha；19 份母版/平台 PNG 检查通过（鸿蒙前景保留透明边距），Vue/uvue 资源副本一致。需要重建原生基座/安装包，页面刷新不能替换桌面图标。

本轮构建与检查证据：忽略目录 unpackage/validation/global-audit-20261112-*。未提交推送。

## 2026-11-12 独立活体 Demo 入口

- 此前只有插件接口，首页没有独立活体入口。Vue/uvue 现在在“1:1 人脸验证”下方增加“独立活体检测 → 开始活体检测”，直接调用 detectLiveness，不传 faceID/基准，不读写身份数据；单独的动作开关默认关闭，开启后追加眨眼、点头，不改变身份验证的两个开关。
- SDK 0.8.11 始终执行静默活体，界面明确说明“只验真人、不比对身份”，未展示不存在的静默关闭能力。actions 为空是有效的静默检测；“两个都关报参数错误”与当前接口契约不符，API/readme 已补充说明，SDK 和公共 API 未改动。
- 新入口复用 busy、success/fail/complete 及离页取消；结果标记“独立活体”和提交模式，空 faceID 不显示标识行。20 项页面检查通过，覆盖空标识、独立动作选择、忙碌锁定、结果快照、权限错误、complete 收尾、离页取消及 Web 拦截。全套检查通过 132 项（101 JS、31 Python）、37 个 SDK 文件校验和三端 UTS 转换。
- HBuilderX 5.34 的 Vue3 App 资源和 Web 导出编译成功，uvue SFC 脚本与 Kotlin/Swift 模板生成通过。360px Web 预览确认入口、用途说明及独立动作开关：切换独立动作时，身份验证仍为静默开/动作关，检查后恢复默认。证据为忽略目录 `unpackage/validation/demo-liveness-20261112-*`；本轮没有调用真机相机、安装 App 或新增真人活体验收。旧基座若缺少 detectLiveness，需要先原生联编/重建，再运行新版页面。

## 2026-11-12 Demo 字号与开关尺寸

- Vue/uvue 同步去掉“插件调用示例”标题和对应无用样式；辅助说明缩为 11–12px，结果文本为 13px。活体开关以右侧中心为基点等比缩小至 80%，选项行最小高度由 68px 收为 60px，保留 label 行和原有事件、防重复、四种组合及模式快照。
- 验证卡片四边改为与功能按钮相同的绿色线框；“开始 1:1 验证”直接继承通用 action 按钮的白底、绿色边框和绿字，仅保留卡片内部所需的底部间距。Vue/uvue 两页同步，16 项行为检查、Vue3 App 资源导出和 uvue 脚本/模板检查再次通过。
- 绿色样式在 360px Web 预览确认：卡片四边均为 `#72CCAE`，验证按钮与其他功能按钮的边框、底色、文字颜色、高度及圆角计算值一致。Web 导出编译成功，截图为 `unpackage/validation/demo-green-20261112-web.png`；Android 当前缓存页面未同步到本次颜色更新，未将旧截图计作新版样式实机确认。
- 16 项页面行为检查通过，HBuilderX 5.34 的 Vue3 App 资源导出成功，uvue SFC 脚本和 Kotlin/Swift 模板生成通过。Android API 23 上通过已有基座的页面更新实际检查布局、缩小后的动作开关切换和组合说明，随后恢复默认静默开/动作关；没有重新安装 App 或调用录入/同步/识别。截图和日志位于忽略目录 `unpackage/validation/demo-compact-20261112*`；未新增 iOS/鸿蒙真机或完整 uvue App 验收。

## 2026-11-12 官方规范核对与修复

- 核对 DCloud/UTS、CameraX、UIKit/AVFoundation、HarmonyOS/ArkTS 及锁定 SDK 的公开契约；依据、保留项和调整边界见 [官方规范核对](OFFICIAL_REVIEW.md)。修复 Android 分析流的回退候选未限制 SDK 尺寸上限的问题，保留 640×480 偏好和 CameraX 顺序；读取基准时密钥缺失现在直接存储错误，不生成替代密钥，保存逻辑和已有密文格式不变。
- `npm run check` 最终通过 128 项（97 JS、31 Python）、37 个 SDK 文件校验及三端 UTS 转换。Android 的 uni-app / uni-app x 官方 UTS、Kotlin、DEX 与稳定桥接 ABI 检查通过；两种模式均实际加载编译后的 ReferenceStore，三项 JVM 边界检查通过：缺失密钥读取不生成、已有密钥 AES-GCM 往返、密文绑定 faceID。该提供器/Preferences 边界不是真实 Android Keystore，不计作手机验收；同一回归对修复前的 ReferenceStore 实际失败（读取尝试生成密钥），修复后通过。
- iOS 8 个 Swift 语法、20 项纯状态、真实 UIKit 和仅供编译的 SDK 边界类型检查通过；保留旧工具链对 UIKit 可访问性常量的并发警告。当前 Xcode 15.2 仍不能完成 Swift 6.1.2 SDK 全量编译/IPA，没有 iOS 真机结果。
- DevEco 对当前插件及真实 0.8.11 HAR 的 `assembleHar` 通过。HBuilderX 5.34 在 09:15:14 报告完整鸿蒙发行安装包制作成功，产物是 `unpackage/dist/build/app-harmony/build/outputs/release/app-harmony-release-unsigned.app`，发行通道未配置数字证书，因此未签名、未安装。发行工程的原生 .ets 与规范目录逐字节一致；独立 HAR 检查目录的精简 AppScope 缺少 icon/label，直接拿它构建完整 HAP 曾失败，随后通过 HBuilderX 完整发行导出验证，未把精简目录当完整宿主验收。
- Vue3 App 资源在当前构建中编译成功；uvue SFC 脚本及 Kotlin/Swift 模板生成通过，未完成独立 uvue 原生 App 链接。两套 Demo 的页面源码均未改动；保留单一默认标识、四种活体组合及模式快照。
- 用户本轮补充反馈“弹窗和图片大小合适”，记为此前鸿蒙新版确认弹窗的界面反馈，不计为本轮新增接口、身份比对或活体通过。
- Android GRA-UL00 / API 23 重新连接后，先用独立包名、同证书且无 Activity 的 instrumentation 只读记录原基准。最终正式调试基座经源码指纹、SDK/模型/16KB 静态校验后，以相同证书覆盖安装；保留 UID 10118 和首次安装时间 `2026-11-09 19:38:18`。已有 1 条基准的密文摘要逐字节相同，仍能正常解密；没有把公开 AI 图片同步或保存为用户基准，没有卸载/清数据或安装同包名预览宿主。
- 最终 APK 上 23 项真实原生检查通过：getFaceStatue 的存在/缺少和不泄漏特征、读取原基准、真实 SDK 提取公开 AI 图片得到 HF1 且不作身份判定、独立活体实际 CameraX STREAMING、协商分析尺寸 640×480、共享操作槽 BUSY、满亮与原值恢复、主动取消及槽位复用、独立活体无人脸超时、verifyFace 四种组合均返回实际 NO_FACE_TIMEOUT / passed false、切后台取消及资源复用，以及纯接口前后基准未改。它们直接调用 App 的原生入口；不替代 Vue/uvue 接入和真人识别/活体通过验收。
- 在这台旧系统上复现并修复脚本把 sha256sum/getconf 的“命令不存在”误当成功输出的问题。新增 3 项 Python 回归通过；APK 字节回退核对确认手机安装包与当前基座相同，smaps 实测 4096 B。run-as 被厂商系统拒绝，改用 HBuilderX 已安装基座通道，09:40:53 Vue3 编译成功、09:40:59 页面同步成功、09:41:02 启动成功；冷启动页面默认静默开/动作关。真实 16KB 系统、iOS 真机仍未验。
- 完整 Vue 页面以仅静默活体模式触发 verifyFace，当前进程原生日志在 09:47:03 返回 OK / PASSED（3557ms）。操作者随后明确确认“是，本人正对了镜头”，据此补记本轮 SDK 0.8.11 的 Android GRA-UL00 / API 23 完整 Vue Demo 本人验证通过；本次是已有基准的真实 1:1 验证，与上文 instrumentation 的四种组合无人脸拒绝分别记录。本轮动作组合的真人通过、他人拒绝及照片/屏幕攻击仍待验证。页面运行后的只读复查仍为原 1 条基准、相同密文摘要及相同 UID，没有同步替换基准。采样的本进程原生日志未见 FATAL EXCEPTION。

本轮证据位于忽略目录 `unpackage/validation/official-audit-20261112-*`，包含构建日志、APK/鸿蒙产物收据、独立检查源文件和只读摘要。SDK 版本、License、AppID、签名身份和阈值未改，未提交推送。

## 2026-11-12 三个独立插件接口

- 三端新增 `detectLiveness`、`extractFaceFeature`、`getFaceStatue`，沿用 options、success/fail/complete、code/msg 和统一互斥。独立活体与纯提取不要求 faceID、基准或写入存储；状态查询只读/解密后返回 exists，缺少基准正常返回 false，读写异常仍 fail，不返回原始特征。
- SDK 仍为 0.8.11 Beta。核对三端实际公开声明和锁定 SDK 文档后，独立活体直接调用 `startCameraLiveness`：始终包含静默活体，actions 非空时追加动作，不暴露无效的关闭开关。没有构造虚假身份基准，不用相似度改写活体判定。新相机入口共用权限、取消（含授权尚未返回时）、亮度和资源释放，并显示“活体检测”。
- 纯提取复用 FaceImageImporter 与图片限制，只返回 feature/featureSpaceID。Android 延迟创建存储对象，iOS/鸿蒙跳过基准读取；查询/提取均不打开相机，状态查询不创建识别 SDK。存储实现、键、License、模型、阈值及老接口未改动。
- `npm run check` 通过 125 项（97 JS、28 Python）、37 个 SDK 文件校验和 Kotlin/Swift/ArkTS 转换。新增用例覆盖无基准参数、活体 SDK 否决不被高分覆盖、特征/相似度不泄漏、缺少基准与损坏存储的区别、提取不读写存储、忙碌期间互斥以及授权前后取消与迟到事件。原生边界可控测试不代表实际识别/活体通过。
- Android 官方 uni-app 与 uni-app x UTS/Kotlin/DEX 编译和 JVM 桥接 ABI 均通过。iOS 8 个 Swift 语法、20 项状态、真实 UIKit 和仅供编译的 SDK 边界类型检查通过；真实 SDK 全量编译/IPA 仍受本机 Xcode 15.2 不支持 Swift 6 限制，未新增 iOS 真机验收。
- 使用当前官方 UTS ArkTS 输出与生成宿主 runtime imports、当前原生 .ets 和真实 0.8.11 HAR，DevEco `uni_modules__helloface_verify:assembleHar` 编译成功。修复检查中发现的结果 exists 未在对象构造时赋值的问题：查询返回 true/false，其他方法显式 null。该 HAR 不可单独安装，不代表完整 HAP 或真机验收；没有主动安装新 App、写入测试基准或沿用前一版真人结果。

证据位于忽略目录 `unpackage/validation/new-apis-*`。接口/SDK 边界与短示例见 [API](API.md) 及插件 readme；uvue 副本已同步。新增原生方法需重新联编或重建基座，纯页面刷新无法更新旧原生产物。

## 2026-11-12 Demo 统一默认 faceID

- Vue/uvue 统一默认 `demo-user`。相机录入、验证、演示图片/特征同步和删除均使用当前输入的 `faceID`；同步不再切换到另一个标识，保持原有 `overwrite: true`，会替换当前标识的基准。用户手动修改标识后同步也继续使用该值。
- 按钮改为“同步演示人脸图片 / 同步演示人脸特征”，移除同步标识说明及结果框底部小字，删除对应无用样式。保留四种活体组合、模式快照、防重复、离页取消和删除确认。
- 更新现有页面回归，16 项通过，覆盖默认/自定义标识同步、覆盖参数与原有交互。HBuilderX 5.34 的 Vue3 App 资源和 Web 导出编译成功，uvue SFC 脚本及 Kotlin/Swift 模板检查通过；实际导出 JS 的两个新文案存在，旧标识和两条底部说明不存在。未调用真机同步或改写设备基准，未新增真人识别验收。

## 2026-11-11 Demo 四种活体组合

- 根 Vue 和独立 uvue 示例将两个含义不够明确的验证按钮改为“静默活体 / 动作活体”独立开关和一个“开始 1:1 验证”按钮，覆盖仅比对、仅静默、仅动作、静默 + 动作四种组合。默认静默开启、动作关闭；直接向 `verifyFace` 传布尔值和动作数组，动作固定为眨眼、点头。SDK 0.8.11、原生 API、阈值、默认值及存储不变。
- 显示当前组合及操作说明，两种活体关闭时明确显示只做人脸比对；调用期间禁用开关并拦截重复调用。结果区域记录本次提交的组合，之后调整开关只影响下一次调用，录入/同步/删除时清除上次验证模式。
- `npm run check` 通过 113 项（85 JS、28 Python）、37 个 SDK 校验与三端 UTS 转换。新增页面脚本检查逐一确认四种选择传给 `verifyFace` 的参数、等待期间锁定和结果模式保留；测试使用原生调用替身，不模拟识别成功。插件说明已同步到 uvue 副本。
- HBuilderX 5.34 的 Vue3 App 资源导出和 Web 导出编译成功；官方 uvue 编译器的 SFC 脚本编译及 Kotlin/Swift 模板生成通过，不代表 uvue 完整原生 App 链接或真机验收。
- 浏览器实际点击两项开关，四种组合说明都正确更新；390px 手机宽度截图正常，320px 时卡片边界为 x=16..304，无横向溢出。Web 点击验证仍提示去 App 真机体验，没有伪造通过结果。证据位于忽略目录 `unpackage/validation/liveness-combinations-*`；本轮未新增真人录入/比对或活体四组合的实机验收。

## 2026-11-11 三端样式与交互复查

**数据保留未达成**：临时同包名 UI 宿主安装后，正式示例的 `demo-user` 返回 105（请先录入）；通过 `hdc shell -b` 只读检查，当前 EL1/EL2 的应用及 entry Preferences 目录没有原基准文件。Bundle 安装时间为 19:16:48（首次 UI 宿主安装时），随后更新时间为 19:29:17。未找到可恢复副本，具体重置环节尚不能确定，不能把本轮安装视为保留数据成功，也不能据此认定 SDK 特征格式不兼容。没有用 AI 基准覆盖 `demo-user`。今后 UI 专用宿主必须使用独立 Bundle/沙箱，增量安装前后需核对安装时间、UID 及原基准可读性；同包名临时宿主生成脚本已撤除。

- `native-ui.json` 统一遮罩透明度 0.62、标题/关闭图标字号、188×188 最大图片、间距、圆角及按钮尺寸。三端标题和操作栏固定，中间图片/说明可滚动；缺图时收起图片空间、禁用确认；重拍回到采集，关闭取消整个操作，保存期间禁用返回/关闭/重拍/确认。同步 Android 的 700ms 稳定圆环，重复 HOLD_STILL 不重启，离开稳定阶段、确认、重拍和离页都会清理，动画不触发采集成功。
- 鸿蒙真机使用实际原生视图配公开虚构图片进行界面专用检查。实截图发现并修复关闭“×”被默认内边距挤没、重拍按钮的边框覆盖圆角两个问题；复截图确认关闭图标、圆角、完整比例、前置显示镜像及图片 611×611 物理像素（约 188vp）正常。实际点击检查了重拍、缺图禁用、关闭以及保存状态按钮禁用；确认后 1.15 秒内按硬件返回并截图，保存弹窗仍保留。证据为忽略目录 `unpackage/validation/ui-preview-harmony/` 的截图和 `harmony-ui-ui-fixed-*.json`。
- 界面专用宿主仅位于忽略的生成工程，覆盖启动相机与保存方法以注入公开图片、停留 UI 状态，并显示红色“不识别、不保存”标识；未调用真实录入/比对/写入基准。此结果只证明布局和交互，不能当成新版本真人录入、识别或活体通过。测试宿主已撤除，恢复了完整 Vue 示例。
- 整理后的 Android 自签名云基座已构建，SHA-256 `9a7657a2dc884fe71263564ade1bd57a351f06b1da032d8afe0d859371f39f06`，当前源码指纹、SDK 四个原生库、模型及 16KB 静态对齐检查通过；无连接 Android 手机，未新增安装或运行结果。
- 完整 Vue 示例于 19:27:01 制作签名 HAP 成功、19:27:03 安装成功，22,176,805 字节，SHA-256 `fd6fc972f7dde652a1ab2c1d9a09f70336cfc9ecd8da677439554085cf4a66d6`。HAP 内 SDK 库与锁定 HAR 一致，逐项扫描确认没有临时 UI 宿主导出、测试标识或之前的提取地址；设备已恢复正式 Demo。正式版本复测相机授权、录入打开及取消 103 通过；无基准处理返回 105。因原基准未保留，本轮没有新增无人脸超时、本人识别或活体验收；没有用上一轮 SDK 0.8.11 的结果替代本轮结果。检查原/现进程 Fatal 为 0，faultlogger 未发现该包的崩溃文件。
- `npm run check` 通过 111 项（83 JS、28 Python），包含预览缺失空间回收和短屏滚动边界；37 个 SDK 文件校验与三端 UTS 转换通过。Android 官方 uni-app / uni-app x UTS、Kotlin、DEX 和桥接 ABI 均通过。iOS 真实 UIKit 类型及纯状态检查通过；无 iOS 真机，本机 iOS 17.2 模拟器在启动进度中停留、安装超时，未得到插件运行截图。没有将编译用 SDK 边界或界面预览当成完整 iOS App 验收。

## 2026-11-11 小图确认弹窗与 SDK 0.8.11

- 对照上游提交 `dc60c7b15ebf8038fb73a752bcea3590bbd86eaf` 的 Android `dialog_face_enrollment.xml` 和鸿蒙/iOS 录入确认 UI，三端改成居中模态确认卡片，图片最大 188×188 逻辑尺寸，保持完整比例、圆角和前置显示镜像，不再将 333×333 对齐图铺满采集圆框。Android 使用 Dialog，iOS/鸿蒙使用原生页内模态卡片；小屏可滚动，保留重拍、取消、预览缺失禁用确认以及保存期间禁止操作。
- 三端 SDK 更新为 0.8.11 Beta，37 个文件按固定提交、SHA-256 和长度校验并安装。模型文件哈希与前版相同；公共 API、阈值、用户 License、存储键和已有基准保留。本次只改变确认图片的显示大小，采集目标与固定对齐图尺寸未提高。
- Android 新 SDK 使用 `libhiface_core.so` + `libhiface_opencv.so`。旧运行校验器固定检查 ncnn 库名，导致新云基座生成后被误报缺库；已改为从锁定 AAR 派生库清单，并对 APK 内每个 SDK 库逐字节哈希验证。新基座已通过 ARM64/ARMv7 四个库、未压缩模型、源码指纹和 16KB 静态对齐校验；Android 手机当前未连接，尚未安装/运行该新基座，不沿用旧版真机结果。
- SDK 安装器在新文件校验全部通过后，将旧版 hiface AAR/HAR 移到 `.sdk-cache/retired-sdk` 保留备份，避免重复依赖；其他 AAR 和 License 不动。新增回归检查覆盖旧库缺失/混入、未知 ABI、旧 SDK 退休备份以及确认图窄屏尺寸约束。
- 使用 SDK 0.8.11 的完整签名鸿蒙示例，对最终 200×200 AI PNG 实际调用图片同步、读取和删除。确认测试 HAP 原生库与新 HAR 一致后才启用提取，随机测试标识已删除。重新生成的 HF1 与旧版本不同，`demo/face-reference.json` 记录新 SDK、提交和提取平台；未只改版本标签沿用旧特征，Vue/uvue 常量已重新生成。临时提取入口及本机接收端已撤除，最终 Vue 页面与原版一致，最终 HAP 不含提取测试地址。
- 正式鸿蒙 HAP 于 18:49:38 构建成功、18:49:42 安装成功，大小 22,178,053 字节，SHA-256 `3e70d968daacb09ef78894fcca39b5080af242a591c0b95c8e2180cab47f67a3`。Mate 60 Pro / API 26 已打开新版录入相机；取消正常，原 `demo-user` 基准可读取并进入验证，无人脸返回 203 / `passed: false`，动作验证切后台恢复返回 103。本人确认图的弹窗观感、保存和本人/他人识别尚待操作者配合，不把原版真人通过计为新版通过。
- `npm run check` 通过 110 项（82 项 JS、28 项 Python）、37 个 SDK 校验和三端 UTS 转换。Android 的 uni-app / uni-app x 官方 UTS/Kotlin/DEX 编译与桥接 ABI 检查通过。iOS 8 个 Swift 语法、20 项状态、真实 UIKit 视图及编译边界平台类型检查通过；真实 SDK 完整编译仍受 Xcode 15.2 / Swift 6 限制，无 iOS 真机结果。旧 UIKit 可访问性常量的严格并发警告保留记录。

证据位于忽略目录 `unpackage/validation/sdk-0.8.11-*`。源码和依赖已同步到独立 uvue 示例；未新增 uvue 完整 App 真机验收。

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
