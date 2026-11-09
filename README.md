# HelloFace uni-app UTS 插件

基于 [FaceSDKPro/HelloFace](https://github.com/FaceSDKPro/HelloFace) 原生 SDK 0.8.8，实现离线 **1:1 人脸录入**和 **1:1 人脸识别**。使用 UTS API 插件与原生混编，供 Vue2、Vue3 和 uni-app x 的 uvue 页面调用。

录入流程：打开原生相机 → 采集人脸 → 显示采集预览 → 用户确认 → 保存此 `faceID` 的基准特征。识别流程：读取此 `faceID` 的特征 → 原生相机连续送帧 → 可选静默/动作活体 → 1:1 比对 → 返回 SDK 业务结果。

## 环境

| 项目 | 要求 |
| --- | --- |
| HBuilderX | 5.34+，安装对应的 UTS 原生运行扩展 |
| Android | Android 6.0 / API 23+，ARM64 / ARMv7，原生验证使用 JDK 17 |
| iOS | iOS 15+，ARM64 真机；原生 SDK 使用 Swift 6.1.2 构建，本地编译需兼容的 Xcode（16.3+） |
| 鸿蒙 | HarmonyOS API 20+，ARM64；与上游一致使用 DevEco Studio 26 工具链 |
| 前端 | uni-app Vue2 / Vue3；uni-app x uvue |

相机功能需要真机。Web、小程序不在插件支持范围内。当前验证状态见 [docs/VALIDATION.md](docs/VALIDATION.md)。

## 安装与运行

1. 克隆本仓库后，在工程根目录安装原生 SDK 文件：

   ```sh
   python3 scripts/install_sdk.py
   python3 scripts/install_sdk.py --check
   ```

   需要 Python 3.9+、curl 和网络。也可通过 `--platform android`、`--platform ios`、`--platform harmony` 仅安装单个平台。`--source /path/to/HelloFace` 可复用本机上游源码中的完整 SDK 文件；LFS 指针会自动下载对应文件。

   SDK 版本、上游提交和每个文件的 SHA-256/长度锁定在 `sdk-artifacts.json`。安装器先验证临时文件再替换目标，避免把 Git LFS 指针当成原生库。大型二进制和模型通过安装器获取，不重复纳入工程 Git 历史。

2. 在 HBuilderX 导入工程根目录，修改 `manifest.json` 中的示例 AppID、包名和签名为自己的配置。根目录默认为 Vue3；使用 Vue2 时把 `vueVersion` 改为 `"2"`，`main.js` 已包含两种启动分支。

3. Android / iOS 制作包含本插件与原生 SDK 的自定义调试基座，再在真机运行。Android 的 `manifest.json` 已配置 `noCompress 'bphfm'`，确保模型可被原生 SDK 映射读取；更改该项需要重新制作基座。鸿蒙端安装 HAR 后使用 HBuilderX 的鸿蒙运行流程。

4. 运行 uvue 示例：

   ```sh
   python3 scripts/prepare_example.py
   ```

   在 HBuilderX 中单独导入 `examples/uni-app-x`，配置自己的 AppID/签名后运行。该命令把根目录的插件与已安装的原生依赖复制到示例中，避免维护两份插件源码；修改插件后再次执行。

集成到已有工程时，复制**安装完成后的** `uni_modules/HelloFace`。Android 宿主还需合并下面的模型打包配置：

```json
// uni-app：manifest.json -> app-plus -> distribute -> android
{ "minSdkVersion": 23, "aaptOptions": ["noCompress 'bphfm'"], "abiFilters": ["arm64-v8a", "armeabi-v7a"] }
// uni-app x 5.34：manifest.json -> app-android -> distribute
{ "minSdkVersion": 23, "aaptOptions": ["noCompress 'bphfm'"], "abiFilters": ["arm64-v8a", "armeabi-v7a"] }
```

离线原生打包时也要在宿主 Android 模块设置 `androidResources.noCompress += "bphfm"`。iOS 两个 xcframework 必须一同集成。相机用途描述和鸿蒙相机权限已放在插件对应平台的清单中。

## 最小调用

```js
import { enrollFace, verifyFace, cancel } from '@/uni_modules/HelloFace'

enrollFace({
  faceID: 'user-001',
  success: result => {
    if (result.passed === true) uni.showToast({ title: '录入成功' })
  },
  fail: error => uni.showModal({ content: error.errMsg, showCancel: false })
})

// 用户后续主动点击“识别”时调用。
verifyFace({
  faceID: 'user-001',
  threshold: 0.80,
  silentLiveness: true,
  actions: ['blink', 'nodHead'],
  onProgress: progress => { /* 更新业务页面的进度 */ },
  success: result => {
    if (result.passed === true) {
      // SDK 已完成活体与身份判断。
    } else {
      // 根据 result.outcome 处理非本人、活体拒绝或流程超时。
    }
  },
  fail: error => { /* 技术错误、取消、权限拒绝等 */ },
  complete: result => { /* 清理业务页面的 loading 状态 */ }
})

// 页面退出时：cancel({})
```

uvue 从同一插件入口导入 `EnrollFaceOptions`、`VerifyFaceOptions`、`FaceResult` 等类型，示例见 `examples/uni-app-x/pages/index/index.uvue`。按官方要求，通过 `@/uni_modules/HelloFace` 引用插件，页面不直接导入 `utssdk` 内部文件。

## API

所有接口接受一个 options 对象，包含可选的 `success`、`fail`、`complete` 回调。`success` / `fail` 为终态，`complete` 在终态后执行；`onProgress` 可被多次调用，不触发 `complete`。当前仅允许一个操作占用插件，避免录入、识别和特征修改互相覆盖。

| API | 参数 | 行为 |
| --- | --- | --- |
| `enrollFace` | `faceID`，可选 `overwrite`、`camera`、`onProgress` | 原生相机采集并在确认后保存 |
| `verifyFace` | `faceID`，可选参数见下表 | 对此用户执行原生 1:1 验证 |
| `getFaceFeature` | `faceID` | 读取完整 HF1 特征，供业务自主同步 |
| `setFaceFeature` | `faceID`、`feature`、`featureSpaceID`，可选 `overwrite` | 把相同特征空间的 HF1 特征保存到本机 |
| `deleteFace` | `faceID` | 删除本机基准特征；不存在时也成功 |
| `cancel` | 无业务参数 | 取消当前相机任务；没有相机任务时成功返回 |

`faceID` 会去除两端空白，长度为 1–64 个 UTF-16 单元，不接受 NUL。`overwrite` 默认 `false`，已有基准时返回 `9011006`；只有明确传入 `true` 才替换。`camera` 为 `front`（默认）或 `back`。`enrollFace` 始终显示原生确认按钮，确认之前不保存特征。

| verifyFace 可选参数 | 默认值 | 说明 |
| --- | --- | --- |
| `threshold` | `0.80` | 0–1；相似度不是身份概率 |
| `silentLiveness` | `true` | 是否执行 SDK 静默活体校验 |
| `actions` | `[]` | `blink` / `openMouth` / `shakeHead` / `nodHead`，最多 4 个，可重复 |
| `actionTimeoutMs` | `10000` | 整数，1000–60000 毫秒 |
| `faceTimeoutMs` | `15000` | 整数，1000–60000 毫秒 |
| `camera` | `front` | 前置或后置相机 |

多个脸同时进入画面默认拒绝。业务应以 `passed` / `outcome` 判断结果，插件不根据分数重新覆盖 SDK 的活体结论。没有产出的分数保持 `null`。

### 成功结果 FaceResult

```ts
{
  errMsg: string,
  faceID: string,
  feature: string | null,          // 录入、读取、同步时返回；识别时不返回探测特征
  featureSpaceID: string,          // 当前为 jdx-feature-v1
  passed: boolean | null,
  outcome: string | null,
  similarity: number | null,
  livenessScore: number | null
}
```

验证拒绝同样属于成功完成的一次业务流程：`success` 返回 `passed: false`。`outcome` 可能为 `PASSED`、`NOT_MATCHED`、`SPOOF_DETECTED`、`NO_FACE_TIMEOUT`、`FACE_LOST`、`MULTIPLE_FACES`、`ACTION_TIMEOUT`、`FINAL_CAPTURE_TIMEOUT`。特征管理接口的 `passed` / `outcome` 为 `null`。

`onProgress` 返回 `{ faceID, stage, action, stepNumber, stepCount }`。原生相机界面也会显示相应提示。

### 错误

`fail` 返回符合 UniError 约定的 `errSubject: "HelloFace"`、`errCode`、`errMsg`，另有 `sdkCode` 保留原始错误名称。

| errCode | 含义 |
| --- | --- |
| `9011001` | 参数错误或特征空间不兼容 |
| `9011002` | 相机权限拒绝 |
| `9011003` | 用户取消、页面关闭或相机进入后台 |
| `9011004` | 有任务进行中；或确认后的保存提交尚未结束 |
| `9011005` | 此用户尚未录入 |
| `9011006` | 已有基准且未允许覆盖 |
| `9011007` | 本地特征存储错误 |
| `9011008` | 其他 SDK / 相机 / 桥接错误，详见 `sdkCode` |

确认录入后开始的保存会完成提交；此时取消不会把已保存的数据伪装成“未录入”。任务退出后会取消 SDK 请求、停止送帧、释放相机及 SDK 实例。SDK 初始化期间的 `NOT_READY` 帧会被丢弃，不阻断流程。

## 特征与数据

基准特征使用 Android Keystore AES-GCM、iOS Keychain（仅本机且解锁后可访问）、鸿蒙 HUKS AES-GCM 保存。特征空间参与存储键，避免 SDK 换模型后混用旧基准。插件不把采集图落盘，也不自动上传或在日志中输出特征。

HF1 是 604 字符的特征编码，本身不是加密格式。`setFaceFeature` 必须同时提供 `featureSpaceID: "jdx-feature-v1"`。旧 FaceAISDK-Core 的特征格式不能直接导入本插件。需要跨设备同步时，由业务系统通过 `getFaceFeature` / `setFaceFeature` 自行处理用户授权、传输与存储。

## 开发与验证

```sh
node --test tests/api.test.cjs
python3 -m unittest discover -s tests -v
python3 scripts/install_sdk.py --check
```

API 测试使用 HBuilderX 自带 TypeScript（可设置 `HBUILDERX_PATH` 指向 `Contents/HBuilderX`），也可安装项目的开发依赖后运行 `npm test`。这些测试验证 UTS API 参数与回调契约，不模拟人脸识别成功。原生编译和待执行的真机用例记录在 [docs/VALIDATION.md](docs/VALIDATION.md)。

## 规范与许可

实现参考 DCloud 当前官方文档：[UTS API 插件](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-plugin.html)、[原生混编](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-plugin-hybrid.html)、[鸿蒙插件配置](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-for-harmony.html)、[UTSHarmony](https://doc.dcloud.net.cn/uni-app-x/uts/utsharmony.html)。参考插件 [FaceAISDK-Core](https://ext.dcloud.net.cn/plugin?name=FaceAISDK-Core) 的 1:1 使用场景，API 并非旧版本的兼容替代。

本仓库封装代码采用 MIT 许可。原生 SDK、模型和其资源继续使用上游许可（当前文件为 `Hello Face Test Only`），原文保留在插件的 `notices` 目录；上游说明当前模型不适用于 12 岁以下人群和金融场景。本仓库不改变原生 SDK 的授权条件。
