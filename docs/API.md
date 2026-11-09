# HelloFaceVerify API 参考

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
| `actionTimeoutMs` | `10000` | 整数，2000–30000 毫秒，与原生 SDK 的动作超时范围一致 |
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

`fail` 返回符合 UniError 约定的 `errSubject: "HelloFaceVerify"`、`errCode`、`errMsg`，另有 `sdkCode` 保留原始错误名称。

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


[返回工程说明](../README.md) · [三端打包指南](BUILDING.md)
