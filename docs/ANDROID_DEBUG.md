# Android 调试与实现

根目录 Vue2/Vue3 示例提供“编译页面 → 应用内同步 → 重启示例”的命令行调试通道；该通道只同步页面，对原生源码采用严格指纹校验，源码变更会要求重建基座。日常修改 `.uts` / `.kt` 查看效果，使用 HBuilderX 自身的本地编译运行通道即可，不必每次云打包。uvue 同样使用 HBuilderX 原生编译通道。

## 在 HBuilderX 中调试插件功能

1. 打开工程根目录 `HelloFace_uniapp`，这是 Vue 示例；要调试 uvue 则单独打开 `examples/uni-app-x`，先执行 `npm run demo:prepare` 同步插件。两个示例使用各自的 AppID 和基座。
2. 本工程包含第三方人脸 SDK，首次运行或 SDK、依赖、资源、Manifest 改动后需要自定义基座，不能选择标准基座。确认 HBuilderX 登录账号拥有当前 `manifest.json` 的 AppID 权限；执行 `npm run android:base` 自动制作并校验基座，或先执行 `npm run android:prepare`，再从 HBuilderX“运行 → 运行到手机或模拟器 → 制作自定义调试基座”制作。
3. 手机连接 USB 并授权调试。在 HBuilderX 选择“运行 → 运行到手机或模拟器 → 运行到 Android App 基座”，选小米并勾选“使用自定义基座运行”。已有最新版基座时可选“已安装的基座”，包名为 `dev.helloface.uniapp.demo`；使用本地基座时文件为根工程 `unpackage/debug/android_debug.apk`。
4. 运行成功后，在底部运行控制台点击红色虫子图标，选择“调试”；如需调试 App 初始化，开启后再点击旁边的“重启应用”。双击代码行号添加断点，然后在手机点击录入/验证按钮触发。
5. 按调用链设置断点：`pages/index/index.vue` 的 `enroll` / `verify` → `utssdk/app-android/index.uts` 的参数创建与原生调用 → `HelloFaceVerifyNative.kt` 的 `invoke` → `HelloFaceVerifyCameraActivity.kt` 的进度、采集、保存回调 → `shared.uts` 的结果分发。调试 Kotlin 时按 HBuilderX 提示安装 `kotlin-language` 插件。SDK AAR 内部源码未随本工程提供，可在调用前后检查参数、结果和日志。

HBuilderX 的“设置 → 运行配置”应配置 Android SDK、Gradle 和 Gradle JDK。本机已验证的组合是 JDK 17、Gradle 8.14.3、Android SDK `/Users/zlb/Library/Android/sdk`；不要使用不存在的旧 SDK 路径。环境配置见 [官方 Android UTS 运行说明](https://uniapp.dcloud.net.cn/tutorial/run/uts-development-android.html)，断点操作见 [官方 UTS/Kotlin 调试说明](https://uniapp.dcloud.net.cn/tutorial/debug/uni-uts-debug.html)。

页面改动可保存后刷新。已有包含 SDK/依赖的基座后，修改插件 `.uts` 或混编 `.kt` 可由 HBuilderX 本地联编、重新运行，不需要云打包；不要用只同步页面的 `android:dev` 来更新原生代码。本工程命令行入口（包括 `android:run -- --hbuilder`）会先校验完整源码指纹，开发中需要绕过这一保守检查时，应直接从 HBuilderX 运行菜单启动，而不是跳过 SDK/依赖校验。官方说明见 [UTS 原生混编](https://uniapp.dcloud.net.cn/plugin/uts-plugin-hybrid.html)。

更换 AAR/JAR/SO、修改依赖/Gradle、Manifest 权限或 Activity 声明、添加原生资源、更换应用图标时，需要重制基座或用完整本地原生工程重新构建；这不表示必须使用云端。`.java` 修改不属于上述 Kotlin 混编的直接联编范围，也需要重建。普通源码调试和正式安装包发布应分开：发布时仍要完整打包。

推荐在 `success` / `fail` 回调检查 `passed`、`outcome`、`errCode`、`sdkCode`；`complete` 仅用于恢复按钮状态。相机逐帧分析和动作活体期间应尽量使用日志，长时间停在断点可能使真实超时或人脸丢失判定触发。原生操作日志可另外执行 `npm run android:logs -- --follow --device 手机序列号`，不要把完整人脸特征或照片写入控制台。

## 接口改动后的本地编译检查

```sh
npm run android:uts-check                     # uni-app 的 UTS 桥接 + Kotlin
npm run android:uts-check -- --uni-app-x       # uni-app x 的 UTS 桥接 + Kotlin
```

这两项使用已安装的 HBuilderX Android UTS 扩展实际生成并编译插件，补充 `uts:check` 的三端源码转换检查。不打包、不签名、不安装 App，也不需要云端 AppID 权限；仍不能代替完整基座与真机验证。

编译后还会检查 DEX 中的桥接 JVM 方法名。0.1.5 起，跨文件访问的 Kotlin `internal` 桥接成员使用 `@PublishedApi` 保持名称稳定，避免本地 `main` 模块与云端 `HelloFace_Verify_release` 模块产生不同后缀而触发 `NoSuchMethodError`。从旧版升级需要重新制作一次基座，之后普通混编源码仍可本地联编。

需要 Android SDK、兼容的 JDK（本工程使用 17）与 Gradle 8。脚本优先使用环境变量，再查找常用 SDK 路径、本机 JDK 和 Gradle wrapper 缓存。非默认安装位置可设置 `HBUILDERX_PATH`、`ANDROID_HOME`、`GRADLE_JAVA_HOME`、`GRADLE_HOME`、`USER_DATA_PATH`（HBuilderX 用户数据目录）。首次解析第三方依赖时可能需要 Maven 网络访问。产物仅写入 `unpackage` 和工具链缓存。

## 常用命令

```sh
npm run android:devices                  # 查看在线、离线、待授权设备
npm run android:base                     # 生成指纹、云端制作基座、校验产物
npm run android:check                    # 只读检查基座、原生源码、SDK、16KB 与设备
npm run android:run                      # 一次页面编译、同步、启动
npm run android:dev                      # 监听页面修改并重新同步；Ctrl+C 结束
npm run android:logs                     # 当前进程的插件操作日志
npm run android:logs -- --follow         # 持续跟踪，App 重启后自动跟随
```

只有一台已授权在线设备时自动使用它，离线设备不参与选择。多台在线设备时必须传入 `--device 序列号`。`android:dev` 在启动时固定设备，断线后等待同一序列号重连。

`android:run` 比较手机安装包与本地基座的 SHA-256；相同则跳过安装。`--skip-install` 会严格要求二者相同，无法用正式包或另一版基座冒充当前调试包。签名不一致时提示使用原证书重建，不会卸载应用或清除本机人脸基准。

保留的入口：

```sh
npm run android:run -- --sync-resources   # 与 Vue 默认同步通道相同
npm run android:run -- --hbuilder         # 使用 HBuilderX 自身运行/监听通道
npm run android:run -- --project examples/uni-app-x  # uvue，由 HBuilderX 编译运行
```

uvue 先配置有效 AppID、执行 `npm run demo:prepare` 并制作自身基座，不能直接使用根目录 Vue 基座。

## 基座与签名

`android:base` 使用本机已有的调试证书。通过环境变量配置：

```sh
export HELLOFACE_ANDROID_CERTFILE=/本机路径/demo.jks
export HELLOFACE_ANDROID_CERTALIAS=自己的别名
export HELLOFACE_ANDROID_STOREPASS=自己的密码
# 私钥密码不同时另设 HELLOFACE_ANDROID_KEYPASS
npm run android:base
```

也可在被 Git 忽略的 `.sdk-cache/android-debug/signing.json` 保存 `{ "file": "/本机路径/demo.jks", "alias": "别名", "password": "密码" }`；已有 `helloface-demo.jks` 配置可继续使用。签名参数不打印到终端，完整云端日志保存在仅当前用户可读的 `unpackage/debug/cloud-build.log`。

手工在 HBuilderX 制作基座时，先执行 `npm run android:prepare`，再打包。它更新生成的 `HelloFaceVerifyBuildInfo.kt`。由 `android:base` 制作的产物还会生成 `base-build.json`，绑定 APK、原生源码和宿主配置。

基座检查包含：AppID、包名、HBuilderX 运行时版本、API/ABI、原生相机入口、模型不压缩、16KB ELF/RELRO/ZIP 对齐，以及原生源码指纹。检查失败时停止，不退回标准基座。

Android 图标配置和实际 PNG 内容也参与宿主指纹；更换图标后需重制基座。`android:dev` 会监听示例的 Android 图标资源，不会将新图标当成可热更新的页面资源。

## 资源同步如何实现

1. HBuilderX 的 `publish app-android --type appResource` 导出当前页面资源，核对 AppID 和必需文件。
2. Python 把普通文件打成 ZIP，拒绝符号链接，并限制解压后总大小为 32 MB。
3. 通过 `adb shell -T run-as 包名 tee` 把 ZIP 写进 App 的私有 `files/helloface-debug` 目录。不会用 ADB 在外部资源目录中新建页面目录。
4. 向 `HelloFaceVerifyDebugReceiver` 发送显式有序广播。接收器要求发送方持有 Android 的 [DUMP 权限](https://developer.android.com/reference/android/Manifest.permission#DUMP)，并检查宿主的 `FLAG_DEBUGGABLE`。正式包返回 `NOT_DEBUGGABLE`。
5. App 进程校验请求、ZIP SHA-256、打包时的 AppID、原生指纹、条目数量和解压大小，拒绝路径越界及重复条目。整个操作与人脸任务共用操作锁，录入/验证进行中返回 `BUSY`。
6. App 以自身 UID 创建暂存资源，验证后把旧 `www` 保留为备份，再启用新目录。替换失败则恢复旧目录；校验失败不修改当前页面。接收器回传请求号、资源哈希和文件数，脚本核对回执后重启示例。

接收器通过 [goAsync](https://developer.android.com/reference/android/content/BroadcastReceiver#goAsync()) 在单线程队列执行文件工作，回到主线程释放操作锁并完成广播回执。

同步前脚本会把示例置于前台。实测 MIUI 的 Greezer 会暂缓发给缓存后台进程的广播，即使广播显式指定组件；前台同步可以稳定获得回执。若同步期间切到其他 App 导致接收器无响应，请返回示例后重试。

这解决了 Android 11+ 上 shell 创建的外部目录无法被 App 读取的问题。遗留 shell 缓存及混合归属的旧页面备份，仅在归属和 AppID 符合已知情况时移到备份目录；遇到其他 AppID、非页面业务目录或未知归属时停止迁移。

调试收件 ZIP 在完成后删除；页面目录保留上一版备份。`last-run.json` 记录本次设备、页大小、APK/资源哈希和原生指纹，不保存人脸标识、特征、图像或分数。

## 原生改动如何被发现

原生指纹覆盖 `utssdk/app-android` 下的源码、配置、清单和 AAR，以及 `utssdk` 根目录的全部共享 UTS 文件（类型、参数校验、错误定义、返回码与短提示）。新增共享文件会自动参与校验。生成的指纹文件自身不参与计算，避免循环依赖。页面、样式和文档不参与该指纹。

指纹编译进 APK 的 DEX，并由调试接收器回传。运行前分别核对当前源码、本地 APK 和手机基座。由脚本制作的基座还会校验宿主 Android 配置；构建过程中原生源码或宿主配置变化时不登记构建成功。

## 日志与排错

调试包的 `HelloFaceVerify` 日志只记录操作随机追踪号、方法、开始/结束、错误码、业务结果枚举和耗时。不记录 `faceID`、特征、照片、分数或完整调用参数，也不逐帧刷屏。正式包关闭这些日志。

`android:logs` 在主机上按当前 App PID 过滤，兼容旧版 logcat；持续模式会跟随 App 重启。默认收集插件日志和当前进程的 `AndroidRuntime` 错误，输出中再次遮盖 HF1 特征。应用已退出时请结合 HBuilderX 的原生日志排查；`android:run` 会检查启动进程及常见的页面读取失败。

| 提示 | 处理 |
| --- | --- |
| 原生代码与基座不匹配 | 执行 `android:base`；仅同步页面不能更新原生二进制 |
| 宿主原生配置改变 | 用新配置重建基座 |
| `NOT_DEBUGGABLE` | 安装自定义调试基座，正式 APK 不提供资源更新入口 |
| `BUSY` | 先结束人脸操作并返回示例页 |
| `SYNC_FAILED` | 查看提示中的校验阶段；旧页面保持可用 |
| 手机拒绝安装 | 开启 USB 安装并允许本次安装；脚本不重复触发安装 |
| 包名相同但签名不同 | 使用此前的调试证书重建 |

Android 16KB 的静态检查与真实 16KB 环境运行是不同的验证项，设备实测范围见 [验证记录](VALIDATION.md)。
