# HelloFace 离线人脸识别与活体检测 UTS 插件

为你的 **uni-app / uni-app x** 应用接入**离线人脸识别、1:1 人脸比对、静默活体与动作活体检测**，支持人脸录入和特征同步。一套 UTS API 面向 Android、iOS、鸿蒙，适配 Vue2、Vue3、uvue。

无需自建人脸识别服务，也无需从零编写相机页面。适合账号本人确认、签到核验、设备端人员验证等流程的技术评估。

**集成到应用后一个CPU架构仅新增10MB左右体积(Android可以配置仅支持ARM64位CPU)**

## 你可以实现什么

| 需求 | 插件提供的能力 |
| --- | --- |
| 先录入，再确认是否本人 | 原生相机采集、预览确认、按 `faceID` 保存和比对 |
| 按业务选择验证方式 | 仅比对、静默活体、动作活体、静默 + 动作四种组合 |
| 只检测真人，不确认身份 | 独立活体检测，无需先录入或准备人脸基准 |
| 复用已有的人脸资料 | 图片导入、同模型特征同步，成功后无需重新拍摄录入 |
| 管理账号的人脸基准 | 状态查询、特征读取、覆盖与删除 |

**自带录入确认和动作引导界面。** 三端动作验证均显示剩余秒数及圆环倒计时。 动作支持眨眼、张嘴、摇头、点头，可按顺序组合，最多 4 步，允许重复。人脸比对与活体检测在设备端完成，不调用云端人脸识别 API。

[下载示例工程](https://github.com/FaceAISDK/HelloFace_uniapp)，体验录入、四种验证组合、独立活体、图片/特征同步和删除；示例默认使用同一个 `demo-user`。

## 接入

### 1. 导入插件

在 HBuilderX 中将完整插件导入 `uni_modules/HelloFace-Verify`，配置自己的 AppID、包名和签名。使用示例 ZIP 时，请同时导入包含目标平台 SDK 的完整插件。集成和运行 Demo 无需安装 Python。

### 2. 配置并运行到真机

Android 在 `manifest.json` 合并以下配置：uni-app 放在 `app-plus → distribute → android`，uni-app x 放在 `app-android → distribute`。
"armeabi-v7a" 是32位CPU，可以去除

```json
{
  "minSdkVersion": 23,
  "aaptOptions": ["noCompress 'bphfm'"],
  "abiFilters": ["arm64-v8a", "armeabi-v7a"]
}
```

首次运行必须把插件及真实 SDK 纳入原生运行产物。Android / iOS 可选择云端制作自定义基座，也可配置本地原生工程构建；鸿蒙使用本机 DevEco 工具链。**不强制在线制作自定义基座**，完整步骤见 [打包指南](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/BUILDING.md)。

### 3. 调用录入和验证

无需额外初始化。以下两个函数分别绑定业务页面的录入、验证按钮：

```js
import { enrollFace, verifyFace, cancel } from '@/uni_modules/HelloFace-Verify'

const faceID = 'demo-user' // 替换为业务账号标识

function enroll() {
  enrollFace({
    faceID,
    success: res => uni.showToast({ title: res.msg, icon: 'none' }),
    fail: err => uni.showToast({ title: err.msg, icon: 'none' })
  })
}

function verify() {
  verifyFace({
    faceID,
    success: res => {
      if (res.passed === true) { /* 验证通过，继续业务 */ }
      else uni.showToast({ title: res.msg, icon: 'none' })
    },
    fail: err => uni.showToast({ title: err.msg, icon: 'none' }),
    complete: (_) => { /* 关闭 loading，恢复按钮 */ }
  })
}

// 页面 onUnload 中调用 cancel()。
```

同一账号使用同一个 `faceID`。录入经用户确认后保存；默认不覆盖，更新时传 `overwrite: true`。验证默认前置相机、阈值 `0.80`、静默活体开启。

接口通过回调返回结果，不能直接 `await`。**是否通过以 `passed === true` 为准**，识别未通过仍会进入 `success`。页面应防重复点击、在 `complete` 收尾，离页时取消相机任务；删除基准前由业务确认。

## 活体如何组合

在 `verifyFace` 中配置两个独立选项：

| `silentLiveness` | `actions` | 本次验证 |
| --- | --- | --- |
| `false` | `[]` | 仅 1:1 比对 |
| `true` | `[]` | 比对 + 静默活体（默认） |
| `false` | `['blink', 'nodHead']` | 比对 + 动作活体 |
| `true` | `['blink', 'nodHead']` | 比对 + 静默活体 + 动作活体 |

动作参数：眨眼 `blink`、张嘴 `openMouth`、摇头 `shakeHead`、点头 `nodHead`。每步默认超时 3 秒，可通过 `actionTimeoutMs` 设置为 2000–30000 毫秒。

Demo 开启动作后可勾选上述四项，默认眨眼、点头，至少选择一个；身份验证和独立活体各自保留选择，按列表顺序执行。

只验真人时使用 `detectLiveness`：

```js
import { detectLiveness } from '@/uni_modules/HelloFace-Verify'

detectLiveness({
  actions: ['blink', 'nodHead'], // 省略或传 [] 时仅做静默活体
  success: res => {
    if (res.passed === true) { /* 活体通过，不代表身份匹配 */ }
  },
  fail: err => uni.showToast({ title: err.msg, icon: 'none' })
})
```

独立活体无需 `faceID` 或人脸基准，始终包含静默活体，不提供 `silentLiveness` 开关。

## API 一览

| API | 用途 |
| --- | --- |
| `enrollFace(options)` | 相机录入，确认后保存 |
| `verifyFace(options)` | 1:1 比对，可组合活体 |
| `detectLiveness(options)` | 独立活体，不比对身份 |
| `extractFaceFeature(options)` | 从图片提取特征，不保存 |
| `getFaceStatue(options)` | 查询基准是否存在，返回 `exists` |
| `getFaceFeature(options)` | 读取完整基准特征 |
| `setFaceFeature(options)` | 保存同特征空间的基准 |
| `syncFaceImage(options)` | 从外部图片提取并保存基准 |
| `syncFaceFeature(options)` | 保存外部下发的基准特征 |
| `deleteFace(options)` | 删除本机基准 |
| `cancel(options)` | 取消当前相机任务 |

已有照片可调用 `syncFaceImage({ faceID, imageBase64 })`；已有同模型特征可调用 `syncFaceFeature({ faceID, feature, featureSpaceID })`。成功后直接按 `faceID` 验证，更新已有基准时显式传 `overwrite: true`。

特征与 `featureSpaceID` 须成对传递，不能混用其他模型。同步、图片提取或基准存在均不代表身份、活体通过。完整参数、图片限制、回调类型与返回码见 [API 参考](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/API.md)。

## 兼容环境

| 项目 | 要求 |
| --- | --- |
| HBuilderX | 5.34+，安装对应 UTS 原生运行扩展 |
| 前端 | uni-app Vue2 / Vue3、uni-app x uvue |
| Android | Android 6.0 / API 23+，ARM64 / ARMv7 |
| iOS | iOS 15+；本地构建需兼容 Swift 6.1.2 的 Xcode（16.3+） |
| HarmonyOS | API 20+，ARM64，DevEco Studio 26 |

人脸采集需真机摄像头，Web、小程序不支持。iOS 尚未完成真实 SDK 完整编译和真机验证，各平台实际结果见 [验证记录](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/VALIDATION.md)。当前插件 0.2.0，底层 SDK 0.8.11 Beta。

## 常见问题

**运行 Demo 必须安装 Python 吗？**

不需要。集成方导入包含 SDK 的完整插件，在 HBuilderX 中构建运行即可。Python 仅用于本仓库的开发维护脚本。

**必须在线制作自定义基座吗？**

不必须。本插件含第三方 SDK，Android / iOS 常规真机调试需先制作包含依赖的自定义基座，也可配置完整本地原生工程构建；鸿蒙走本地构建。已有匹配的原生运行产物后，普通 UTS / Kotlin / Swift / ArkTS 源码可按 [DCloud 原生混编流程](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-plugin-hybrid.html)本地联编调试。更换 SDK、依赖、权限或资源后需重建，仅刷新页面不够。

**未录入就验证，或重复调用怎么办？**

未准备基准时提示“请先录入”，可先相机录入或同步已有基准；操作进行中返回 104，应等 `complete` 后再调用。常见提示直接展示 `msg`，业务按 `code` 分支。

更多操作见 [Android 调试](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/ANDROID_DEBUG.md)、[鸿蒙调试](https://github.com/FaceAISDK/HelloFace_uniapp/blob/main/docs/HARMONY_DEBUG.md)。反馈问题请到 [GitHub Issues](https://github.com/FaceAISDK/HelloFace_uniapp/issues)，附 HBuilderX 版本、机型、系统版本、复现步骤和日志，避免提交原始人脸特征。

## 体验与联系

- 🌍 **网站说明**：[HelloFace SDK](https://helloface.dev/)
- 📧 **EMAIL**：[FaceAISDK.Service@gmail.com](mailto:FaceAISDK.Service@gmail.com)
- 📱 **APK 下载**：[下载体验 APK](https://www.pgyer.com/HelloFace)
