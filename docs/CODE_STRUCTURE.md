# 插件代码结构与维护

## 接入侧保留什么

页面从 `@/uni_modules/HelloFace-Verify` 导入公开 API；不直接访问原生类或 `utssdk` 内部文件。插件按调用初始化 SDK 并管理相机权限、采集页面和资源，无需业务再包一层初始化或相机组件。

录入只需 `enrollFace({ faceID, success, fail, complete })`；验证只需 `verifyFace({ faceID, success, fail, complete })`。默认前置相机、阈值 0.80、开启静默活体。静默与动作独立：Demo 用两个开关展示四种组合，显式传入 `silentLiveness`，按动作开关传 `actions: ['blink', 'nodHead']` 或空数组。保留插件默认值与阈值，录入和存储行为不受验证选项影响。

根 Vue 和独立 uvue 示例保持相同的按钮与调用顺序：每个动作直接调用 API，`begin` 拦截重复点击，`showResult / showError` 只展示结果，`finish` 在 complete 中解除忙碌。Vue/uvue Options API 的页面方法用作回调时保持页面实例绑定；uvue 的结果、错误和 complete 参数按接口声明提供类型。删除先确认，离页取消相机任务，页面不保留返回的原始生物特征。同步按钮使用内置 AI 演示基准，与录入、验证、删除共用当前 `faceID`（默认 `demo-user`），说明见 [外部基准](../demo/README.md)。

`success` 表示接口正常完成，验证必须检查 `passed === true`；2xx 未通过结果仍走 success。`complete` 只做收尾；不要在这里读取业务字段，也不要因相似度高而改写 passed。

## 插件分层

| 文件/目录 | 负责的内容 | 修改时的边界 |
| --- | --- | --- |
| `utssdk/interface.uts` | 公开类型、参数说明、可空字段和回调契约 | 兼容既有调用；补充说明不等于调整行为 |
| `utssdk/shared.uts` | 默认参数、统一校验、`invokeFaceMethod`、结果分发 | 三端共用；非法输入应在进入原生层前失败 |
| `utssdk/status.uts` / `unierror.uts` | code/msg、旧 errCode 和原始诊断字段 | 保留 SDK outcome/sdkCode 和旧错误码兼容性 |
| `utssdk/app-*/index.uts` | 对外 API 与平台适配器 | 只选参数构造器、回调和上下文；不复制校验规则 |
| `app-*/HelloFaceVerifyNative.*` | 原生操作互斥、路由和取消协调 | 存储与相机共用操作槽，旧结果不得结束新任务 |
| `app-*/HelloFaceVerifyCamera*` | 权限后的相机采集、SDK 调用、确认及释放 | 保存确认前不写基准，结束后不再接受旧帧 |
| `app-*/FaceImageImporter.*` | 外部图片解码、方向处理、真实 SDK 特征提取 | 导入不等于活体或身份验证；失败保留原基准 |
| `app-*/ReferenceStore.*` | 指定模型空间和 faceID 的本机基准 | 不改存储键、加密格式或覆盖语义 |
| `native-ui.json` / `HelloFaceVerifyPresentation.*` | 三端共用界面参数及其生成产物 | 修改 JSON 后执行 `npm run ui:build` |

这些路径均相对 `uni_modules/HelloFace-Verify`。插件副本 `examples/uni-app-x/uni_modules/HelloFace-Verify` 由 `npm run demo:prepare` 同步，不在副本中单独修复。

## 异步流程的约束

调用顺序是「构造默认参数 → 创建本次分发器 → 校验 → 平台适配器 → 原生操作」。校验错误也走 fail 和 complete；三端无需各自复制此逻辑。新增 API 时，先定义类型和参数规则，再选择原生方法，保持这条路径。

原生可以多次发进度，终态只能一次。共享分发器在调用业务回调前标记 ended，避免业务重入或迟到原生事件导致重复 complete；即使 success/fail 抛异常，也通过 finally 收尾。损坏响应走 BRIDGE_ERROR，不产生伪成功。

原生任务标识（Android job ID、iOS activeID、鸿蒙 generation）隔离取消、重拍和下一轮操作。鸿蒙授权弹窗尚未返回时也可能取消，必须在 await 之后重新检查代次。不要只隐藏相机页面而保留旧任务。

用户确认录入后进入提交状态，不能再报告“已取消但基准已保存”。取消确认应在相机/窗口释放及操作槽归还后发出，才能在 cancel 的 success 回调立即重试。相机释放前需等待正在处理的帧；窗口常亮和可见性监听也需要恢复/解除。

采集圆框只用于实时引导。SDK 返回对齐图后，三端以居中确认弹窗显示最大 188×188 的图片，保持比例和前置显示镜像；图片不再铺满采集圆框。Android 使用独立 Dialog 窗口，iOS/鸿蒙在原生相机页内使用模态遮罩卡片，避免额外页面切换触发相机离页收尾。标题与操作栏固定，小屏只滚动中间图片和说明；预览缺失时不能确认，保存时禁止重拍/关闭。Android 关闭操作槽前也要先清理确认 Dialog，其窗口保持与相机相同的满亮策略。

三端原生相机页负责临时调高亮度及恢复。Android 在 Activity 恢复时覆盖本窗口亮度，在暂停和相机收尾时归还原值；iOS 在所在屏幕保存一次原值，失去前台或离页时恢复，恢复前台时可重新调亮；鸿蒙将窗口调亮和恢复串入 `screenTask`，避免快速取消时迟到的异步调亮覆盖恢复。原值为跟随系统时保留该策略，不把它改成固定亮度。确认/重拍期间不重新采样原值，业务 API 和 Demo 不参与这项资源管理。

三端录入圆环仅呈现 SDK `HOLD_STILL` 阶段的约 700 毫秒稳定等待，不承担识别判定。Android 使用 ValueAnimator，鸿蒙使用单调时钟，iOS 使用 Core Animation；同一阶段的重复事件不重启动画，姿态/稳定性变化、确认、重拍和离页时清理。圆环走满后由 SDK 结果决定是否展示确认照片，不得从动画回调直接保存或报告成功。

iOS 的 `HelloFaceVerifyCameraState.swift` 分离圆环阶段和退出门闩：权限拒绝/取消可能早于页面弹出动画，必须同时等弹出及资源释放完成后才能关闭页面并归还调用槽。纯状态检查不依赖 UIKit 或识别 SDK。相机会话的配置、帧处理、暂停和关闭均在同一串行队列；关闭后不能再启动或处理旧帧。功能对照和验证边界见 [iOS 功能与调试](IOS_DEBUG.md)。

Android 云基座与本地联编模块的名称不同，跨文件桥接访问器上的 `@PublishedApi` 用于保持 JVM 名称稳定，不能作为无用注解删除。

## 注释与验证

注释优先解释异步边界、保存时机、平台约束和数据格式。参数与默认值统一在 `interface.uts` 描述，完整列表见 [API](API.md)；避免让 Demo 承担 SDK 内部机制的解释。

修改共享 UTS 或三端入口后执行 `npm run check`；它覆盖真实源码的参数/回调测试、SDK 完整性和三端 UTS 转换。另执行 `npm run android:uts-check` 及其 `-- --uni-app-x` 模式，检查实际 Kotlin/DEX 与桥接 ABI。Demo 修改还应使用 HBuilderX 编译对应 Vue/uvue 页面，不能仅靠 JS 替身测试推导原生编译通过。

原生修改需相应平台编译和必要真机回归。HAR 构建、UTS 转换、完整 HAP 构建与真机验收分别记录，不能互相代替。鸿蒙操作步骤见 [鸿蒙调试](HARMONY_DEBUG.md)，实际结果和限制见 [验证记录](VALIDATION.md)。

## 独立能力的复用边界

`detectLiveness` 复用原生相机页、进度、权限、取消、互斥及释放，直接启动 SDK 独立活体请求，不构造虚假基准、不读取用户存储。SDK 的该入口始终静默，动作数组只追加挑战。

`extractFaceFeature` 复用 `FaceImageImporter`，与图片同步共用输入限制和参数归一化，纯提取路径不访问基准存储；只有同步分支写入。Android 的 ReferenceStore 延迟构造，避免纯提取/活体误读存储。`getFaceStatue` 则实际只读/解密基准后返回 exists，异常继续走 fail；不创建 SDK，不返回特征，不改变存储格式。
