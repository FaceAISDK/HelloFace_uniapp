# HelloFaceVerify · 离线人脸识别与 1:1 人脸比对 UTS 插件

**HelloFaceVerify** 为 uni-app / uni-app x 提供**人脸采集、人脸录入、1:1 人脸识别和活体检测**。按 `faceID` 管理已录入用户，通过原生相机验证“当前操作人是否为该用户”，可作为 App 登录确认、签到核验、设备端人员验证中的人脸比对模块。

提供 **Android、iOS、HarmonyOS 鸿蒙**原生实现，前端使用统一 UTS API，适配 **Vue2、Vue3、uvue**。识别在设备端离线完成，无需调用云端人脸识别 API；录入确认后，基准特征加密保存在本机。

## 核心功能

| 能力 | 使用方式 |
| --- | --- |
| 人脸采集与录入 | 打开原生相机，自动采集并展示预览，用户确认后保存 |
| 1:1 人脸识别 / 人脸比对 | 按指定 `faceID` 读取基准，验证当前人脸是否匹配 |
| 静默活体检测 | 验证时默认开启，由原生 SDK 给出活体结论 |
| 动作活体检测 | 支持眨眼、张嘴、摇头、点头，最多 4 个动作，可重复 |
| 人脸特征管理 | 支持特征读取、同步、覆盖和删除 |
| 原生相机流程 | 支持前后置相机、实时提示、权限处理、取消与后台释放 |

Android 使用 CameraX，iOS 使用 AVFoundation，鸿蒙使用 CameraKit。相机帧在原生层处理，前端接收进度与业务结果。基准特征分别由 Android Keystore、iOS Keychain、鸿蒙 HUKS 保护；插件不主动上传人脸图片或特征，也不把采集图保存到相册或文件。

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

1. 将包含原生依赖的完整 `HelloFaceVerify` 插件放入工程的 `uni_modules`。
2. 配置宿主 AppID、包名和签名，以及下面的 Android 模型打包选项。
3. Android / iOS 选择云端制作自定义基座，或通过本地原生工程集成 SDK 与 UTS 插件后构建；鸿蒙在本机用 DevEco 工具链运行。用于调试的原生产物需包含本插件全部依赖。
4. 从 `@/uni_modules/HelloFaceVerify` 导入 API，先录入用户，再按同一 `faceID` 验证。

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
import { enrollFace } from '@/uni_modules/HelloFaceVerify'

enrollFace({
  faceID: 'user-001',
  camera: 'front',
  overwrite: false,
  success: result => {
    if (result.passed === true) {
      // 用户已在原生界面确认，基准特征已加密保存在本机。
    }
  },
  fail: error => { /* 处理取消、权限拒绝或技术错误 */ },
  complete: result => { /* 结束业务页面的 loading */ }
})
```

`faceID` 为 1–64 个 UTF-16 单元，去除两端空白，不接受 NUL。重复录入默认保留已有特征；确认需要覆盖时传 `overwrite: true`。确认之前退出不会保存。

## 1:1 人脸识别与活体检测

```js
import { verifyFace, cancel } from '@/uni_modules/HelloFaceVerify'

verifyFace({
  faceID: 'user-001',
  threshold: 0.80,
  silentLiveness: true,
  actions: ['blink', 'nodHead'],
  onProgress: progress => { /* 更新提示：stage、action、stepNumber、stepCount */ },
  success: result => {
    if (result.passed === true) {
      // 1:1 验证通过，继续业务流程。
    } else {
      // 根据 outcome 处理非本人、活体拒绝或超时。
    }
  },
  fail: error => { /* errCode、errMsg、sdkCode */ },
  complete: result => { /* 清理页面状态 */ }
})

// 页面 onUnload 中调用：cancel({})
```

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `threshold` | `0.80` | 比对阈值，范围 0–1 |
| `silentLiveness` | `true` | 是否开启静默活体校验 |
| `actions` | `[]` | `blink`、`openMouth`、`shakeHead`、`nodHead`，最多 4 个 |
| `actionTimeoutMs` | `10000` | 动作超时，1000–60000 毫秒整数 |
| `faceTimeoutMs` | `15000` | 等待人脸超时，1000–60000 毫秒整数 |
| `camera` | `front` | `front` 前置，`back` 后置 |

所有 API 使用 `success / fail / complete`；录入和识别还可监听 `onProgress`。`success` 表示业务流程已完成，应以 `passed` 判断是否通过。例如 `outcome: 'SPOOF_DETECTED'` 会返回 `passed: false`，前端不能仅依据相似度放行。未产生的相似度或活体分数返回 `null`。

uvue 可从同一入口导入 `EnrollFaceOptions`、`VerifyFaceOptions`、`FaceResult`、`FaceProgress` 类型。完整示例位于 [uvue 示例工程](https://github.com/FaceAISDK/HelloFace_uniapp/tree/main/examples/uni-app-x)。

## API 与特征同步

| API | 功能 |
| --- | --- |
| `enrollFace(options)` | 相机录入并在用户确认后保存 |
| `verifyFace(options)` | 对指定用户进行 1:1 验证 |
| `getFaceFeature(options)` | 读取该用户完整特征 |
| `setFaceFeature(options)` | 导入相同特征空间的特征 |
| `deleteFace(options)` | 删除本机基准特征 |
| `cancel(options)` | 取消当前相机任务 |

特征管理以 `faceID` 为键。当前特征格式为 604 字符的 HF1，特征空间为 `jdx-feature-v1`。同步时需同时保留 `feature` 和 `featureSpaceID`；旧插件的不同格式不能直接导入。跨设备传输、服务端保存与账号授权由业务系统接入。

错误遵循 UniError，主题为 `HelloFaceVerify`：`9011001` 参数错误、`9011002` 权限拒绝、`9011003` 取消、`9011004` 任务忙、`9011005` 尚未录入、`9011006` 已录入未允许覆盖、`9011007` 存储错误、`9011008` 其他原生错误；`sdkCode` 保留 SDK 错误名称。

## 版本与验证说明

当前插件版本 **0.1.1**，底层为 HelloFace 原生 SDK **0.8.8**。Android 原生 Kotlin 编译、鸿蒙原生 HAR 构建及三端 UTS 转换已通过；iOS 当前仅完成 Swift 语法检查，完整编译和三端真机联合运行仍需按 [验证记录](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/VALIDATION.md) 验收。

从早期 `HelloFace` 目录升级时，将导入入口改为 `@/uni_modules/HelloFaceVerify`，错误主题改为 `HelloFaceVerify`。原有方法名和参数一致，特征存储键延续使用。

封装代码采用 MIT 许可；原生 SDK 和模型保留上游 `Hello Face Test Only` 许可，原文位于 `notices`。上游当前说明模型不适用于 12 岁以下人群和金融场景。

更多配置与参数见 [GitHub 工程说明](https://github.com/FaceAISDK/HelloFace_uniapp#readme)。
