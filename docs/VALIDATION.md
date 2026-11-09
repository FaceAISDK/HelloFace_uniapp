# 验证记录

日期：2026-11-09。原生 SDK 0.8.8，上游提交 `572751458a3ea9d85ca422cecec56d115be71e4e`。

插件 0.1.1 的发布 ID 为 `HelloFace-Verify`，展示名称为 `HelloFaceVerify`。本次 ID 迁移后重新通过 28 项自动化检查、37 个 SDK 文件校验和三端 UTS 转换，并核对了目录、示例导入、5 个关键词和版本一致性。原生源码与存储键未因本次 ID 迁移改变；此前的 Android Kotlin 编译、鸿蒙 HAR 构建与 iOS Swift 语法检查记录见下表。以下 iOS 完整编译与真机验收限制继续适用。

## 已通过

| 检查 | 结果与范围 |
| --- | --- |
| 插件 ID | `HelloFace-Verify` 符合“作者 ID-插件名”结构，目录与导入一致。HBuilderX 5.34 官方解析器确认新旧 ID 映射为相同 Kotlin/Swift 命名空间；插件市场的 ID 占用与发布结果仍需服务端确认 |
| `npm test` | 15 项 API 契约测试、10 项示例交互测试和 3 项 SDK 安装器测试通过 |
| 示例页面 | Vue 示例通过 HBuilderX 5.34 的 H5 构建；uvue 脚本与 Kotlin/Swift 模板编译、三端 CSS 检查通过。浏览器预览只检查布局与交互，不代表真机识别验收 |
| SDK 文件校验 | 37 个文件均通过锁定的 SHA-256 和长度校验 |
| 官方 UTS 转换 | HBuilderX 5.34 的 UTS 编译器成功生成 Kotlin、Swift、ArkTS；不是最终 App 链接验证 |
| Android 完整自定义基座 | HBuilderX 5.34 云端构建成功，APK 约 30.8 MB；相机 Activity、ARM64/ARMv7 动态库和 6 个未压缩模型均已确认，签名通过 API 23 校验，并已安装到华为 GRA-UL00 / Android 6.0 |
| Android 运行入口 | `npm run android:check` 在已授权的 Android 6.0 / API 23、ARM64 设备上通过；检查真实 AppID、包名、基座版本、SDK 与模型打包，错误 AppID、不完整基座和压缩模型均被拦截 |
| Android Vue3 真机运行 | HBuilderX 5.34 导出当前页面资源成功，`android:run -- --skip-install --sync-resources` 完成同步并启动（`Status: ok`）。首页显示正常；未录入时验证正确返回 `NOT_FOUND`，相机权限授权后成功打开原生录入 Activity 与前置相机预览，取消正确回调并返回示例。观察期间未见插件崩溃或 JS 异常；真人确认录入、持久化和 1:1 比对尚未验收 |
| Android 原生编译 | 将插件原生 Kotlin 源码直接加入临时 Android Library，`compileDebugKotlin` 成功；AGP 8.13.1、Kotlin 1.9.22、JDK 17、compileSdk 36、CameraX 1.5.2、真实 0.8.8 AAR |
| 鸿蒙原生构建 | 将原生 ArkTS 源码加入临时 HAR 模块，DevEco Studio 26 / Hvigor 的 `assembleHar` 成功，使用真实 0.8.8 HAR，未签名 |
| iOS Swift 语法 | `swiftc -frontend -parse` 检查所有原生 Swift 文件通过；不代表类型检查或链接通过 |

API 测试执行实际 UTS 入口及共享校验/回调代码，使用轻量的 JS 环境适配 UTSJSONObject。原生调用在测试中被捕获，**不会伪造识别成功作为算法测试**。覆盖默认参数、非法输入拦截、特征空间不匹配、未通过活体时保留业务拒绝、空分数、取消错误、原始 SDK 错误和 complete 回调行为。

安装器测试覆盖：同长度文件篡改、LFS 指针误用、只校验模式不创建文件、安装失败保留已有文件和清理临时文件。

示例交互测试执行 Vue/uvue 页面的实际脚本，用替身捕获插件调用，检查活体参数、重复点击拦截、删除确认、失败收尾、离页取消，以及高相似度但 `passed: false` 时仍显示未通过。页面不保存或展示原始人脸特征；浏览器预览只提示真机运行。

## 本机环境限制

本机 Xcode 为 15.2，无法完整编译 Swift 6.1.2 构建的上游 iOS SDK。需使用兼容新版 Xcode，或在满足 SDK 工具链要求的云打包环境中完成 iOS 编译和链接。

本机已安装 Android 原生运行扩展并生成 Android 自定义基座。HBuilderX 5.34 的“已安装基座”CLI 在本次环境停在启动阶段，使用 `appResource` 导出和 ADB 同步页面后，完成上述 Vue3 页面与录入相机检查。Vue2、uvue 的完整基座联合运行仍待验收。

本次仅连接并操作 Android 真机；相机首次授权和录入预览已检查，尚不能据此声称真人识别效果、加密存储持久化和跨设备特征互通已通过验收。iOS、HarmonyOS 的真机流程仍待验证。

## 复查命令

```sh
npm ci --ignore-scripts
npm test
python3 scripts/install_sdk.py --check
node scripts/check_uts.cjs
```

可通过 `HBUILDERX_PATH` 指定 HBuilderX 的 `Contents/HBuilderX` 目录。原生源码位于插件的 `utssdk/app-android`、`app-ios`、`app-harmony`；独立原生构建直接引用这些文件和安装器获取的真实 SDK，未引入算法替代实现。

工程也提供 `npm run check` 顺序执行自动化测试、SDK 文件校验和 UTS 转换。它不生成正式安装包；本地与云端构建路径见 [三端打包指南](BUILDING.md)，接口定义见 [API 参考](API.md)。

## 待真机验收

在 Android、iOS、HarmonyOS 上，分别使用 Vue2、Vue3、uvue 宿主完成以下用例，并记录 OS、HBuilderX、原生 SDK 版本与设备型号：

1. 首次拒绝相机权限、再次授权、永久拒绝后的失败返回。
2. 首次录入、确认前取消、确认后重启 App 仍可验证；覆盖录入需 `overwrite: true`。
3. 未录入的 faceID、本人、他人、照片/屏幕攻击、多脸、无人脸和动作超时。
4. 默认静默活体、启用眨眼/点头、关闭可选活体时的 1:1 流程。
5. 快速重复调用返回 BUSY，取消后立即启动新任务，旧结果不进入新任务；相机任务进入后台后释放。
6. 退出录入确认界面不会保存；确认保存过程中不会报告“取消但已写入”。
7. 读取并同步同一特征空间的 HF1，拒绝旧插件特征；删除已有/不存在/损坏的本地基准。
8. 调整前后置相机；横竖屏、锁屏和来电后的恢复；SDK 原始授权错误原样传递。
