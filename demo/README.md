# 外部基准示例

- `../static/demo-face.png`：完全虚构的 AI 成年人脸，最终尺寸 200×200，PNG 26255 字节。内置 imagegen 生成后裁近并缩小，经 TinyPNG 网站压缩；缩小前母图不打入 App。200×200 原 PNG 为 59846 字节，压缩后减少约 56%。TinyPNG 采用视觉近似无损的有损量化，不是数学意义的无损。
- `face-reference.json` 记录实际提取的 HF1、特征空间、SDK 版本和最终图片 SHA-256；脚本生成完全相同的 `face-reference.js`（Vue2/Vue3）和 `face-reference.uts`（uvue），包含 Base64 与特征常量，模拟服务器下发的数据。特征不由 AI 生成，不使用随机占位值。
- 两套示例共享这些常量，`npm run demo:prepare` 复制给 uvue。同步按钮直接调用插件，不依赖设备上先有任何录入数据，也不调用云识别服务。
- AI 图片只演示同步基准，不表示录入活体或验证通过；真人不能按该 AI 基准验证自己的身份。演示操作统一使用输入框中的 `faceID`，默认 `demo-user`；点击“同步演示人脸图片/特征”会覆盖当前标识的基准，需要验证本人时应重新录入本人。

修改图片后，先运行 [真实 SDK 图片检查](../tests/android/README.md) 导出新的特征，更新 JSON 中的特征、图片 SHA-256 和 SDK 版本，再运行 `npm run demo:prepare`。脚本遇到图片哈希或 SDK 版本不一致会停止，避免图片与外部特征悄悄失配。

生成工具：内置 imagegen（非 CLI）。生成提示：

> Use case: photorealistic-natural. Asset type: face SDK demo fixture. Generate one square, realistic ID-style headshot of a completely fictional adult East Asian person about 30 years old, straight-on facing camera, neutral expression, eyes open, closed mouth, no glasses, no hat, face unobstructed. Plain light gray background, even soft lighting, sharp natural facial landmarks. Head occupies about 75% of image height, full chin and forehead visible with small margin, no hands. Intended final deliverable 200 by 200 pixels; make a square clean portrait suitable for resizing. No text, logos or watermark.

2026-11-11 使用锁定提交 `dc60c7b15ebf8038fb73a752bcea3590bbd86eaf` 的 SDK 0.8.11，在鸿蒙 API 26 完整签名示例中重新提取最终 PNG 的特征。通过公开同步/读取/删除 API 使用随机测试标识，测试基准已删除；JSON 记录此次提取平台，Vue/uvue 常量已重新生成。模型文件未改变，但新提取值与旧版不同，未仅修改版本标签沿用旧特征。
