# 验证记录

日期：2026-11-09。原生 SDK 0.8.8，上游提交 `572751458a3ea9d85ca422cecec56d115be71e4e`。

## 已通过

| 检查 | 结果与范围 |
| --- | --- |
| `npm test` | 15 项 API 契约测试和 3 项 SDK 安装器测试通过 |
| SDK 文件校验 | 37 个文件均通过锁定的 SHA-256 和长度校验 |
| 官方 UTS 转换 | HBuilderX 5.34 的 UTS 编译器成功生成 Kotlin、Swift、ArkTS；不是最终 App 链接验证 |
| Android 原生编译 | 将插件原生 Kotlin 源码直接加入临时 Android Library，`compileDebugKotlin` 成功；AGP 8.13.1、Kotlin 1.9.22、JDK 17、compileSdk 36、CameraX 1.5.2、真实 0.8.8 AAR |
| 鸿蒙原生构建 | 将原生 ArkTS 源码加入临时 HAR 模块，DevEco Studio 26 / Hvigor 的 `assembleHar` 成功，使用真实 0.8.8 HAR，未签名 |
| iOS Swift 语法 | `swiftc -frontend -parse` 检查所有原生 Swift 文件通过；不代表类型检查或链接通过 |

API 测试执行实际 UTS 入口及共享校验/回调代码，使用轻量的 JS 环境适配 UTSJSONObject。原生调用在测试中被捕获，**不会伪造识别成功作为算法测试**。覆盖默认参数、非法输入拦截、特征空间不匹配、未通过活体时保留业务拒绝、空分数、取消错误、原始 SDK 错误和 complete 回调行为。

安装器测试覆盖：同长度文件篡改、LFS 指针误用、只校验模式不创建文件、安装失败保留已有文件和清理临时文件。

## 本机环境限制

本机 Xcode 为 15.2，无法完整编译 Swift 6.1.2 构建的上游 iOS SDK。需使用兼容新版 Xcode，或在满足 SDK 工具链要求的云打包环境中完成 iOS 编译和链接。

本机 HBuilderX 的 Android/iOS 模块编译命令提示安装原生运行扩展，未产出最终可运行基座。Android 和鸿蒙的原生编译已在独立原生工程完成；Vue2、Vue3、uvue 与完整基座的联合运行仍需 HBuilderX 环境验收。

未连接并操作三端真机，因此当前记录不声称权限弹窗、摄像头行为、识别效果、加密存储硬件能力和跨设备特征互通已通过真机验收。

## 复查命令

```sh
npm ci --ignore-scripts
npm test
python3 scripts/install_sdk.py --check
node scripts/check_uts.cjs
```

可通过 `HBUILDERX_PATH` 指定 HBuilderX 的 `Contents/HBuilderX` 目录。原生源码位于插件的 `utssdk/app-android`、`app-ios`、`app-harmony`；独立原生构建直接引用这些文件和安装器获取的真实 SDK，未引入算法替代实现。

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
