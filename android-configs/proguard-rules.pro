# 本地原生宿主开启 R8 时，通过 proguardFiles 引用本文件。
# HBuilderX 的 JS 原生混淆不是 R8，也不会自动读取本目录。
# UTS/JS 桥接按名称访问模块入口；只保留本插件，不保留整个应用或整个 SDK。
-keep class uts.sdk.modules.HelloFaceVerify.** { *; }
# SDK AAR 已包含 JNI consumer rules，宿主需按正常 Gradle 依赖引入 AAR。
