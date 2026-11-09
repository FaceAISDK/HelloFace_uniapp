# Android 原生 SDK 集成检查

`NativeSdkSmoke.java` 在已安装的调试基座进程内调用插件的真实 Kotlin 入口和 HelloFace SDK。覆盖 12 项检查：未录入返回、Keystore 加密保存与解密读取、特征往返、覆盖保护、无人脸验证结果、重复请求拦截、取消确认、原任务取消、取消后继续调用、删除及删除后读取。

先安装完整自定义基座并授权相机，测试时让镜头内无人脸。测试会重启被测 App，使用随机测试 faceID，结束时删除测试基准和临时验收 App。需要 Android SDK 的 platform/build-tools、JDK 17，以及与被测基座相同的调试证书。

通过 `HELLOFACE_TEST_STOREPASS` 环境变量提供调试证书密码；若私钥密码不同，另设 `HELLOFACE_TEST_KEYPASS`。执行：

```sh
npm run android:native-check -- \
  --feature-file /本机路径/features_10000.json \
  --keystore /本机路径/demo.jks --alias 调试证书别名 \
  --device Android设备序列号
```

`--feature-file` 使用上游 HelloFace 同版本的 `platforms/Android/demo/src/main/assets/face_search/features_10000.json`，需通过 Git LFS 获取实际内容。当前验证使用上游提交 `572751458a3ea9d85ca422cecec56d115be71e4e` 的公开测试特征，脚本检查 `jdx-feature-v1` 与 HF1 格式，只取一条测试特征；测试数据与证书不入库，日志不输出特征。

默认被测包名为 `dev.helloface.uniapp.demo`，可通过 `--package` 指定其他包含本插件的调试宿主。此检查执行真实 SDK 验证调用，预期无人脸时返回 `NO_FACE_TIMEOUT`；本人识别、他人拒绝和活体防攻击仍需真人验收。
