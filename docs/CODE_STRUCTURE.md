# 插件代码结构与维护

## 接入侧保留什么

页面从 `@/uni_modules/HelloFace-Verify` 导入公开 API；不直接访问原生类或 `utssdk` 内部文件。插件按调用初始化 SDK 并管理相机权限、采集页面和资源，无需业务再包一层初始化或相机组件。

录入只需 `enrollFace({ faceID, success, fail, complete })`；验证只需 `verifyFace({ faceID, success, fail, complete })`。默认前置相机、阈值 0.80、开启静默活体。静默与动作独立：Demo 用两个开关展示四种组合，显式传入 `silentLiveness`，开启动作时传当前勾选的 `actions`，关闭时传空数组。保留插件默认值与阈值，录入和存储行为不受验证选项影响。

根 Vue 和独立 uvue 示例保持相同的按钮与调用顺序：每个动作直接调用 API，`begin` 拦截重复点击，`showResult / showError` 只展示结果，`finish` 在 complete 中解除忙碌。Vue/uvue Options API 的页面方法用作回调时保持页面实例绑定；uvue 的结果、错误和 complete 参数按接口声明提供类型。删除先确认，离页取消相机任务，页面不保留返回的原始生物特征。同步按钮使用内置 AI 演示基准，与录入、验证、删除共用当前 `faceID`（默认 `demo-user`），说明见 [外部基准](../demo/README.md)。

`success` 表示接口正常完成，验证必须检查 `passed === true`；2xx 未通过结果仍走 success。`complete` 只做收尾；不要在这里读取业务字段，也不要因相似度高而改写 passed。

独立活体卡片直接调用 `detectLiveness`，不传 faceID/身份基准。SDK 始终静默，因此该卡片只提供一个独立的动作开关；不复用身份验证开关，以免将“仅比对身份”误解为活体选项。两类调用共用 busy、结果回调、complete 和离页取消，结果保留提交时的模式快照；空 faceID 不显示无意义的标识行。

两类流程各自保存四种动作的勾选结果，默认眨眼、点头，按列表顺序归一化。四项在同一行显示，文字 12px，label 保留 44px 点击高度。动作开启时至少一项：最后一个已选 checkbox 禁止取消，提交前仍校验非空；关闭开关保留选择但传空数组。忙碌时锁定勾选，提交数组取副本，结果模式同时快照动作名称，后续修改不影响上次结果。

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

Demo 宿主的鸿蒙发行配置位于根目录 `harmony-configs/entry` 和 `harmony-configs/AppScope`，同步脚本只复制这两个公开目录，不复制包含证书材料的根级 build-profile。安装包的压缩、混淆和实测边界见 [安装包体积](APP_SIZE.md)。

## 异步流程的约束

调用顺序是「构造默认参数 → 创建本次分发器 → 校验 → 平台适配器 → 原生操作」。校验错误也走 fail 和 complete；三端无需各自复制此逻辑。新增 API 时，先定义类型和参数规则，再选择原生方法，保持这条路径。

原生可以多次发进度，终态只能一次。共享分发器在调用业务回调前标记 ended，避免业务重入或迟到原生事件导致重复 complete；即使 success/fail 抛异常，也通过 finally 收尾。损坏响应走 BRIDGE_ERROR，不产生伪成功。

原生录入、验证和活体页的导航标题位于返回按钮之后，同高度垂直居中；中部动态提示保持原位。不再创建“本机处理”或底部说明/品牌控件。circleExpansion 将原圆形开孔每侧扩大 7 个逻辑单位，覆盖原外圈位置；三端状态边框和录入进度弧必须沿开孔的同一圆周绘制，避免重新出现双圈。相机帧与 SDK 裁剪、阈值不参与这项布局调整。

导航标题使用返回按钮右侧的剩余宽度，单行显示并在空间不足时尾部省略，避免固定宽度在大字体时换行。返回按钮点击区域统一为 48 个逻辑单位；标题与按钮共用顶部及高度。尺寸和间距从 native-ui.json 生成，已经不再使用的旧确认页定位常量不保留。

返回箭头不使用字体字符 ‹：Android 由 Button 绘制路径，iOS 使用 CAShapeLayer，鸿蒙使用 Path，避免字体基线使字形看起来偏移。鸿蒙 Path commands 的像素坐标须通过当前 UIContext.vp2px 换算，并对汉字墨迹中心作 1vp 的图形补偿；不能仅凭按钮/标题控件边界相同便认定视觉对齐。

Demo 的所有业务接口在 `showResult / showError` 中统一 Toast 接口返回的 `msg，code: 数值`，持续 2 秒；成功、未通过和调用错误均保留底部完整结果。code 105 同样直接展示返回文案，不额外预读 getFaceStatue；离页先解除当前展示状态再取消，迟到回调和删除弹窗不能继续操作；正常调用仍由 complete 解除 busy。

原生任务标识（Android job ID、iOS activeID、鸿蒙 generation）隔离取消、重拍和下一轮操作。鸿蒙授权弹窗尚未返回时也可能取消，必须在 await 之后重新检查代次。不要只隐藏相机页面而保留旧任务。

Android 的 clearAnalyzer 不等待当前帧结束。停止送帧后在同一个分析执行器排入屏障，等 ImageProxy 的 finally 执行后，再在主线程解绑、关闭 SDK、重拍或回调；收尾期间仍占用操作槽。重复 cancel 等待同一次释放，不覆盖已经确定的终态。共享层拒绝 passed 为 true 而 outcome 非 PASSED 的矛盾响应，按 BRIDGE_ERROR 收尾。

用户确认录入后进入提交状态，不能再报告“已取消但基准已保存”。取消确认应在相机/窗口释放及操作槽归还后发出，才能在 cancel 的 success 回调立即重试。相机释放前需等待正在处理的帧；窗口常亮和可见性监听也需要恢复/解除。

采集圆框只用于实时引导。SDK 返回对齐图后，三端以居中确认弹窗显示最大 188×188 的图片，保持比例和前置显示镜像；图片不再铺满采集圆框。Android 使用独立 Dialog 窗口，iOS/鸿蒙在原生相机页内使用模态遮罩卡片，避免额外页面切换触发相机离页收尾。标题与操作栏固定，小屏只滚动中间图片和说明；预览缺失时不能确认，保存时禁止重拍/关闭。Android 关闭操作槽前也要先清理确认 Dialog，其窗口保持与相机相同的满亮策略。

三端原生相机页负责临时调高亮度及恢复。Android 在 Activity 恢复时覆盖本窗口亮度，在暂停和相机收尾时归还原值；iOS 在所在屏幕保存一次原值，失去前台或离页时恢复，恢复前台时可重新调亮；鸿蒙将窗口调亮和恢复串入 `screenTask`，避免快速取消时迟到的异步调亮覆盖恢复。原值为跟随系统时保留该策略，不把它改成固定亮度。确认/重拍期间不重新采样原值，业务 API 和 Demo 不参与这项资源管理。

三端录入圆环仅呈现 SDK `HOLD_STILL` 阶段的约 700 毫秒稳定等待，不承担识别判定。Android 使用 ValueAnimator，鸿蒙使用单调时钟，iOS 使用 Core Animation；同一阶段的重复事件不重启动画，姿态/稳定性变化、确认、重拍和离页时清理。圆环走满后由 SDK 结果决定是否展示确认照片，不得从动画回调直接保存或报告成功。

动作倒计时对齐上游 [Android FaceFlowUi](https://github.com/FaceSDKPro/HelloFace/blob/main/platforms/Android/demo/src/main/java/com/hiface/sdk/demo/ui/FaceFlowUi.java) 和 [iOS FaceActionCountdown](https://github.com/FaceSDKPro/HelloFace/blob/main/platforms/iOS/HiFaceDemo/UI/FaceActionCountdown.swift)：首次 `PERFORM_ACTION` 启动整个序列的总时限（`actionTimeoutMs × stepCount`），圆环从满圈递减，同时显示向上取整的剩余秒数。切换步骤及携带 action 的短暂丢脸/多人/距离提示不重置截止时刻；回到正脸/稳定阶段、无动作阶段、确认、重拍、取消和离页时清理。使用单调时钟，不受系统时间修改影响。三端只呈现 SDK 进度，不新增前端计时参数或进度回调，也不根据归零伪造 SDK 结果；录入原有稳定进度保持独立。

iOS 的 `HelloFaceVerifyCameraState.swift` 分离圆环阶段和退出门闩：权限拒绝/取消可能早于页面弹出动画，必须同时等弹出及资源释放完成后才能关闭页面并归还调用槽。纯状态检查不依赖 UIKit 或识别 SDK。同一生命周期状态还管理请求代次，重拍先等送帧队列中的暂停屏障，回主 actor 校验代次后才重启。相机会话的配置、帧处理、暂停和关闭均在同一串行队列；首次运行错误立即拒绝后续帧和恢复请求，实际帧按 SDK 的正偶数及长短边上限校验。SDK 错误码转换统一由 HelloFaceVerifySDKError 处理，关闭后不能再启动或处理旧帧。功能对照和验证边界见 [iOS 功能与调试](IOS_DEBUG.md)。

Android 云基座与本地联编模块的名称不同，跨文件桥接访问器上的 `@PublishedApi` 用于保持 JVM 名称稳定，不能作为无用注解删除。

## 注释与验证

注释优先解释异步边界、保存时机、平台约束和数据格式。参数与默认值统一在 `interface.uts` 描述，完整列表见 [API](API.md)；避免让 Demo 承担 SDK 内部机制的解释。

修改共享 UTS 或三端入口后执行 `npm run check`；它覆盖真实源码的参数/回调测试、SDK 完整性和三端 UTS 转换。另执行 `npm run android:uts-check` 及其 `-- --uni-app-x` 模式，检查实际 Kotlin/DEX 与桥接 ABI。Demo 修改还应使用 HBuilderX 编译对应 Vue/uvue 页面，不能仅靠 JS 替身测试推导原生编译通过。

原生修改需相应平台编译和必要真机回归。HAR 构建、UTS 转换、完整 HAP 构建与真机验收分别记录，不能互相代替。鸿蒙操作步骤见 [鸿蒙调试](HARMONY_DEBUG.md)，实际结果和限制见 [验证记录](VALIDATION.md)。

## 独立能力的复用边界

`detectLiveness` 复用原生相机页、进度、权限、取消、互斥及释放，直接启动 SDK 独立活体请求，不构造虚假基准、不读取用户存储。SDK 的该入口始终静默，动作数组只追加挑战。

`extractFaceFeature` 复用 `FaceImageImporter`，与图片同步共用输入限制和参数归一化，纯提取路径不访问基准存储；只有同步分支写入。Android 的 ReferenceStore 延迟构造，避免纯提取/活体误读存储。`getFaceStatue` 则实际只读/解密基准后返回 exists，异常继续走 fail；不创建 SDK，不返回特征，不改变存储格式。
