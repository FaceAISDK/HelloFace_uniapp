# HelloFaceVerify 接入与 API

插件入口：`@/uni_modules/HelloFace-Verify`。十一个接口在 Android、iOS、HarmonyOS 上使用相同参数和回调，兼容 uni-app Vue2/Vue3 与 uni-app x uvue。原生相机、权限申请、特征加密和 SDK 生命周期由插件处理，业务页面无需先初始化 SDK。

## 先选择基准来源

| 接入方式 | 录入/保存 | 验证时传参 | 是否使用本机基准 |
| --- | --- | --- | --- |
| 本机录入（默认） | `enrollFace({ faceID })`，用户确认保存 | `verifyFace({ faceID })` | 是 |
| 服务端下发，仅本次使用 | 业务取得同模型的 HF1 与特征空间 | `faceID` + `referenceFeature` + `featureSpaceID` | 否，不保存、不替换 |
| 同步后离线使用 | `syncFaceFeature({ faceID, feature, featureSpaceID })` | 后续只传 `faceID` | 是 |
| 外部已录照片 | `syncFaceImage({ faceID, imageBase64 })` | 后续只传 `faceID` | 是 |

录入、验证和基准管理接口的 `faceID` 必填，是业务账号标识而非相机采集结果。直接传基准验证时它用于关联回调，不要求本机已经录入；独立活体 `detectLiveness` 和纯图片提取 `extractFaceFeature` 不需要该参数。录入/同步/删除只影响本机，不会调用业务服务器。

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

录入固定为“采集 → 预览 → 确认保存”。重新采集或确认前取消不会替换原基准。下文两种超时参数用于验证和独立活体，录入不接受它们，也不支持跳过确认。

### verifyFace(options)

| 参数 | 类型 | 必填 / 默认 | 说明 |
| --- | --- | --- | --- |
| `faceID` | string | 必填 | 本机验证须与录入一致；直接传基准时用于关联此次业务 |
| `referenceFeature` | string | 不传 | 完整 HF1 基准；传入后优先使用它，不使用或修改本机基准 |
| `featureSpaceID` | string | 不传 | 与 referenceFeature 成对传入，使用录入/读取结果中的原值 |
| `threshold` | number | `0.80` | 有限数值 0..1；相似度不是身份概率，调低会放宽要求 |
| `silentLiveness` | boolean | `true` | 是否开启静默活体；false 不会清除 actions |
| `actions` | FaceAction[] | `[]` | 按顺序执行，最多 4 步，可重复；空数组不做动作活体 |
| `actionTimeoutMs` | number | `3000` | 每步动作超时，2000..30000 的整数毫秒 |
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
  actionTimeoutMs: 3000,
  success: (res) => { /* 仍以 res.passed === true 判断 */ }
})
```

静默与动作是两个独立选项，组合如下。Demo 默认勾选眨眼、点头，开启动作后可从四种动作中选择，至少保留一项，按列表顺序执行：

| `silentLiveness` | `actions` | 验证内容 |
| --- | --- | --- |
| `false` | `[]` | 仅 1:1 比对 |
| `true` | `[]` | 比对 + 静默活体（默认） |
| `false` | `['blink', 'nodHead']` | 比对 + 动作活体 |
| `true` | `['blink', 'nodHead']` | 比对 + 静默活体 + 动作活体 |

两种活体一起启用时，在同一次 `verifyFace` 调用中传入 `silentLiveness: true` 和非空 `actions`，使用最终 `passed` 判断整个验证是否通过。Demo 的 `actionLiveness` 只是页面状态，对外 API 仍使用动作数组；组合选择不影响录入、同步或删除基准。

两个超时都是 SDK 流程参数，不是整个接口调用的总时长，不包含系统权限对话框，也不是录入确认的等待时长。多脸默认拒绝。`silentLiveness: false` 且 `actions: []` 会关闭可选活体，仅做 1:1 比对；是否启用活体与阈值由业务评估，比对分数和 SDK 通过结论须区分。

### 独立活体、图片提取与基准状态

```js
import { detectLiveness, extractFaceFeature, getFaceStatue } from '@/uni_modules/HelloFace-Verify'

// 无需 faceID 或已录基准。省略 actions 时只做静默活体；传入后再叠加动作。
detectLiveness({
  actions: ['blink', 'nodHead'],
  success: res => { if (res.passed === true) { /* 活体通过，不表示身份匹配 */ } },
  fail: err => { /* err.code / err.msg */ }
})

// 只提取，不保存到本机；不要把返回的原始特征写入日志。
extractFaceFeature({
  imageBase64: photoBase64,
  success: res => { /* 使用 res.feature 和 res.featureSpaceID */ }
})

// 名称按本工程 API 保留为 getFaceStatue；正常缺少基准不是接口错误。
getFaceStatue({
  faceID: 'demo-user',
  success: res => { if (res.exists === true) { /* 基准存在且可读取 */ } }
})
```

| 接口 | 必要输入 | 可选配置 | 成功结果 |
| --- | --- | --- | --- |
| `detectLiveness` | options 对象，可为 `{}` | `actions: []`、`actionTimeoutMs: 3000`、`faceTimeoutMs: 15000`、`camera: 'front'`、`onProgress` | `passed / outcome / livenessScore`；`feature / similarity` 为 null |
| `extractFaceFeature` | `imageBase64` | 通用回调 | `feature / featureSpaceID`；不作身份或活体判定 |
| `getFaceStatue` | `faceID` | 通用回调 | `exists: true / false`；不返回原始特征，不初始化识别 SDK |

三者沿用 `success / fail / complete`，返回 `void`。独立活体与图片提取不绑定用户，回调 `faceID` 为空串；状态查询返回归一化后的输入标识。独立活体支持进度与 `cancel()`，参数限制及后台释放/亮度恢复与验证共用。取消只作用于相机，不取消图片提取或存储操作；操作槽未释放前其他调用仍返回 104。

当前 SDK 0.8.11 的独立活体流程**始终包含静默活体**，非空 `actions` 叠加动作挑战，因此该接口不提供 `silentLiveness` 开关；需要对身份比对配置四种组合时继续使用 `verifyFace`。依据 [锁定 SDK 的公开说明](https://github.com/FaceSDKPro/HelloFace/blob/dc60c7b15ebf8038fb73a752bcea3590bbd86eaf/platforms/Harmony/SDK.zh-CN.md#相机流程生命周期)。

Vue/uvue 首页在“1:1 人脸验证”下方提供“独立活体检测”卡片，点击“开始活体检测”即可演示；无需先录入或填写 faceID。该卡片单独保存动作开关和勾选结果，关闭动作时只做静默活体，打开时追加所选动作，默认眨眼、点头，至少保留一项。`detectLiveness({ actions: [] })` 是有效的静默活体调用，现有接口没有“两种活体都关闭”的状态；“两个都关闭应报参数错误”不适用于当前契约。身份验证的两个开关都关闭时，`verifyFace` 仍按既有约定只比对身份。

图片提取复用 `syncFaceImage` 的 PNG/JPEG、Base64、6 MiB、EXIF、像素及人脸大小限制，但不读取或写入任何基准，不覆盖已录用户，也不落盘图片。状态查询只读：不存在返回 `code: 0, exists: false`，存在且能读取返回 `exists: true`；读取/解密失败走 `fail`（302），不能把异常当作未录入。存在状态不等于身份或活体通过，也不能恢复已被清除的基准。

新增原生接口后需重新原生联编或重建调试基座/完整 HAP；仅刷新 Vue 页面不会为旧基座增加接口。11 个方法保持同一套错误码和互斥机制，原有调用不变。

### getFaceFeature / setFaceFeature / deleteFace

| API | 参数 | 结果 |
| --- | --- | --- |
| `getFaceFeature` | `faceID` + 可选回调 | 读取完整基准及特征空间；未录入 fail(9011005) |
| `setFaceFeature` | `faceID`、`feature`、`featureSpaceID`、可选 `overwrite: false` 和回调 | 保存到本机；已有且未允许覆盖 fail(9011006) |
| `deleteFace` | `faceID` + 可选回调 | 仅删除该用户的本机基准；不存在也成功 |

三个接口不打开相机、不申请相机权限。`setFaceFeature` 没有确认页面，业务应在允许覆盖前自行确认。

### syncFaceImage / syncFaceFeature

用于照片或基准已在别处录好、本机无需重新相机录入的场景；三端不打开相机、不申请相机权限，不包含服务器请求。

```js
import { syncFaceImage, syncFaceFeature, verifyFace } from '@/uni_modules/HelloFace-Verify'

// imageBase64 来自业务服务器/本地文件；不是图片 URL，也不是 HF1 特征。
syncFaceImage({
  faceID: 'user-001', imageBase64: photoBase64,
  success: (res) => { /* code 0：已提取并保存 res.feature 与 res.featureSpaceID */ },
  fail: (err) => { /* 展示 err.msg，排查 err.sdkCode / err.detail */ }
})

// 或者：业务服务器已保存同模型 SDK 提取的特征，直接同步，省去本地图片处理。
syncFaceFeature({
  faceID: 'user-002', feature: serverFeature, featureSpaceID: serverFeatureSpaceID,
  success: (res) => { /* 同步成功后，后续 verifyFace 只需传相同 faceID */ }
})
// 同步成功后的业务按钮再调用：verifyFace({ faceID: 'user-001', success: ... })
```

| 参数 | 默认 / 限制 |
| --- | --- |
| `faceID` | 必填，规则同录入 |
| `imageBase64` | 图片同步必填；标准 Base64，支持纯字符串或 `data:image/png;base64,` / `data:image/jpeg;base64,` 前缀，不含空白 |
| `feature`、`featureSpaceID` | 特征同步必填；完整 HF1 + SDK 返回的原特征空间；不接受其他模型特征或图片数据 |
| `overwrite` | 默认 `false`；已有基准 fail(106)。业务确认更新后才传 `true`，没有原生确认页 |
| `success / fail / complete` | 同其他接口；成功返回 `code: 0 / msg: '同步成功'`、完整特征和特征空间 |

图片统一接受 PNG/JPEG，编码文件最多 **6 MiB**，每边 **2..4096 px**，总像素最多 **4194304**；超限请业务先缩小。三端应用 EXIF 方向，奇数末边由 SDK/适配层裁去 1 px，不主动放大或美颜。采用三端公开的 **extractFeature** 入口（Android 在串行工作线程使用 `extractFeatureBlocking`），不依赖额外返回对齐图或较新的多人采集接口。**请传清晰单人照片**：该原生入口选择最大脸，人脸宽高均须至少 100 px；无人脸 fail(108)，人脸过小 fail(109)，无法解码/图片超限 fail(107)。不具备多人照片拒绝保证。

同步接口返回的 `passed / outcome / similarity / livenessScore` 均为 `null`。照片同步不执行活体，成功表示基准已保存，不是身份验证结论。提取失败保留原基准；不落盘原照片。所有操作共用任务锁，处理期间其他操作 fail(BUSY)；`cancel()` 只取消相机任务，不取消同步。

`syncFaceFeature` 与 `setFaceFeature` 使用同一存储语义，保留旧接口兼容。服务器下发特征可来自其他设备，但必须来自兼容模型/预处理的 SDK，并同时传递返回的 `featureSpaceID`。仅用于本次验证且不保存时，仍可用 `verifyFace({ faceID, referenceFeature, featureSpaceID })`。

两套 Demo 的同步按钮读取同一份 [AI 示例基准](../demo/README.md)：200×200 PNG 经 TinyPNG 压缩，HF1 由压缩后图片通过真实 SDK 提取。按钮与录入、验证、删除共用输入框中的 `faceID`，默认 `demo-user`，并显式覆盖当前标识的基准。同步演示人脸后，如需验证本人，应重新相机录入本人。AI 人脸用于演示数据同步，不能拿本人通过该人脸的活体验证。业务接入时换成自己的照片/服务器特征，通常保留 `overwrite: false`。

### faceID 与特征规则

`faceID` 自动去除两端空白，长度为 1..64 个 UTF-16 单元，禁止 NUL。建议使用稳定的账号 ID，不使用手机号展示名等会变动的文本。特征空间参与本机存储键，已有加密存储键未因本次升级改变。

HF1 是当前 SDK 的 604 字符特征编码，本身不是加密格式，不是图片/base64。`feature` 与 `featureSpaceID` 必须成对保存和传递；当前空间为 `jdx-feature-v1`，旧 FaceAISDK-Core 或其他模型特征不能直接使用。共享层检查 HF1 长度、字符集和空间，不符时在进入原生流程前 fail(9011001)；特征内容是否可用于比对由真实 SDK 判断，不能把格式通过当作有效身份基准。错误说明不回显完整特征。

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

日常接入读取 `code + msg`，两种回调都提供这两个字段。`0` 表示当前方法成功；`1xx` 为操作问题，`2xx` 为识别未通过，`3xx` 为运行异常。`2xx` 仍走 success，SDK 判定和回调顺序不变。`errCode`、`sdkCode`、`outcome` 保留兼容。

| FaceResult 字段 | 类型 | 含义 |
| --- | --- | --- |
| `code` | FaceCode | 简短返回码，见下表 |
| `msg` | string | 可直接展示的短提示 |
| `errMsg` | string | 如 `verifyFace:ok`，用于区分接口完成状态 |
| `faceID` | string | 规范化后的用户标识；cancel、独立活体、纯图片提取为空串 |
| `exists` | boolean / null，可选字段 | 仅 getFaceStatue 返回 true/false，其他接口为 null；读取异常走 fail |
| `passed` | boolean / null | 录入/验证/独立活体的 SDK 判定；其他接口为 null |
| `outcome` | string / null | SDK 业务结果，未产生为 null |
| `similarity` | number / null | 仅验证返回实际相似度；其他接口、未产生或非有限值为 null |
| `livenessScore` | number / null | 验证/独立活体返回实际活体分数；其他接口、未产生或非有限值为 null |
| `feature` | string / null | 录入、读取、同步、图片提取返回 HF1；验证、独立活体、状态查询不返回特征 |
| `featureSpaceID` | string | 当前 SDK 的特征空间，跨设备传递时保留 |

已知 outcome：`PASSED`、`NOT_MATCHED`、`SPOOF_DETECTED`、`NO_FACE_TIMEOUT`、`FACE_LOST`、`MULTIPLE_FACES`、`ACTION_TIMEOUT`、`FINAL_CAPTURE_TIMEOUT`。未产生的分数为 null，不能当成 0；也不能用高相似度覆盖 `passed: false`。

## 返回码

三端共用 `utssdk/status.uts`。`code: 0` 的提示按方法返回：录入成功、验证通过、读取成功、保存成功、同步成功、删除成功、已取消。

| 分类 | code | msg | 对应原因 |
| --- | --- | --- | --- |
| 操作 | 101 | 参数错误 | INVALID_ARGUMENT；具体参数见 detail |
| 操作 | 102 | 相机未授权 | PERMISSION_DENIED |
| 操作 | 103 | 已取消 | CANCELLED |
| 操作 | 104 | 操作中 | BUSY |
| 操作 | 105 | 请先录入 | NOT_FOUND |
| 操作 | 106 | 已录入 | ALREADY_EXISTS |
| 操作 | 107 | 图片无效 | INVALID_IMAGE / UNSUPPORTED_FORMAT |
| 操作 | 108 | 图片无人脸 | IMAGE_NO_FACE |
| 操作 | 109 | 人脸过小 | IMAGE_FACE_TOO_SMALL |
| 识别 | 201 | 人脸不匹配 | NOT_MATCHED |
| 识别 | 202 | 活体未通过 | SPOOF_DETECTED |
| 识别 | 203 | 未检测到人脸 | NO_FACE_TIMEOUT |
| 识别 | 204 | 人脸丢失 | FACE_LOST |
| 识别 | 205 | 检测到多人 | MULTIPLE_FACES |
| 识别 | 206 | 动作超时 | ACTION_TIMEOUT |
| 识别 | 207 | 采集超时 | FINAL_CAPTURE_TIMEOUT |
| 识别 | 299 | 未通过 | SDK 判定为 false，但 outcome 未知或不一致 |
| 运行 | 301 | 相机异常 | CAMERA_ERROR |
| 运行 | 302 | 存储异常 | STORAGE_ERROR / DATABASE_ERROR |
| 运行 | 303 | SDK未就绪 | NOT_READY / CLOSED |
| 运行 | 304 | 识别异常 | 其他 SDK 错误；原始名称见 sdkCode |
| 运行 | 305 | 返回异常 | BRIDGE_ERROR |
| 运行 | 306 | 环境不可用 | NO_CONTEXT / UNSUPPORTED_PLATFORM |
| 运行 | 307 | SDK授权异常 | SDK 返回的 LICENSE_* 错误 |
| 运行 | 308 | 模型异常 | MODEL_LOAD_FAILED |

例如未检测到人脸时返回 `success({ code: 203, msg: '未检测到人脸', passed: false, outcome: 'NO_FACE_TIMEOUT', ... })`，不是接口异常。原任务被取消返回 `fail({ code: 103, msg: '已取消', ... })`；主动调用 `cancel()` 本身成功时则为 `code: 0 / msg: '已取消'`。

`msg` 仅用于显示，业务不要解析提示文字。验证仍判断 `passed`；本机特征管理判断 code 是否为 0。错误排查用 `sdkCode + detail`，无需让页面显示底层长文案。进度通知继续使用 stage/action，不携带终态 code。

`getFaceStatue` 的结果额外包含可选布尔字段 `exists`，其他接口为 null；不会为查询返回 `feature`。

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

fail 符合 UniError：`errSubject: 'HelloFaceVerify'`、原有 `errCode` 保持不变，`errMsg` 为 `方法名:fail 短提示`。新增 `code / msg` 用于日常处理，`detail` 保留原始参数校验或 SDK 说明；`sdkCode` 保留原始错误名称，`faceID` 关联此次用户。用户取消仍走 fail，可对 `code: 103`（原 `errCode: 9011003`）静默收尾。

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

已有包含 SDK/依赖的基座后，修改插件 `.uts`、`interface.uts`、共享 UTS 或混编 `.kt`，可用 HBuilderX 本地联编并重新运行；修改原生依赖、Manifest 或资源时需要重制基座。仓库命令行页面同步工具对源码采用更保守的指纹检查，不能用页面同步代替原生编译。完整构建与真机验证范围见 [验证记录](VALIDATION.md)，配置见 [打包指南](BUILDING.md)。
