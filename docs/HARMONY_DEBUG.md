# 鸿蒙真机运行与调试

本工程的规范插件源码在 `uni_modules/HelloFace-Verify`。根目录是 Vue2/Vue3 示例；`examples/uni-app-x` 是独立 uvue 示例。鸿蒙使用 HBuilderX 调用本机 DevEco 工具链，不需要制作 Android 云端基座。

## 首次准备

1. 安装 HBuilderX 的鸿蒙运行扩展及 DevEco Studio，在 HBuilderX「设置 → 运行配置」中配置 DevEco 路径。本机为 `/Applications/DevEco-Studio.app`，HBuilderX 5.34。插件使用真实 SDK 0.8.11，要求 ARM64、API 20+；不能仅按 uni-app 框架更低的最低 API 配置宿主。

   两套示例已在 `manifest.json` 的 `app-harmony.distribute` 设置 `"compatibleSdkVersion": "6.0.0(20)"`，HBuilderX 会把它应用到生成工程的各个 product。API 20 对应 HarmonyOS 6.0.0，作为最低版本时不支持鸿蒙 5；较新系统满足最低版本条件，功能仍需真机验收。不要降低真实 SDK HAR 的最低版本声明，也不要只修改会被覆盖的 `unpackage` 文件。这个配置解决 `00306004` / `MergeProfile` 的 API 13 与 20 冲突；签名证书需另行配置。
2. 在手机开启开发者模式与 USB 调试，通过 USB 连接并在手机确认调试授权。以下命令应列出设备；本次为 Mate 60 Pro / ALN-AL80 / API 26。

   ```sh
   export PATH="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains:$PATH"
   hdc list targets
   hdc shell param get const.product.model
   hdc shell param get const.ohos.apiversion
   ```

3. 在工程根目录校验依赖：

   ```sh
   python3 scripts/install_sdk.py --check --platform harmony
   # 缺少依赖时安装，再重新校验：
   python3 scripts/install_sdk.py --platform harmony
   ```

4. 打开根目录工程，保留当前 AppID 和 `manifest.json` 的鸿蒙 Bundle Name `dev.helloface.uniapp.demo`。在「运行到鸿蒙」的设备选择窗口点「配置调试证书」，使用拥有该应用权限的华为开发者账号申请或导入证书。Profile 必须匹配此 Bundle Name，并包含当前手机的 UDID；`hdc shell bm get -u` 可以查询 UDID。复用本机已有签名身份时，也必须为本应用申请匹配的 Profile，不能使用其他包名的 Profile。不要提交私钥或签名密码。
5. 选择 debug 构建运行到真机。相机权限由插件 `module.json5` 和 `resources/base/element/string.json` 提供；首次录入时在手机处理权限弹窗。

本机已于 2026-11-11 完成上述配置：AGC 应用为 **HelloFaceVerify Demo**，Bundle Name 为 `dev.helloface.uniapp.demo`，调试 Profile 为 `HelloFaceVerifyUniappDebug20261111`。沿用已有开发证书和私钥，Profile 包含当前手机。HBuilderX 从本地 `harmony-configs/build-profile.json5` 读取签名配置；该文件已加入 `.gitignore`，仅在本机使用，不能上传或粘贴到日志。证书和 Profile 保存在用户的 `.ohos/config` 中，其他电脑仍需自行配置。DCloud AppID 与 AGC APP ID 各自保留，不能互相替代。

运行 uvue 时先执行 `npm run demo:prepare`，再单独导入 `examples/uni-app-x`，配置其自身有效 AppID 与签名。两个示例目前使用同一鸿蒙 Bundle Name；不要交替覆盖安装来比较结果。需要并存时应由应用所有者配置独立的 Bundle Name 及匹配的签名。

## 命令行入口

先在 HBuilderX 中完成工程导入和签名配置，再使用安装版本实际提供的 CLI：

```sh
/Applications/HBuilderX.app/Contents/MacOS/cli devices list --platform app-harmony
/Applications/HBuilderX.app/Contents/MacOS/cli launch app-harmony \
  --project /Users/zlb/uniapp/HelloFace_uniapp \
  --deviceId 29QGK24528000025 --buildType debug --native-log true
```

设备序列号应替换为 `hdc list targets` 的实际输出。只编译时使用 `--compile true`；正式本地打包使用 `cli pack app-harmony --project 工程绝对路径`。参数以 `cli launch app-harmony --help` 为准。CLI 停在版本信息或“正在编译”时，检查 HBuilderX 的设备/签名窗口及运行控制台；没有成功构建、签名和安装日志就不能认为已经运行成功。

## 断点与调用链

uvue / UTS / 混编 ArkTS：先以 debug 模式运行成功，在 HBuilderX 运行控制台点红色虫子，选择「开启调试」，按提示安装鸿蒙调试扩展。双击行号设置断点；初始化断点需要点旁边的「重启应用」。官方步骤见 [鸿蒙 UTS 调试](https://uniapp.dcloud.net.cn/tutorial/debug/uni-uts-debug-harmony.html)。

| 定位位置 | 观察内容 |
| --- | --- |
| `pages/index/index.vue` 或 uvue 页的 `enroll` / `verify` / `syncImage` | 业务 faceID、动作选项及回调；不要输出完整图片/特征 |
| `utssdk/app-harmony/index.uts` | 默认参数、校验失败、原生 invoke 的方法名 |
| `utssdk/shared.uts` 的 `createDispatcher` | 过程事件、终态去重、success/fail/complete、code/msg |
| `app-harmony/HelloFaceVerifyNative.ets` 的 `invoke` / `execute` | busy、generation、权限等待及取消隔离 |
| `app-harmony/HelloFaceVerifyCamera.ets` 的 `open` / `confirm` / `finish` / `shutdown` | SDK 结果、确认保存、相机释放及对话框收尾 |
| 同文件的 `result` → `image.createPixelMap` | 录入确认照片；SDK 的 `alignedRgba` 必须显式指定 `srcPixelFormat: RGBA_8888`，仅设置输出 `pixelFormat` 会红蓝互换 |
| 同文件 `FaceCameraDialog.updateCaptureProgress` / `resetCaptureProgress` | 录入稳定圆环；只在 `HOLD_STILL` 阶段按 700 毫秒显示提示，检查异常阶段和离页后的定时器清理；满圈不会触发录入成功 |
| 同文件 `CameraFlow.prepareScreen` / `restoreScreen` | 进入相机页的满亮和原值恢复；`screenTask` 串行处理快速取消，保留原来的 `-1` 跟随系统策略，可用 HiLog 的 `OnSetWindowBrightness` 核对数值和结果 |
| `app-harmony/ReferenceStore.ets` / `FaceImageImporter.ets` | HUKS 加密存储及外部图片提取错误 |

根 Vue 示例的 JS 业务层与原生 ArkTS 调试应按各自运行引擎处理；不要把 uvue 的断点能力直接等同于 Vue JS 的断点能力。Vue 前端页面及 JSVM 调试入口见 [uni-app 鸿蒙运行与调试](https://uniapp.dcloud.net.cn/tutorial/harmony/runbuild.html#调试的方式)。完整原生宿主生成后也可用 DevEco 打开 `unpackage/dist/dev/app-harmony`（uvue 以实际控制台输出路径为准），分析原生异常和资源泄漏。生成目录会被覆盖，修复应回写规范源码或宿主配置。

## 日志

```sh
hdc shell pidof dev.helloface.uniapp.demo
# 将下面 12345 替换为上一步当前进程的 PID：
hdc shell hilog -x -P 12345
hdc shell hilog -P 12345
```

第一条 HiLog 命令读取现有缓冲后退出，第二条持续读取，Ctrl+C 停止；App 重启后重新查询 PID。可在 DevEco 的 HiLog 中按应用进程和 Error/Fatal 级别过滤。只记录方法、返回码和时序；不要记录 HF1 特征、Base64 图片、原始相机帧或签名密码。

亮度回归可先查询当前 PID，再用 `hdc shell hilog -P 12345 -e OnSetWindowBrightness` 持续观察窗口日志：进入应设置为 `1`，退出应恢复原值（本机为 `-1`），返回结果应为 0。使用持续日志可避免调试缓冲被其他日志覆盖。设置与恢复由原生相机页管理，前端无需额外调用。窗口亮度含义见 [鸿蒙窗口 API](https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-apis-window-window/)。

## 修改后如何更新

| 修改内容 | 操作 |
| --- | --- |
| Vue 页面 | 通过 HBuilderX 的鸿蒙运行通道重新编译/刷新；不要使用 `android:dev` 或 ADB 同步 |
| uvue、UTS、原生 `.ets` | 用鸿蒙通道重新编译运行；是否可热更以该版本工具链提示为准 |
| HAR、权限、资源、Bundle Name、SDK 配置 | 完整重建、签名并更新安装；权限或包名变化时核对 Profile |
| 规范插件源码供 uvue 使用 | 先 `npm run demo:prepare`，再运行独立示例 |

安装失败时先核对签名及 Profile，不要靠卸载清数据解决。HBuilderX 官方说明存在安装失败后尝试卸载重装的情况；已有录入数据的设备应先保留数据并排查失败原因。

## 验收次序与本次限制

先验证缺少基准的返回，再验证相机授权、预览、取消、无人脸超时、重复调用、后台退出和恢复。真人录入确认、重启后的持久化、本人/他人验证和动作活体，需要操作者配合。`success` 只表示接口完成，只有 `passed === true` 才是验证通过。

2026-11-11 已完成匹配签名，当前 SDK 0.8.11 的完整根 Vue3 示例已在 Mate 60 Pro（系统 `OpenHarmony-7.0.0.111` / API 26）构建、安装和运行。本轮样式检查完成小图弹窗、重拍/关闭、缺图禁用、保存按钮及返回保护，并在正式示例复测授权、录入打开、取消和无基准处理。临时预览安装后原 `demo-user` 基准未保留，尚未恢复；本轮未新增真人保存、本人/他人比对、活体或无人脸超时验收。先前颜色、稳定圆环、本人静默和动作活体通过的历史记录保留于 [验证记录](VALIDATION.md)，不能当作本轮通过。没有 HarmonyOS 6 实机结果，也未验收独立 uvue 完整 App。

颜色排错依据：[ImageKit 初始化选项](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-image-i/) 中 `srcPixelFormat` 默认值为 BGRA，而 `pixelFormat` 是生成 PixelMap 的格式；两者含义不同。该输入格式选项自 API 12 提供，本修复不提高当前 API 20 的最低系统要求。

录入成功采集后，确认图在居中卡片中按最大 188vp 显示，保持比例，右上角可取消，底部可重拍/确认。`CapturePhoto` / `ConfirmationDialog` 的断点可检查 `alignedSide`、显示边长和保存禁用状态；图库大小属于 SDK 输出，显示区域大小由 `native-ui.json` 统一维护。

升级后若编译提示找不到 `@dcloudio/uni-app-runtime`、`@uni_modules/helloface-verify` 等，先检查生成工程的 `oh_modules` 是否存在。本次通过在 DevEco 终端的生成工程根目录执行 `ohpm install --all` 恢复依赖，再从 HBuilderX 正常重新运行解决；无需改 AppID、Bundle Name 或签名。不要在并行构建中清理其他运行通道正在使用的生成目录。

## 调试安装与用户数据

2026-11-11 样式复查中，同包名临时 UI 宿主安装后发现原 `demo-user` 基准未保留；当前偏好文件缺失、具体重置环节未确定，详情见 [验证记录](VALIDATION.md)。不要在已有真人基准的包名上安装临时 UI 宿主；界面预览应使用独立 Bundle 与沙箱。

完整示例更新前后要核对 Bundle、签名、安装时间、UID 和基准能否读取。[HDC 官方文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hdc/)说明 `hdc install -r` 表示覆盖安装，但安装命令成功本身不能证明用户数据保留；不要为了处理签名/安装错误直接卸载。基准使用 HUKS 不可导出密钥，单独复制密文不能保证卸载后可恢复。本轮没有用示例特征覆盖原真人标识。
