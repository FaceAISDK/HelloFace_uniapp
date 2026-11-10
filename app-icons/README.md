# HiFaceUni 应用图标

两套示例的 Android、iOS、HarmonyOS 应用图标共用此目录的母版。此配置属于示例宿主，不修改集成插件的其他应用图标。

- `HiFaceUni.png`：1024×1024、不透明 PNG 母版，原图主体上方增加红色小字 `HiFaceUni`。
- `source-original.png`：用户提供的原始图片，保留用于后续修改。
- `android/`：72、96、144、192 像素图标，保留少量边距适应启动器遮罩。
- `ios/`：iPhone/iPad 所需尺寸；App Store 图标直接使用母版，全部无透明通道。
- `harmony/`：透明边距的前景和不透明背景，供系统分层图标使用。

原图来源：[用户指定图片](https://lh3.googleusercontent.com/35AZEoV1p846Wr92Nkbegx5xFBhoa5Ia4JeT-fFx2J5e9v0_2q9ttdzhNeWqtXf925Z685NGb0UiE94HuJyhpQ)。母版通过内置 image_gen 图像编辑工具制作，完整提示词保存在 [generation-prompt.txt](generation-prompt.txt)。平台尺寸转换由本地资源脚本完成。

需要更新图标时，替换母版后在 macOS 工程根目录执行：

```sh
npm run icons:build
npm run demo:prepare
```

资源已提交，正常集成和打包不需要执行 Swift 脚本。`demo:prepare` 将此目录复制到独立 uvue 工程，副本由脚本生成，不维护第二份源文件。

图标配置位于根工程的 `app-plus.distribute.icons`、uvue 工程的 `app-android.distribute.icons` / `app-ios.distribute.icons`，以及两者的 `app-harmony.distribute.icons`。更新后需重新打包或制作基座，单独刷新页面不会更换桌面图标。
