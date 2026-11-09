# HelloFaceVerify · uni-app / uni-app x 离线人脸识别与活体检测 UTS 插件

**HelloFaceVerify** 是面向 **uni-app / uni-app x** 的离线人脸识别 UTS 插件，专注**人脸录入、1:1 人脸比对、静默活体检测和动作活体检测**。支持 **Android、iOS、HarmonyOS 鸿蒙**原生相机采集，适配 **Vue2、Vue3、uvue**，便于评估 App 登录确认、签到核验与设备端人员验证等场景。

识别在设备端离线完成，无需调用云端人脸识别 API。用户确认录入后，基准特征加密保存在本机；业务可按 `faceID` 读取、同步和删除。底层使用 [FaceSDKPro/HelloFace](https://github.com/FaceSDKPro/HelloFace) 原生 SDK 0.8.8。

插件发布 ID 为 `HelloFace-Verify`（作者前缀 `HelloFace`，插件名 `Verify`），展示名称为 `HelloFaceVerify`。目录与导入入口为 `uni_modules/HelloFace-Verify`；从早期 `HelloFace` 或 `HelloFaceVerify` 目录升级时，更新导入路径并重新构建包含插件的原生基座。接口方法与参数相同，当前错误主题为 `HelloFaceVerify`，本机特征存储键延续原有值。

录入流程：打开原生相机 → 采集人脸 → 显示采集预览 → 用户确认 → 保存此 `faceID` 的基准特征。识别流程：读取此 `faceID` 的特征 → 原生相机连续送帧 → 可选静默/动作活体 → 1:1 比对 → 返回 SDK 业务结果。

## 工程入口与目录

| 入口 | 用途 |
| --- | --- |
| 当前工程根目录 | HBuilderX 的 uni-app Vue3 示例；切换 `vueVersion` 可运行 Vue2 |
| `examples/uni-app-x` | 独立的 uvue 示例，执行 `npm run demo:prepare` 后导入 HBuilderX |
| `uni_modules/HelloFace-Verify` | 唯一的插件源码目录，业务工程集成此目录 |
| [三端打包指南](docs/BUILDING.md) | 本地/云端打包选择、平台配置与操作步骤 |
| [API 参考](docs/API.md) | 接口、参数、结果与错误码 |
| [验证记录](docs/VALIDATION.md) | 已通过的检查和待执行的真机验收 |

两套示例都在页面的 `enroll`、`verify`、`remove` 方法中直接调用插件，展示参数、成功/失败回调与 `complete` 收尾。示例设置 `overwrite: true` 方便重复录入，仍需在原生采集页确认保存；业务可按需保留默认的 `false`。

```text
HelloFace_uniapp/
├── App.vue / main.js / manifest.json / pages.json   # Vue2 / Vue3 示例配置
├── pages/index/index.vue                            # 示例页面
├── uni_modules/HelloFace-Verify/                     # 插件主源码
│   ├── package.json / readme.md / notices/
│   └── utssdk/
│       ├── interface.uts                            # 统一对外类型
│       ├── shared.uts / unierror.uts                 # 参数校验、回调与错误映射
│       ├── app-android/                             # Kotlin、UTS、AAR 与清单
│       ├── app-ios/                                 # Swift、UTS、xcframework 与清单
│       └── app-harmony/                             # ArkTS、UTS、HAR 与权限
├── examples/uni-app-x/                              # uvue 示例工程
├── scripts/                                        # SDK 安装、示例同步与 UTS 检查
├── tests/                                          # API 契约与安装器测试
├── docs/                                           # 接口、构建与验证文档
└── sdk-artifacts.json                               # 原生 SDK 版本和校验锁
```

在 `uni_modules/HelloFace-Verify` 修改插件，再同步到 uvue 示例。`examples/uni-app-x/uni_modules` 是生成的副本；`unpackage`、`node_modules`、`.sdk-cache` 为本机产物，不作为插件源码维护。

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

3. 按 [三端打包指南](docs/BUILDING.md) 选择构建方式。Android / iOS 可使用 DCloud 云打包或本地原生工程打包；鸿蒙走本地 DevEco 工具链。调试时需要包含本插件及原生 SDK 的基座或本地运行产物，不能直接用缺少原生依赖的标准基座验证。自定义基座不等于必须云打包。Android 的 `manifest.json` 已配置 `noCompress 'bphfm'`；原生依赖、权限或打包配置变更后，需重新构建原生产物。

4. 运行 uvue 示例：

   ```sh
   npm run demo:prepare
   ```

   在 HBuilderX 中单独导入 `examples/uni-app-x`，配置自己的 AppID/签名后运行。该命令把根目录的插件与已安装的原生依赖复制到示例中，避免维护两份插件源码；修改插件后再次执行。

Android 调试时，先制作包含本插件的自定义基座，再运行：

```sh
npm run android:check
npm run android:run
```

多台手机连接时使用 `npm run android:run -- --device 设备序列号`。脚本检查真实 AppID、SDK 文件、基座版本与包名、原生相机类、动态库、未压缩模型，以及手机 API/ABI；安装后使用“已安装自定义基座”运行，不使用标准基座。手机弹出的安装确认仍需允许。完整步骤见 [Android 调试指南](docs/BUILDING.md#android)。

集成到已有工程时，复制**安装完成后的** `uni_modules/HelloFace-Verify`。Android 宿主还需合并下面的模型打包配置：

```json
// uni-app：manifest.json -> app-plus -> distribute -> android
{ "minSdkVersion": 23, "aaptOptions": ["noCompress 'bphfm'"], "abiFilters": ["arm64-v8a", "armeabi-v7a"] }
// uni-app x 5.34：manifest.json -> app-android -> distribute
{ "minSdkVersion": 23, "aaptOptions": ["noCompress 'bphfm'"], "abiFilters": ["arm64-v8a", "armeabi-v7a"] }
```

离线原生打包时也要在宿主 Android 模块设置 `androidResources.noCompress += "bphfm"`。iOS 两个 xcframework 必须一同集成。相机用途描述和鸿蒙相机权限已放在插件对应平台的清单中。

## 最小调用

```js
import { enrollFace, verifyFace, cancel } from '@/uni_modules/HelloFace-Verify'

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

uvue 从同一插件入口导入 API 和 `FaceResult` 类型，示例见 `examples/uni-app-x/pages/index/index.uvue`。按官方要求，通过 `@/uni_modules/HelloFace-Verify` 引用插件，页面不直接导入 `utssdk` 内部文件。

## API 参考

插件提供 `enrollFace`、`verifyFace`、`getFaceFeature`、`setFaceFeature`、`deleteFace`、`cancel` 六个接口。完整参数、回调结果、错误码与特征同步约定统一维护在 [API 参考](docs/API.md)。

## 开发与验证

```sh
npm ci --ignore-scripts
npm test                  # API 契约和 SDK 安装器测试
npm run sdk:check         # 原生 SDK 文件完整性
npm run uts:check         # 调用 HBuilderX 编译器转换三端 UTS
```

也可运行 `npm run check` 顺序执行以上三项检查。它们不生成 APK / IPA / APP 安装包。

API 测试使用 HBuilderX 自带 TypeScript（可设置 `HBUILDERX_PATH` 指向 `Contents/HBuilderX`），也可安装项目的开发依赖后运行 `npm test`。这些测试验证 UTS API 参数与回调契约，不模拟人脸识别成功。原生编译和待执行的真机用例记录在 [docs/VALIDATION.md](docs/VALIDATION.md)。

## 规范与许可

实现参考 DCloud 当前官方文档：[UTS API 插件](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-plugin.html)、[原生混编](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-plugin-hybrid.html)、[鸿蒙插件配置](https://doc.dcloud.net.cn/uni-app-x/plugin/uts-for-harmony.html)、[UTSHarmony](https://doc.dcloud.net.cn/uni-app-x/uts/utsharmony.html)。参考插件 [FaceAISDK-Core](https://ext.dcloud.net.cn/plugin?name=FaceAISDK-Core) 的 1:1 使用场景，API 并非旧版本的兼容替代。

The wrapper and example code are provided for technical exchange and evaluation purposes only. See [LICENSE](LICENSE). The native SDK, models, and resources remain subject to the upstream `Hello Face Test Only` terms. Upstream currently states that its models are not intended for children under 12 or financial use.
