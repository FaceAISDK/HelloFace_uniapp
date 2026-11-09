## 0.1.1（2026-11-09）

- 插件发布 ID 规范为 HelloFace-Verify（作者前缀 HelloFace，插件名 Verify），展示名称为 HelloFaceVerify；同步目录、导入、示例和安装脚本。
- 优化人脸识别、人脸比对、活体检测、离线人脸识别、鸿蒙五个关键词及市场介绍。
- 更正本机特征加密保存的隐私说明，补充独立插件文档与升级路径。
- 错误主题调整为 HelloFaceVerify；保留原有加密存储键，避免仅因更名而丢失已有基准。

## 0.1.0（2026-11-09）

- 基于 HelloFace 原生 SDK 0.8.8 的首版 UTS 1:1 封装。
- Android CameraX、iOS AVFoundation、HarmonyOS CameraKit 原生相机流程。
- 录入确认、按 faceID 验证、可选静默/动作活体、特征读取/同步/删除。
- Vue2 / Vue3 和 uvue 示例，统一类型、UniError、权限及取消处理。
- 原生 SDK 固定版本安装与 SHA-256 校验。
