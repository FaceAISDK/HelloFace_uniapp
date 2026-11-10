# HelloFaceVerify 接入与 API

插件入口：`@/uni_modules/HelloFace-Verify`。六个接口在 Android、iOS、HarmonyOS 上使用相同参数和回调，兼容 uni-app Vue2/Vue3 与 uni-app x uvue。原生相机、权限申请、特征加密和 SDK 生命周期由插件处理，业务页面无需先初始化 SDK。

## 先选择基准来源

| 接入方式 | 录入/保存 | 验证时传参 | 是否使用本机基准 |
| --- | --- | --- | --- |
| 本机录入（默认） | `enrollFace({ faceID })`，用户确认保存 | `verifyFace({ faceID })` | 是 |
| 服务端下发，仅本次使用 | 业务取得同模型的 HF1 与特征空间 | `faceID` + `referenceFeature` + `featureSpaceID` | 否，不保存、不替换 |
| 同步后离线使用 | `setFaceFeature({ faceID, feature, featureSpaceID })` | 后续只传 `faceID` | 是 |

`faceID` 始终必填，是业务账号标识而非相机采集结果。直接传基准时它用于关联回调，不要求本机已经录入。录入/同步/删除只影响本机，不会调用业务服务器。

## 最小调用

```js
import { enrollFace, verifyFace } from '@/uni_modules/HelloFace-Verify'

// 用户点击“录入”时调用；默认不覆盖已存在的用户。
enrollFace({
  faceID: 'user-001',
  success: (res) => { if (res.passed === true) { /* 已确认并保存 */ } },
  fail: (err) => { /* 按 err.errCode / err.sdkCode 提示 */ }
})

// 用户后续点击“验证”时调用；默认前置、阈值 0.80、静默活体开启。
verifyFace({
  faceID: 'user-001',
  success: (res) => {
    if (res.passed === true) { /* 本人且所选活体流程通过 */ }
    else { /* 根据 res.outcome 提示重试，不能按分数自行放行 */ }
  },
  fail: (err) => { /* 取消、权限拒绝、未录入、SDK 错误等 */ },
  complete: (_) => { /* 关闭 loading、恢复按钮 */ }
})
```

接口返回 `void`，请使用回调，不能直接 `await verifyFace(...)`。H5/小程序不支持此原生能力；有浏览器预览需求时，将导入和调用放在 `APP` 条件编译内，示例页面已包含这一处理。

## 参数

采用单层 options 对象；不需要额外的初始化、全局配置或手工 JSON 序列化。参数默认值由共享 UTS 层统一维护，三端一致。

### enrollFace(options)

| 参数 | 类型 | 必填 / 默认 | 说明 |
| --- | --- | --- | --- |
| `faceID` | string | 必填 | 见下方标识规则 |
| `overwrite` | boolean | `false` | 已存在时 fail(9011006)；true 时仍需用户在原生页确认保存才替换 |
| `camera` | FaceCamera | `'front'` | `'front'` 前置 / `'back'` 后置，不自动切换 |
| `onProgress` | function | 可选 | 过程通知；原生页面已提供提示，可不传 |
| `success / fail / complete` | function | 可选 | 见回调约定 |

录入固定为“采集 → 预览 → 确认保存”。重新采集或确认前取消不会替换原基准。下文两种超时参数仅用于验证，录入不接受它们，也不支持跳过确认。

### verifyFace(options)

| 参数 | 类型 | 必填 / 默认 | 说明 |
| --- | --- | --- | --- |
| `faceID` | string | 必填 | 本机验证须与录入一致；直接传基准时用于关联此次业务 |
| `referenceFeature` | string | 不传 | 完整 HF1 基准；传入后优先使用它，不使用或修改本机基准 |
| `featureSpaceID` | string | 不传 | 与 referenceFeature 成对传入，使用录入/读取结果中的原值 |
| `threshold` | number | `0.80` | 有限数值 0..1；相似度不是身份概率，调低会放宽要求 |
| `silentLiveness` | boolean | `true` | 是否开启静默活体；false 不会清除 actions |
| `actions` | FaceAction[] | `[]` | 按顺序执行，最多 4 步，可重复；空数组不做动作活体 |
| `actionTimeoutMs` | number | `10000` | 每步动作超时，2000..30000 的整数毫秒 |
| `faceTimeoutMs` | number | `15000` | SDK 等待人脸的超时，1000..60000 的整数毫秒 |
| `camera` | FaceCamera | `'front'` | 前置/后置 |
| `onProgress` | function | 可选 | 过程通知 |
| `success / fail / complete` | function | 可选 | 见回调约定 |

`FaceAction` 为 `'blink'`（眨眼）、`'openMouth'`（张嘴）、`'shakeHead'`（摇头）、`'nodHead'`（点头）。`FaceCamera` 和 `FaceAction` 提供编辑器值域提示，运行时也校验参数。数字/布尔值请使用实际类型，不传 `'0.8'`、`'false'` 等字符串。

```js
// 增加动作只需传数组；默认静默活体继续生效。
verifyFace({
  faceID: 'user-001',
  actions: ['blink', 'nodHead'],
  actionTimeoutMs: 10000,
  success: (res) => { /* 仍以 res.passed === true 判断 */ }
})
```

两个超时都是 SDK 流程参数，不是整个接口调用的总时长，不包含系统权限对话框，也不是录入确认的等待时长。多脸默认拒绝。`silentLiveness: false` 且 `actions: []` 会关闭可选活体，仅做 1:1 比对；是否启用活体与阈值由业务评估，比对分数和 SDK 通过结论须区分。

### getFaceFeature / setFaceFeature / deleteFace

| API | 参数 | 结果 |
| --- | --- | --- |
| `getFaceFeature` | `faceID` + 可选回调 | 读取完整基准及特征空间；未录入 fail(9011005) |
| `setFaceFeature` | `faceID`、`feature`、`featureSpaceID`、可选 `overwrite: false` 和回调 | 保存到本机；已有且未允许覆盖 fail(9011006) |
| `deleteFace` | `faceID` + 可选回调 | 仅删除该用户的本机基准；不存在也成功 |

三个接口不打开相机、不申请相机权限。`setFaceFeature` 没有确认页面，业务应在允许覆盖前自行确认。

### faceID 与特征规则

`faceID` 自动去除两端空白，长度为 1..64 个 UTF-16 单元，禁止 NUL。建议使用稳定的账号 ID，不使用手机号展示名等会变动的文本。特征空间参与本机存储键，已有加密存储键未因本次升级改变。

HF1 是当前 SDK 的 604 字符特征编码，本身不是加密格式，不是图片/base64。`feature` 与 `featureSpaceID` 必须成对保存和传递；当前空间为 `jdx-feature-v1`，旧 FaceAISDK-Core 或其他模型特征不能直接使用。格式、空间、数值范围不符时在进入原生流程前 fail(9011001)，错误说明不回显完整特征。

```js
import { verifyFace, setFaceFeature } from '@/uni_modules/HelloFace-Verify'

// 在业务已取得与当前模型兼容的基准后，仅用于本次验证，不改变本机账号数据。
verifyFace({
  faceID: 'user-001',
  referenceFeature: savedFeature,   // 完整 HF1，从业务系统取得
  featureSpaceID: savedSpaceID,    // 与该特征一并保存的空间标识
  success: (res) => { /* res.passed / res.outcome */ },
  fail: (err) => { /* 参数、权限或 SDK 错误 */ }
})

// 如需后续只传 faceID 离线验证，改用显式同步：
setFaceFeature({ faceID: 'user-001', feature: savedFeature, featureSpaceID: savedSpaceID })
```

## 回调与结果

每次调用只产生一个终态：`success` 或 `fail`，随后执行一次 `complete`。终态之后的重复结果和进度会被忽略。参数校验失败也执行 fail、complete，可能在调用返回前发生；请先设置业务 loading，再调用插件。不要在 complete 中再次手工调用 success/fail。

`success` 表示接口正常完成，不代表验证通过。业务拒绝、活体失败、无脸超时都可正常返回 `success({ passed: false })`。只有 `passed === true` 才能放行。

| FaceResult 字段 | 类型 | 含义 |
| --- | --- | --- |
| `errMsg` | string | 如 `verifyFace:ok`，用于区分接口完成状态 |
| `faceID` | string | 规范化后的用户标识；cancel 为空 |
| `passed` | boolean / null | 录入/验证的 SDK 判定；管理接口、cancel 为 null |
| `outcome` | string / null | SDK 业务结果，未产生为 null |
| `similarity` | number / null | 相似度；未产生时为 null |
| `livenessScore` | number / null | 活体分数；未产生时为 null |
| `feature` | string / null | 录入、读取、同步可返回基准；验证、删除、取消不返回特征 |
| `featureSpaceID` | string | 当前 SDK 的特征空间，跨设备传递时保留 |

已知 outcome：`PASSED`、`NOT_MATCHED`、`SPOOF_DETECTED`、`NO_FACE_TIMEOUT`、`FACE_LOST`、`MULTIPLE_FACES`、`ACTION_TIMEOUT`、`FINAL_CAPTURE_TIMEOUT`。未产生的分数为 null，不能当成 0；也不能用高相似度覆盖 `passed: false`。

`onProgress` 可多次回调 `{ faceID, stage, action, stepNumber, stepCount }`。常见 stage 包括 `WAITING_FOR_FACE`、`PERFORM_ACTION`、`HOLD_STILL` 等 SDK 阶段；action 无动作时为 null。进度不触发 complete，不等于识别成功。

uvue 从插件入口导入 `FaceResult`、`HelloFaceVerifyFail`、`VerifyFaceOptions` 等类型即可。遵循 [DCloud UTS API 规范](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-plugin.html) 和 [complete 的桥接说明](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-uni-api.html)，complete 使用 any，仅作收尾；业务字段分别在 success/fail 中读取，避免混合结果类型跨 JS 桥接。

```ts
// uvue / UTS：需要复用参数时显式声明插件 Options 类型。
import { verifyFace, VerifyFaceOptions, FaceResult } from '@/uni_modules/HelloFace-Verify'

const options: VerifyFaceOptions = {
  faceID: 'user-001',
  actions: ['blink', 'nodHead'],
  success: (res: FaceResult) => { if (res.passed === true) { /* 继续业务 */ } }
}
verifyFace(options)
```

## 错误与取消

fail 符合 UniError：`errSubject: 'HelloFaceVerify'`、`errCode`、`errMsg`；额外提供 `sdkCode`（原始错误名称）与 `faceID`（关联用户，无有效标识时为空）。用户取消也走 fail，建议对 9011003 静默收尾。

| errCode | 含义 / 接入处理 |
| --- | --- |
| `9011001` | 参数错误或空间不兼容；先修正参数，勿直接重试 |
| `9011002` | 相机权限拒绝；提示用户授权 |
| `9011003` | 用户取消、页面关闭或相机进入后台；正常收尾 |
| `9011004` | 当前有操作，或录入确认后的保存尚未完成；等待 complete |
| `9011005` | 本机未录入；先录入/同步，或显式传入完整基准对 |
| `9011006` | 已有基准且未允许覆盖；由业务确认是否替换 |
| `9011007` | 本地特征存储错误；保留错误码用于排查 |
| `9011008` | SDK / 相机 / 桥接错误；查看 sdkCode，如 BRIDGE_ERROR、NO_CONTEXT |

```js
import { cancel } from '@/uni_modules/HelloFace-Verify'
// 本页面发起的相机任务仍在进行时，在 onUnload 中取消。
cancel({ success: (_) => { /* 原任务和相机已释放，可开始下一次操作 */ } })
```

同一插件实例全局串行，不为每个页面单独建队列；并发调用返回 BUSY，不会覆盖前一个用户的相机任务。仅在本页面拥有相机任务时取消，避免影响其他业务页面。

options 可省略，直接调用 `cancel()`。cancel 只取消相机任务，不中断普通特征读写；无相机任务也成功。取消相机时，原任务先返回 CANCELLED 并 complete，资源释放后 cancel 再 success；在其 success 中可开始新任务。流程若已产生终态，cancel 不撤回该结果，以先完成的终态为准。保存提交中 cancel 返回 BUSY，保存会完成，避免“报告取消但数据已写入”。系统权限对话框由系统管理，cancel 不会替用户关闭它，迟到的授权结果不会恢复已取消任务。

## 三端实现与集成边界

| 项目 | Android | iOS | HarmonyOS |
| --- | --- | --- | --- |
| 相机 | CameraX | AVFoundation | CameraKit |
| 基准保护 | Keystore AES-GCM | Keychain，仅本机且解锁后可访问 | HUKS AES-GCM |
| 取消完成 | 关闭 SDK/相机后释放任务 | 停止 pipeline、关闭页面后释放任务 | 等待异步 shutdown、关闭弹窗后释放任务 |
| 最低系统 | API 23 | iOS 15 | API 20 |

三端均保留原始 SDK outcome/error，初始化期间 NOT_READY、临时帧 BUSY 只跳过当前帧；SDK 真正的错误正常回传。相机进入后台会终止未提交的操作。插件不上传图片/特征、不落盘采集图；业务自行同步基准时负责账号关联、传输与存储。

修改原生代码、interface.uts 或共享 UTS 实现后，需要重新编译包含插件的基座；只更新示例页面不需要。完整构建与真机验证范围见 [验证记录](VALIDATION.md)，配置见 [打包指南](BUILDING.md)。
