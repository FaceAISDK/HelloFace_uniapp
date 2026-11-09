# HelloFace

离线 1:1 人脸录入与识别 UTS 插件，基于 HelloFace 原生 SDK 0.8.8。

支持 Android API 23+、iOS 15+、HarmonyOS API 20+；供 uni-app Vue2/Vue3 与 uni-app x uvue 调用。需要 HBuilderX 5.34+。

```js
import { enrollFace, verifyFace, cancel } from '@/uni_modules/HelloFace'

enrollFace({ faceID: 'user-1', success: result => { /* 用户确认后保存 */ } })
// 之后由用户主动触发识别：
verifyFace({ faceID: 'user-1', silentLiveness: true, success: result => {
  if (result.passed === true) { /* 验证通过 */ }
} })
// 页面退出时 cancel({})
```

公开 API：`enrollFace`、`verifyFace`、`getFaceFeature`、`setFaceFeature`、`deleteFace`、`cancel`。均使用 options 与 `success / fail / complete`；录入与识别可监听 `onProgress`。录入始终需要用户确认，重复录入默认不覆盖。

从 GitHub 使用前，在工程根目录运行 `python3 scripts/install_sdk.py` 获取并校验三端原生依赖，再把完整插件复制到业务工程。Android 宿主必须配置 `aaptOptions: ["noCompress 'bphfm'"]` 并重建自定义基座。iOS 需兼容 Swift 6.1.2 SDK 的 Xcode。鸿蒙使用插件内的 HAR 依赖与相机权限。

完整参数、特征同步格式、运行步骤及当前验证记录见 [工程说明](https://github.com/FaceAISDK/HelloFace_uniapp#readme)。原生 SDK 的许可保留在 `notices` 目录。
