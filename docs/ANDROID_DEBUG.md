# Android 调试与实现

根目录 Vue2/Vue3 示例提供“编译页面 → 应用内同步 → 重启示例”的调试通道。只修改页面时复用已安装基座；修改 Android 原生源码、UTS 接口或 SDK 二进制后重建基座。uvue 继续使用 HBuilderX 的原生编译通道。

## 接口改动后的本地编译检查

```sh
npm run android:uts-check                     # uni-app 的 UTS 桥接 + Kotlin
npm run android:uts-check -- --uni-app-x       # uni-app x 的 UTS 桥接 + Kotlin
```

这两项使用已安装的 HBuilderX Android UTS 扩展实际生成并编译插件，补充 `uts:check` 的三端源码转换检查。不打包、不签名、不安装 App，也不需要云端 AppID 权限；仍不能代替完整基座与真机验证。

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

原生指纹覆盖 `utssdk/app-android` 下的源码、配置、清单和 AAR，以及共享 UTS 类型、参数校验和错误定义。生成的指纹文件自身不参与计算，避免循环依赖。页面、样式和文档不参与该指纹。

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
