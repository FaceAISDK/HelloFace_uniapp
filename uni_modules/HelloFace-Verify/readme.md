# HelloFaceVerify · 离线人脸识别、1:1 人脸比对与活体检测 UTS 插件

**HelloFaceVerify** 是适用于 **uni-app / uni-app x** 的离线人脸识别 UTS 插件，专注**人脸录入、1:1 人脸比对、静默活体检测和动作活体检测**。使用同一 `faceID` 完成“先录入，再验证是否本人”的流程，便于评估 App 登录确认、签到核验与设备端人员验证等场景。

支持 **Android、iOS、HarmonyOS 鸿蒙**原生相机采集，适配 **Vue2、Vue3、uvue**，三端使用统一 UTS API。人脸识别在设备端离线完成，无需调用云端人脸识别 API；用户确认录入后，基准特征加密保存在本机，支持读取、同步、覆盖和删除。

插件 ID：`HelloFace-Verify`；作者前缀：`HelloFace`；展示名称：`HelloFaceVerify`。

## 核心功能

| 能力 | 使用方式 |
| --- | --- |
| 人脸采集与录入 | 打开原生相机，自动采集后在小图确认弹窗展示预览，用户确认后保存 |
| 1:1 人脸识别 / 人脸比对 | 按指定 `faceID` 读取基准，验证当前人脸是否匹配 |
| 静默活体检测 | 验证时默认开启，由原生 SDK 给出活体结论 |
| 动作活体检测 | 支持眨眼、张嘴、摇头、点头，最多 4 个动作，可重复 |
| 人脸特征管理 | 支持特征读取、同步、覆盖和删除 |
| 原生相机流程 | 支持前后置相机、实时提示、权限处理、取消与后台释放 |

Android 使用 CameraX，iOS 使用 AVFoundation，鸿蒙使用 CameraKit。相机帧在原生层处理，前端接收进度与业务结果。基准特征分别由 Android Keystore、iOS Keychain、鸿蒙 HUKS 保护；插件不主动上传人脸图片或特征，也不把采集图保存到相册或文件。

进入录入、静默验证或动作验证的原生相机页时，插件自动把亮度调到最亮，录入确认和重新采集期间保持；完成、取消、报错、离页或进入后台时恢复进入时的亮度。Android/鸿蒙保存并恢复窗口亮度策略（包括跟随系统），iOS 保存并恢复所在屏幕的亮度。无需额外权限或 Demo 调用代码；没有相机页面的基准读写、同步和删除不调整亮度。

## 平台与环境

| 项目 | 要求 |
| --- | --- |
| 开发工具 | HBuilderX 5.34+，安装对应的 UTS 原生运行扩展 |
| uni-app | Vue2、Vue3 |
| uni-app x | uvue 页面 |
| Android | Android 6.0 / API 23+，ARM64 / ARMv7 |
| iOS | iOS 15+，ARM64 真机；原生 SDK 需要兼容 Swift 6.1.2 的 Xcode（16.3+） |
| HarmonyOS 鸿蒙 | API 20+，ARM64，DevEco Studio 26 工具链 |

相机流程需要真机。完整基座与前端联合运行的验收状态见文末验证说明。

## 接入步骤

1. 将包含原生依赖的完整 `HelloFace-Verify` 插件放入工程的 `uni_modules`。
2. 配置宿主 AppID、包名和签名，以及下面的 Android 模型打包选项。
3. Android / iOS 选择云端制作自定义基座，或通过本地原生工程集成 SDK 与 UTS 插件后构建；鸿蒙在本机用 DevEco 工具链运行。用于调试的原生产物需包含本插件全部依赖。
4. 从 `@/uni_modules/HelloFace-Verify` 导入 API，先录入用户，再按同一 `faceID` 验证。

**从 GitHub 获取源码时**，先在工程根目录运行：

```sh
python3 scripts/install_sdk.py
python3 scripts/install_sdk.py --check
```

安装器按固定版本及 SHA-256 校验 AAR、xcframework、HAR 和模型文件。安装完成后再复制插件；仓库不重复提交这些大型二进制文件。uvue 示例可通过 `python3 scripts/prepare_example.py` 准备。

Android 宿主的 `manifest.json` 必须合并：

```json
{
  "minSdkVersion": 23,
  "aaptOptions": ["noCompress 'bphfm'"],
  "abiFilters": ["arm64-v8a", "armeabi-v7a"]
}
```

uni-app 放在 `app-plus -> distribute -> android`；uni-app x 放在 `app-android -> distribute`。修改后需按所选方式重新构建原生产物。本地原生打包同样需要保留模型文件不压缩；iOS 的两个 xcframework 必须一同集成。

源码版插件的三端构建均不要求自建云服务器。Android、iOS 可选本地或云端路径；鸿蒙按官方流程使用本地构建。详细步骤及环境要求见 [三端打包指南](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/BUILDING.md)。

## 人脸录入

```js
import { enrollFace } from '@/uni_modules/HelloFace-Verify'

enrollFace({
  faceID: 'user-001',
  success: result => {
    if (result.passed === true) {
      // 用户已在原生界面确认，基准特征已加密保存在本机。
    }
  },
  fail: error => { /* 处理取消、权限拒绝或技术错误 */ },
  complete: result => { /* 结束业务页面的 loading */ }
})
```

`faceID` 为 1–64 个 UTF-16 单元，去除两端空白，不接受 NUL。重复录入默认保留已有特征；确认需要覆盖时传 `overwrite: true`。确认弹窗使用最大 188×188 的逻辑尺寸显示 SDK 对齐图，保留完整比例，不再铺满采集圆框。三端统一标题、遮罩、图片及按钮尺寸；标题和操作栏固定，小屏中间内容可滚动。可重新采集或点右上角取消；缺图禁止确认，保存期间禁用操作，确认之前退出不会保存。录入时稳定圆环约 0.7 秒，动画本身不触发采集或成功。

当前 SDK 0.8.11 在单人、大小和正脸稳定性满足要求后，等待约 700 毫秒再采集；检测与特征提取也需要时间，因此不是打开相机后固定 1 秒完成。鸿蒙和 iOS 录入页在 `HOLD_STILL` 阶段显示稳定等待圆环，偏头、晃动或丢失人脸时重置；圆环走满后仍等待 SDK 的实际结果，再展示照片供用户确认。iOS 的功能对照、静态检查及待真机项目见 [iOS 功能与调试](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/IOS_DEBUG.md)。

## 1:1 人脸识别与活体检测

```js
import { verifyFace, cancel } from '@/uni_modules/HelloFace-Verify'

verifyFace({
  faceID: 'user-001',
  success: result => {
    if (result.passed === true) {
      // 1:1 验证通过，继续业务流程。
    } else {
      // 根据 code 处理未通过，直接用 msg 提示。
    }
  },
  fail: error => { /* code / msg；排查时看 sdkCode / detail */ },
  complete: (_) => { /* 仅收尾；业务字段在 success/fail 中读取 */ }
})

// 页面 onUnload 中调用：cancel()
```

默认使用前置相机、阈值 `0.80` 和静默活体；业务只传需要变化的参数。启用动作活体时增加 `actions: ['blink', 'nodHead']` 即可。原生页面已提供采集/动作引导，业务页面无需重复实现相机、权限申请或 SDK 初始化；需要额外的业务进度展示时再提供 `onProgress`。

Demo 的每个按钮直接调用对应 API，`success / fail / complete` 复用页面的结果展示和收尾方法；这些方法只维护页面状态。复制到自己的项目时保留重复点击拦截、删除确认、错误反馈和 `onUnload` 中的取消。内部结构与维护边界见 [代码结构说明](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/CODE_STRUCTURE.md)，鸿蒙签名、断点和日志见 [鸿蒙调试说明](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/HARMONY_DEBUG.md)。

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `threshold` | `0.80` | 比对阈值，范围 0–1 |
| `silentLiveness` | `true` | 是否开启静默活体校验 |
| `actions` | `[]` | `blink`、`openMouth`、`shakeHead`、`nodHead`，最多 4 个 |
| `actionTimeoutMs` | `10000` | 每步动作超时，2000–30000 毫秒整数 |
| `faceTimeoutMs` | `15000` | 等待人脸超时，1000–60000 毫秒整数 |
| `camera` | `front` | `front` 前置，`back` 后置 |
| `referenceFeature` | 不传 | 可选的完整 HF1 基准，仅用于本次验证；必须同时传入 featureSpaceID |
| `featureSpaceID` | 不传 | 与 referenceFeature 成对传入，使用录入/读取返回的原值 |

所有 API 使用 `success / fail / complete`；录入和识别还可监听 `onProgress`。`success` 表示业务流程已完成，应以 `passed` 判断是否通过。例如 `outcome: 'SPOOF_DETECTED'` 会返回 `passed: false`，前端不能仅依据相似度放行。三端返回字段一致：相似度、活体分数仅在验证时返回实际有限值，其他接口或未产生时为 `null`；特征管理、取消的 `passed / outcome` 为 `null`。

结果和错误统一提供 `code + msg`：提示直接显示 msg，业务按 code 分支，原有字段保留。

| code | 分类 | 常见短提示 |
| --- | --- | --- |
| 0 | 成功 | 录入成功、验证通过、保存成功 |
| 101–109 | 操作问题 | 参数错误、相机未授权、已取消、操作中、请先录入、已录入、图片无效、图片无人脸、人脸过小 |
| 201–207、299 | 识别未通过 | 人脸不匹配、活体未通过、未检测到人脸、动作超时 |
| 301–308 | 运行异常 | 相机异常、存储异常、SDK未就绪、返回异常、模型异常 |

`2xx` 仍在 success 回调返回 `passed: false`，不改变 SDK 判定。完整代码表见 [返回码](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/API.md#返回码)。

uvue 可从同一入口导入 `EnrollFaceOptions`、`VerifyFaceOptions`、`FaceResult`、`FaceProgress` 类型。完整示例位于 [uvue 示例工程](https://github.com/FaceAISDK/HelloFace_uniapp/tree/main/examples/uni-app-x)。

## API 与特征同步

| API | 功能 |
| --- | --- |
| `enrollFace(options)` | 相机录入并在用户确认后保存 |
| `verifyFace(options)` | 对指定用户进行 1:1 验证 |
| `getFaceFeature(options)` | 读取该用户完整特征 |
| `syncFaceImage(options)` | 外部 PNG/JPEG Base64 → SDK 提取 → 保存基准 |
| `syncFaceFeature(options)` | 保存服务器/其他设备下发的同模型 HF1 特征 |
| `setFaceFeature(options)` | 导入相同特征空间的特征 |
| `deleteFace(options)` | 删除本机基准特征 |
| `cancel(options)` | 取消当前相机任务 |

特征管理以 `faceID` 为键。当前特征格式为 604 字符的 HF1，特征空间为 `jdx-feature-v1`。同步时需同时保留 `feature` 和 `featureSpaceID`；旧插件的不同格式不能直接导入。跨设备传输、服务端保存与账号授权由业务系统接入。

无需本机重新录入：`syncFaceImage({ faceID, imageBase64 })` 或 `syncFaceFeature({ faceID, feature, featureSpaceID })`，成功后直接 `verifyFace({ faceID })`。默认不覆盖，更新时显式传 `overwrite: true`。图片限 PNG/JPEG、6 MiB、每边 2..4096 px、总像素 4194304，支持 EXIF；需清晰单人脸且人脸宽高至少 100 px，SDK 选最大脸。图片接口采用三端通用 `extractFeature`，无相机/活体；成功只代表同步，`passed` 为 null。详见 [同步参数与示例](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/API.md#syncfaceimage--syncfacefeature)。

接口返回 `void`，使用回调，不直接 `await verifyFace(...)`。普通验证只需传 `faceID`；需要动作活体时传 `actions: ['blink', 'nodHead']`，默认静默活体继续开启。两个超时参数仅属于验证流程，不是接口总时长；录入须用户确认保存。

业务如已取得同模型基准，可跳过本机同步：

```js
verifyFace({
  faceID: 'user-001',
  referenceFeature: savedFeature,
  featureSpaceID: savedSpaceID,
  success: (res) => { /* 只在 res.passed === true 时放行 */ },
  fail: (err) => { /* err.code / err.msg / err.faceID */ }
})
```

直接传入的基准只用于本次验证，不使用、覆盖或保存本机基准。希望下次只传 faceID 时，显式调用 setFaceFeature 同步。

每次调用只终结一次，success/fail 后执行 complete。cancel 会等待相机释放后再 success，此时可开始新任务；原任务走 fail(CANCELLED)。无相机任务也成功，保存提交中返回 BUSY。不要取消其他业务页面拥有的任务。

完整参数、结果、同步方式、错误处理和三端边界见 [接入与 API](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/API.md)。

错误仍遵循 UniError，主题为 `HelloFaceVerify`。旧版 `errCode: 9011001–9011008` 保持兼容；新接入优先使用 code/msg，排查使用 sdkCode/detail。`errMsg` 保留 `方法名:fail 短提示` 格式，`faceID` 关联此次用户。

## 版本与验证说明

当前插件版本 **0.1.5**，底层为 HelloFace 原生 SDK **0.8.11 Beta**。Android 两套 UTS/Kotlin 编译及新基座校验通过，鸿蒙完整签名示例已在 API 26 真机运行并以新 SDK 实际提取 Demo 图片特征。iOS 完成语法、状态与平台类型检查，真实 SDK 完整编译仍受本机 Xcode 版本限制；详细真机边界见 [验证记录](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/VALIDATION.md)。

从 `HelloFace` 或 `HelloFaceVerify` 目录升级时，改为 `HelloFace-Verify` 并更新导入入口，重新构建包含本插件的原生基座。当前错误主题为 `HelloFaceVerify`，原有接口方法、参数与本机特征存储键延续使用。

The wrapper and example code are provided for technical exchange and evaluation purposes only. See [license.md](license.md). The native SDK and models remain subject to the upstream `Hello Face Test Only` terms. Upstream currently states that its models are not intended for children under 12 or financial use.

更多配置与参数见 [GitHub 工程说明](https://github.com/FaceAISDK/HelloFace_uniapp#readme)。
