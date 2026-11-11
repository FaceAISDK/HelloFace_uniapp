import { common } from '@kit.AbilityKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { systemDateTime } from '@kit.BasicServicesKit';
import { ComponentContent, window, display, promptAction, ImmersiveMode } from '@kit.ArkUI';
import { HiFaceSdk, FaceRequest, FaceFlowListener, FaceFlowProgress, FaceFlowResult,
  FaceFlowStage, FaceFlowOutcome, FaceAction, HiFaceError, HiFaceErrorCode,
  FaceVerificationConfig, Yuv420Frame, YuvPlane, YuvColorRange, YuvColorMatrix } from 'hiface';
import { BridgeError, FaceParams, NativeData, envelope, errorEnvelope, unwrap } from './BridgeTypes';
import { ReferenceStore } from './ReferenceStore';
import { HelloFaceVerifyPresentation as UI } from './HelloFaceVerifyPresentation';

const CAMERA_BACKGROUND: string = UI.colorBackground;
const CAMERA_INK: string = UI.colorInk;
const CAMERA_MUTED: string = UI.colorMuted;
const CAMERA_BLUE: string = UI.colorBlue;
const CAMERA_GREEN: string = UI.colorGreen;
// 与 SDK 0.8.11 的引导录入稳定窗口及原生 Demo 一致，仅用于视觉提示。
const CAPTURE_HOLD_MILLIS: number = 700;
const CAPTURE_PROGRESS_INTERVAL_MILLIS: number = 33;
interface DialogParams { flow: CameraFlow; }

@Builder
function cameraDialog(params: DialogParams) { FaceCameraDialog({ flow: params.flow }); }

@Component
struct FaceCameraDialog {
  flow: CameraFlow | undefined = undefined;
  @State guidance: string = UI.liveTitle;
  @State phase: string = UI.verifyPhase;
  @State warning: boolean = false;
  @State captured: boolean = false;
  @State saving: boolean = false;
  @State photo: image.PixelMap | undefined = undefined;
  @State viewportWidth: number = 360;
  @State viewportHeight: number = 640;
  @State previewRatio: number = 3 / 4;
  private safeTop: number = 0;
  private safeBottom: number = 0;
  private safeLeft: number = 0;
  private safeRight: number = 0;
  private controller: XComponentController = new XComponentController();
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasReady: boolean = false;
  private visible: boolean = false;
  private captureProgress: number = 0;
  private captureStartedAt: number = -1;
  private captureTimer: number = -1;

  aboutToAppear(): void {
    this.visible = true;
    const flow = this.flow;
    if (flow === undefined) return;
    this.safeTop = flow.safeTop; this.safeBottom = flow.safeBottom;
    this.safeLeft = flow.safeLeft; this.safeRight = flow.safeRight;
    this.viewportWidth = flow.viewportWidth; this.viewportHeight = flow.viewportHeight;
    this.phase = UI.phase(flow.isEnrollment());
    flow.onPreviewSize = (width: number, height: number): void => { this.previewRatio = width / height; };
    flow.onStatus = (stage: string, action: string | undefined, step: number, count: number): void => {
      if (!this.visible || this.captured) return;
      this.guidance = UI.guidance(stage, action);
      this.phase = UI.phase(flow.isEnrollment(), stage, step, count);
      this.warning = UI.isWarning(stage);
      this.updateCaptureProgress(stage);
      this.drawMask();
    };
    flow.onCapture = (value: image.PixelMap | undefined, ready: boolean): void => {
      if (!this.visible) return;
      this.resetCaptureProgress();
      this.photo = value; this.captured = ready; this.saving = false; this.warning = false;
      this.guidance = ready ? (value === undefined ? UI.missingTitle : UI.confirmTitle) : UI.liveTitle;
      this.phase = ready ? UI.confirmPhase : UI.phase(flow.isEnrollment());
      this.drawMask();
    };
  }
  aboutToDisappear(): void {
    this.visible = false; this.canvasReady = false;
    this.resetCaptureProgress(); this.flow?.cancel();
  }
  private contentLeft(): number { return this.safeLeft + UI.sideInset; }
  private contentWidth(): number { return Math.max(UI.minCircle, this.viewportWidth - this.safeLeft - this.safeRight - UI.sideInset * 2); }
  private centerX(): number { return this.contentLeft() + this.contentWidth() / 2; }
  private titleY(): number {
    return this.safeTop + UI.headerInset + (this.viewportHeight - this.safeTop - this.safeBottom < UI.compactHeight ? UI.compactTitleOffset : UI.titleOffset);
  }
  private circleY(): number { return this.titleY() + UI.circleOffset; }
  private diameter(): number {
    return Math.max(UI.minCircle, Math.min(this.contentWidth(), (this.viewportWidth - this.safeLeft - this.safeRight) * UI.circleRatio,
      this.viewportHeight - this.safeBottom - UI.liveReserve - this.circleY()));
  }
  private phaseY(): number { return this.circleY() + this.diameter() + UI.phaseOffset; }
  private privacyY(): number { return this.viewportHeight - this.safeBottom - UI.footerInset; }
  private previewWidth(): number { return Math.min(this.viewportWidth, this.viewportHeight * this.previewRatio); }
  private previewHeight(): number { return this.previewWidth() / this.previewRatio; }
  private updateCaptureProgress(stage: string): void {
    if (this.flow?.isEnrollment() !== true || stage !== 'HOLD_STILL') {
      this.resetCaptureProgress(); return;
    }
    // 同一稳定阶段的重复回调不能重启计时；偏头、晃动或丢脸后重新累计。
    if (this.captureStartedAt >= 0) return;
    this.captureStartedAt = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP);
    this.captureTimer = setInterval((): void => {
      if (!this.visible || this.captured) { this.resetCaptureProgress(); return; }
      const elapsed = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP) - this.captureStartedAt;
      this.captureProgress = Math.min(1, Math.max(0, elapsed / CAPTURE_HOLD_MILLIS));
      this.drawMask();
      if (this.captureProgress >= 1) {
        clearInterval(this.captureTimer); this.captureTimer = -1;
        // 圆环走满只表示稳定等待提示结束，确认页仍由 SDK 的结果回调触发。
      }
    }, CAPTURE_PROGRESS_INTERVAL_MILLIS);
  }
  private resetCaptureProgress(): void {
    if (this.captureTimer >= 0) clearInterval(this.captureTimer);
    this.captureTimer = -1; this.captureStartedAt = -1; this.captureProgress = 0;
  }
  private drawMask(): void {
    if (!this.canvasReady) return;
    const context = this.canvas; const radius = this.diameter() / 2;
    const x = this.centerX(); const y = this.circleY() + radius;
    context.clearRect(0, 0, this.viewportWidth, this.viewportHeight);
    context.save(); context.fillStyle = CAMERA_BACKGROUND;
    context.fillRect(0, 0, this.viewportWidth, this.viewportHeight);
    context.globalCompositeOperation = 'destination-out';
    context.beginPath(); context.arc(x, y, radius, 0, Math.PI * 2); context.fill();
    context.globalCompositeOperation = 'source-over';
    context.lineWidth = UI.borderWidth; context.strokeStyle = UI.colorOuterRing;
    context.beginPath(); context.arc(x, y, radius + UI.outerRingGap, 0, Math.PI * 2); context.stroke();
    context.lineWidth = UI.ringWidth;
    const enrollment = this.flow?.isEnrollment() === true;
    context.strokeStyle = this.captured ? CAMERA_GREEN : (this.warning ? UI.colorAmber :
      (enrollment ? UI.colorOuterRing : CAMERA_BLUE));
    context.beginPath(); context.arc(x, y, radius, 0, Math.PI * 2); context.stroke();
    if (enrollment && !this.captured && !this.warning && this.captureProgress > 0) {
      context.lineWidth = UI.ringWidth + 1; context.lineCap = 'round'; context.strokeStyle = CAMERA_BLUE;
      context.beginPath(); context.arc(x, y, radius, -Math.PI / 2,
        -Math.PI / 2 + Math.PI * 2 * this.captureProgress); context.stroke();
    }
    context.restore();
  }
  @Builder
  private CapturePhoto(photo: image.PixelMap) {
    Image(photo).objectFit(ImageFit.Contain).backgroundColor(CAMERA_BACKGROUND)
      .width(this.confirmationPhotoSide()).height(this.confirmationPhotoSide())
      .borderRadius(UI.dialogPhotoRadius).clip(true)
      .scale({ x: this.flow?.isFrontCamera() === false ? 1 : -1, y: 1 })
      .accessibilityText(UI.photoLabel)
      .onDisAppear((): void => { this.flow?.releasePreview(photo); })
  }
  private confirmationWidth(): number {
    return Math.max(1, Math.min(UI.dialogMaxWidth, this.viewportWidth - this.safeLeft - this.safeRight - UI.dialogInset * 2));
  }
  private confirmationPhotoSide(): number {
    return Math.max(1, Math.min(UI.dialogPhotoSide, this.confirmationWidth() - UI.dialogPadding * 2));
  }
  private confirmationBodyHeight(): number {
    const photoHeight = this.photo === undefined ? 0 : this.confirmationPhotoSide() + UI.dialogGap;
    const content = photoHeight + UI.detailHeight + UI.dialogGap + UI.confirmationHeight;
    const available = this.viewportHeight - this.safeTop - this.safeBottom - UI.dialogInset * 2 - UI.dialogPadding * 2 -
      UI.dialogHeadingHeight - UI.dialogGap * 2 - UI.buttonHeight;
    return Math.min(content, Math.max(1, available));
  }
  @Builder
  private ConfirmationDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor(Color.Black).opacity(UI.dialogScrimAlpha).onClick((): void => {})
      Column({ space: UI.dialogGap }) {
        Row() {
          Text(this.saving ? UI.savingTitle : (this.photo === undefined ? UI.missingTitle : UI.confirmTitle))
            .fontSize(UI.fontDialogHeading).fontWeight(FontWeight.Medium).fontColor(CAMERA_INK).layoutWeight(1).maxLines(2)
            .textAlign(TextAlign.Start)
          Button('×', { type: ButtonType.Normal }).width(UI.dialogCloseSize).height(UI.dialogCloseSize)
            .padding(0)
            .fontSize(UI.fontDialogClose).fontColor(CAMERA_INK).backgroundColor(Color.Transparent).accessibilityText(UI.cancelCapture)
            .enabled(!this.saving).opacity(this.saving ? UI.disabledAlpha : 1)
            .onClick((): void => { this.flow?.cancel(); })
        }.width('100%').height(UI.dialogHeadingHeight)
        Scroll() {
          Column({ space: UI.dialogGap }) {
            if (this.photo !== undefined) { this.CapturePhoto(this.photo) }
            Text(this.saving ? UI.savingDetail : (this.photo === undefined ? UI.missingDetail : UI.confirmDetail))
              .fontSize(UI.fontDetail).fontColor(CAMERA_MUTED).textAlign(TextAlign.Center).width('100%').height(UI.detailHeight).maxLines(2)
            Text(UI.confirmation).fontSize(UI.fontConfirmation).fontColor(CAMERA_MUTED)
              .textAlign(TextAlign.Center).width('100%').height(UI.confirmationHeight).maxLines(2)
          }.width('100%')
        }.width('100%').height(this.confirmationBodyHeight()).scrollBar(BarState.Auto)
        Row({ space: UI.buttonGap }) {
          Button(UI.retake, { type: ButtonType.Normal }).layoutWeight(1).height(UI.buttonHeight)
            .fontSize(UI.fontButton).fontWeight(FontWeight.Medium).fontColor(CAMERA_INK).backgroundColor(Color.White)
            .border({ width: UI.borderWidth, color: UI.colorButtonBorder })
            .borderRadius(UI.buttonRadius)
            .enabled(!this.saving).opacity(this.saving ? UI.disabledAlpha : 1).onClick((): void => { this.flow?.retake(); })
          Button(this.saving ? UI.savingButton : UI.confirm, { type: ButtonType.Normal }).layoutWeight(1)
            .height(UI.buttonHeight).borderRadius(UI.buttonRadius).fontSize(UI.fontButton).fontWeight(FontWeight.Medium)
            .fontColor(Color.White).backgroundColor(CAMERA_BLUE).enabled(!this.saving && this.photo !== undefined)
            .opacity(this.saving || this.photo === undefined ? UI.disabledAlpha : 1)
            .onClick((): void => { this.saving = true; this.flow?.confirm(); })
        }.width('100%')
      }.width(this.confirmationWidth()).padding(UI.dialogPadding).backgroundColor(Color.White).borderRadius(UI.dialogRadius)
        .translate({ x: (this.safeLeft - this.safeRight) / 2, y: (this.safeTop - this.safeBottom) / 2 })
    }.width('100%').height('100%')
  }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      XComponent({ id: 'hellofaceverify-camera', type: XComponentType.SURFACE, controller: this.controller })
        .width(this.previewWidth()).height(this.previewHeight())
        .position({ x: (this.viewportWidth - this.previewWidth()) / 2, y: (this.viewportHeight - this.previewHeight()) / 2 })
        .renderFit(RenderFit.RESIZE_CONTAIN)
        .onLoad((): void => {
          this.controller.setXComponentSurfaceRotation({ lock: true });
          this.flow?.start(this.controller.getXComponentSurfaceId());
        })
      Canvas(this.canvas).width('100%').height('100%').hitTestBehavior(HitTestMode.None)
        .onReady((): void => { this.canvasReady = true; this.drawMask(); })
      Button('‹', { type: ButtonType.Normal }).width(UI.backSize).height(UI.backSize).fontSize(UI.fontBack)
        .fontColor(CAMERA_INK).backgroundColor(Color.Transparent).borderRadius(UI.backSize / 2)
        .position({ x: this.safeLeft + UI.backInset, y: this.safeTop + UI.headerInset }).accessibilityText(UI.backLabel)
        .opacity(this.saving ? UI.disabledAlpha : 1).enabled(!this.saving).onClick((): void => { this.flow?.cancel(); })
      Text(this.flow?.isEnrollment() === true ? UI.enrollHeading : UI.verifyHeading).fontSize(UI.fontHeading).fontWeight(FontWeight.Medium)
        .fontColor(CAMERA_INK).textAlign(TextAlign.Center).width(UI.headingWidth).height(UI.backSize)
        .position({ x: this.centerX() - UI.headingWidth / 2, y: this.safeTop + UI.headerInset })
      Text(UI.localLabel).fontSize(UI.fontLocal).fontColor(CAMERA_GREEN).textAlign(TextAlign.Center)
        .backgroundColor(UI.colorLocalFill).borderRadius(UI.pillRadius).width(UI.localWidth).height(UI.localHeight)
        .position({ x: this.contentLeft() + this.contentWidth() - UI.localWidth, y: this.safeTop + UI.headerInset + UI.localOffset })
      Text(this.saving ? UI.savingTitle : this.guidance).fontSize(UI.fontTitle).fontWeight(FontWeight.Medium).fontColor(CAMERA_INK)
        .textAlign(TextAlign.Center).maxLines(2).width(this.contentWidth()).height(UI.titleHeight)
        .position({ x: this.contentLeft(), y: this.titleY() })
      Text(this.saving ? UI.savingDetail : (this.captured ?
        (this.photo === undefined ? UI.missingDetail : UI.confirmDetail) :
        UI.liveDetail)).fontSize(UI.fontDetail).fontColor(CAMERA_MUTED)
        .textAlign(TextAlign.Center).maxLines(2).width(this.contentWidth()).height(UI.detailHeight)
        .position({ x: this.contentLeft(), y: this.titleY() + UI.detailOffset })
      Text(this.phase).fontSize(UI.fontPhase).fontColor(CAMERA_BLUE).textAlign(TextAlign.Center)
        .backgroundColor(UI.colorPhaseFill).borderRadius(UI.pillRadius).width(Math.min(this.contentWidth(), UI.phaseWidth)).height(UI.phaseHeight)
        .position({ x: this.centerX() - Math.min(this.contentWidth(), UI.phaseWidth) / 2, y: this.phaseY() })
      if (!this.captured) {
        Row() {
          Text(UI.tipCenter).fontSize(UI.fontTip).fontColor(CAMERA_INK).textAlign(TextAlign.Center).layoutWeight(1)
          Divider().vertical(true).height(UI.dividerHeight).color(UI.colorDivider)
          Text(UI.tipLight).fontSize(UI.fontTip).fontColor(CAMERA_INK).textAlign(TextAlign.Center).layoutWeight(1)
          Divider().vertical(true).height(UI.dividerHeight).color(UI.colorDivider)
          Text(UI.tipClear).fontSize(UI.fontTip).fontColor(CAMERA_INK).textAlign(TextAlign.Center).layoutWeight(1)
        }.backgroundColor(Color.White).borderRadius(UI.tipsRadius).width(this.contentWidth()).height(UI.tipsHeight)
          .position({ x: this.contentLeft(), y: this.phaseY() + UI.tipsOffset })
      }
      Text(UI.privacy).fontSize(UI.fontPrivacy).fontColor(CAMERA_MUTED).textAlign(TextAlign.Center)
        .width(this.contentWidth()).height(UI.privacyHeight).position({ x: this.contentLeft(), y: this.privacyY() })
      Text(UI.brand).fontSize(UI.fontBrand).fontColor(UI.colorBrand).textAlign(TextAlign.Center)
        .width(this.contentWidth()).height(UI.brandHeight).position({ x: this.contentLeft(), y: this.privacyY() + UI.brandOffset })
      if (this.captured) { this.ConfirmationDialog() }
    }.width('100%').height('100%').backgroundColor(CAMERA_BACKGROUND)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .onAreaChange((_, area): void => {
        this.viewportWidth = Number.parseFloat(`${area.width}`); this.viewportHeight = Number.parseFloat(`${area.height}`);
        this.drawMask();
      })
  }
}

export class CameraFlow {
  private readonly context: common.UIAbilityContext;
  private readonly mainWindow: window.Window;
  private readonly sdk: HiFaceSdk;
  private readonly method: string;
  private readonly params: FaceParams;
  private readonly reference: string | undefined;
  private readonly progressCallback: (value: string) => void;
  private readonly completion: (value: string) => void;
  private dialog: ComponentContent<DialogParams> | undefined = undefined;
  private session: camera.VideoSession | undefined = undefined;
  private input: camera.CameraInput | undefined = undefined;
  private output: camera.PreviewOutput | undefined = undefined;
  private analysis: camera.PreviewOutput | undefined = undefined;
  private receiver: image.ImageReceiver | undefined = undefined;
  private request: FaceRequest | undefined = undefined;
  private startup: Promise<void> = Promise.resolve();
  private frameTask: Promise<void> | undefined = undefined;
  private needFrame: boolean = false;
  private accepting: boolean = false;
  private ended: boolean = false;
  private rotation: number = 0;
  private captured: FaceFlowResult | undefined = undefined;
  private photo: image.PixelMap | undefined = undefined;
  private stopTask: Promise<void> | undefined = undefined;
  private surfaceID: string = '';
  private generation: number = 0;
  private restarting: boolean = false;
  private previews: image.PixelMap[] = [];
  private screenTask: Promise<void> = Promise.resolve();
  private previousKeepScreenOn: boolean = false;
  private changedKeepScreenOn: boolean = false;
  private previousBrightness: number = -1;
  private changedBrightness: boolean = false;
  viewportWidth: number = 360;
  viewportHeight: number = 640;
  safeTop: number = 0;
  safeBottom: number = 0;
  safeLeft: number = 0;
  safeRight: number = 0;
  committing: boolean = false;
  onStatus: (stage: string, action: string | undefined, step: number, count: number) => void = (): void => {};
  onCapture: (photo: image.PixelMap | undefined, ready: boolean) => void = (): void => {};
  onPreviewSize: (width: number, height: number) => void = (): void => {};
  private readonly visibility = (event: window.WindowEventType): void => {
    if (event === window.WindowEventType.WINDOW_HIDDEN) {
      this.restoreScreen(); this.cancel();
    }
  };

  constructor(context: common.UIAbilityContext, mainWindow: window.Window, sdk: HiFaceSdk, method: string,
    params: FaceParams, reference: string | undefined, progress: (value: string) => void, completion: (value: string) => void) {
    this.context = context; this.mainWindow = mainWindow; this.sdk = sdk; this.method = method;
    this.params = params; this.reference = reference; this.progressCallback = progress; this.completion = completion;
  }
  open(): void {
    try {
      this.mainWindow.on('windowEvent', this.visibility);
      const ui = this.mainWindow.getUIContext();
      const properties = this.mainWindow.getWindowProperties();
      this.viewportWidth = ui.px2vp(properties.windowRect.width);
      this.viewportHeight = ui.px2vp(properties.windowRect.height);
      const bars = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navigation = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.safeTop = ui.px2vp(bars.topRect.height);
      this.safeBottom = ui.px2vp(Math.max(bars.bottomRect.height, navigation.bottomRect.height));
      this.safeLeft = ui.px2vp(bars.leftRect.width); this.safeRight = ui.px2vp(bars.rightRect.width);
      this.previousKeepScreenOn = properties.isKeepScreenOn;
      this.previousBrightness = properties.brightness;
      this.screenTask = this.prepareScreen();
      const params: DialogParams = { flow: this };
      this.dialog = new ComponentContent<DialogParams>(ui, wrapBuilder(cameraDialog), params);
      const options: promptAction.BaseDialogOptions = { autoCancel: false, alignment: DialogAlignment.Center,
        maskColor: Color.Transparent, immersiveMode: ImmersiveMode.EXTEND,
        onWillDismiss: (_: DismissDialogAction): void => { this.cancel(); } };
      ui.getPromptAction().openCustomDialog(this.dialog, options).catch((error: Error): void => { this.fail(error); });
    } catch (error) { this.fail(new BridgeError('CAMERA_ERROR', String(error))); }
  }
  start(surfaceID: string): void {
    if (this.ended) return;
    this.surfaceID = surfaceID;
    this.startup = this.setup(surfaceID).catch((error: Error): void => { this.fail(error); });
  }
  isEnrollment(): boolean { return this.method === 'enrollFace'; }
  isFrontCamera(): boolean { return this.params.camera !== 'back'; }
  private async prepareScreen(): Promise<void> {
    try { await this.mainWindow.setWindowKeepScreenOn(true); this.changedKeepScreenOn = true; } catch (_) {}
    if (this.ended) return;
    try { await this.mainWindow.setWindowBrightness(1); this.changedBrightness = true; } catch (_) {}
  }
  private restoreScreen(): Promise<void> {
    // 与进入时的异步设置串行，快速取消也要等“调亮”完成后再恢复，防止迟到操作覆盖原值。
    this.screenTask = this.screenTask.then(async (): Promise<void> => {
      if (this.changedBrightness) {
        try { await this.mainWindow.setWindowBrightness(this.previousBrightness); this.changedBrightness = false; } catch (_) {}
      }
      if (this.changedKeepScreenOn) {
        try { await this.mainWindow.setWindowKeepScreenOn(this.previousKeepScreenOn); this.changedKeepScreenOn = false; } catch (_) {}
      }
    });
    return this.screenTask;
  }
  private checkActive(): void { if (this.ended) throw new BridgeError('CANCELLED', 'Camera closed'); }
  private async setup(surfaceID: string): Promise<void> {
    const attempt = ++this.generation;
    await this.screenTask; this.checkActive();
    unwrap(await this.sdk.whenReady()); this.checkActive();
    const listener: FaceFlowListener = {
      onProgress: (value: FaceFlowProgress): void => { if (this.generation === attempt) this.progress(value); },
      onResult: (value: FaceFlowResult): void => { if (this.generation === attempt) this.result(value); },
      onError: (error: HiFaceError): void => {
        if (this.generation === attempt) this.fail(new BridgeError(HiFaceErrorCode[error.code], error.message));
      }
    };
    if (this.method === 'enrollFace') {
      this.request = unwrap(await this.sdk.capture().startCameraCapture(listener));
    } else {
      const actions: FaceAction[] = (this.params.actions ?? []).map((value: string): FaceAction => {
        if (value === 'blink') return FaceAction.BLINK;
        if (value === 'openMouth') return FaceAction.MOUTH_OPEN;
        if (value === 'shakeHead') return FaceAction.SHAKE_HEAD;
        return FaceAction.NOD_HEAD;
      });
      const config = new FaceVerificationConfig(this.reference ?? '', this.params.threshold ?? 0.80,
        this.params.silentLiveness ?? true, actions, this.params.actionTimeoutMs ?? 10000,
        this.params.faceTimeoutMs ?? 15000, false);
      this.request = unwrap(await this.sdk.verification().startCameraVerification(config, listener));
    }
    this.checkActive();
    const manager = camera.getCameraManager(this.context);
    const position = this.params.camera === 'back' ? camera.CameraPosition.CAMERA_POSITION_BACK : camera.CameraPosition.CAMERA_POSITION_FRONT;
    const device = manager.getSupportedCameras().find((value: camera.CameraDevice): boolean => value.cameraPosition === position);
    if (device === undefined) throw new BridgeError('CAMERA_ERROR', 'Requested camera is unavailable');
    const profiles = manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_VIDEO).previewProfiles
      .filter((value: camera.Profile): boolean => value.format === camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP &&
        value.size.width % 2 === 0 && value.size.height % 2 === 0 &&
        Math.max(value.size.width, value.size.height) <= 1920 && Math.min(value.size.width, value.size.height) <= 1080);
    profiles.sort((left: camera.Profile, right: camera.Profile): number =>
      Math.abs(left.size.width * left.size.height - 640 * 480) - Math.abs(right.size.width * right.size.height - 640 * 480));
    if (profiles.length === 0) throw new BridgeError('CAMERA_ERROR', 'No SDK-compatible NV21 camera profile');
    const profile = profiles[0];
    this.receiver = image.createImageReceiver(profile.size, image.ImageFormat.JPEG, 3);
    this.receiver.on('imageArrival', (): void => { this.accept(); });
    const analysisSurface = await this.receiver.getReceivingSurfaceId(); this.checkActive();
    this.input = manager.createCameraInput(device);
    await this.input.open(); this.checkActive();
    this.output = manager.createPreviewOutput(profile, surfaceID);
    this.analysis = manager.createPreviewOutput(profile, analysisSurface);
    this.session = manager.createSession<camera.VideoSession>(camera.SceneMode.NORMAL_VIDEO);
    this.input.on('error', device, (): void => {
      if (this.generation === attempt) this.fail(new BridgeError('CAMERA_ERROR', 'Camera input interrupted'));
    });
    this.session.on('error', (): void => {
      if (this.generation === attempt) this.fail(new BridgeError('CAMERA_ERROR', 'Camera session interrupted'));
    });
    this.output.on('error', (): void => {
      if (this.generation === attempt) this.fail(new BridgeError('CAMERA_ERROR', 'Camera preview interrupted'));
    });
    this.analysis.on('error', (): void => {
      if (this.generation === attempt) this.fail(new BridgeError('CAMERA_ERROR', 'Camera analysis interrupted'));
    });
    this.session.beginConfig();
    this.session.addInput(this.input); this.session.addOutput(this.output); this.session.addOutput(this.analysis);
    await this.session.commitConfig(); this.checkActive();
    const orientation = display.getDefaultDisplaySync().rotation;
    const previewRotation = this.output.getPreviewRotation(orientation);
    this.output.setPreviewRotation(previewRotation, true);
    const swapped = previewRotation === camera.ImageRotation.ROTATION_90 || previewRotation === camera.ImageRotation.ROTATION_270;
    this.onPreviewSize(swapped ? profile.size.height : profile.size.width, swapped ? profile.size.width : profile.size.height);
    this.rotation = this.analysis.getPreviewRotation(orientation);
    this.accepting = true;
    await this.session.start(); this.checkActive();
  }
  private accept(): void {
    if (!this.accepting || this.ended) return;
    this.needFrame = true;
    if (this.frameTask !== undefined) return;
    const task = this.consume(); this.frameTask = task;
    task.then((): void => {
      this.frameTask = undefined;
      if (this.needFrame && this.accepting && !this.ended) this.accept();
    }, (error: Error): void => { this.frameTask = undefined; this.fail(error); });
  }
  private async consume(): Promise<void> {
    while (this.needFrame && this.accepting && !this.ended && this.receiver !== undefined) {
      this.needFrame = false;
      const source = await this.receiver.readLatestImage();
      if (source === undefined) continue;
      let frame: Yuv420Frame;
      try {
        if (source.format !== 25) throw new BridgeError('CAMERA_ERROR', 'Expected NV21 camera buffers');
        const component = await source.getComponent(image.ComponentType.JPEG);
        const width = source.size.width; const height = source.size.height;
        const stride = component.rowStride;
        const yBytes = stride * height;
        const chromaBytes = stride * (height / 2 - 1) + width;
        const bytes = component.byteBuffer;
        if (stride < width || bytes.byteLength < yBytes + chromaBytes) throw new BridgeError('CAMERA_ERROR', 'Invalid NV21 plane layout');
        frame = new Yuv420Frame(new YuvPlane(bytes.slice(0, yBytes), stride, 1),
          new YuvPlane(bytes.slice(yBytes + 1, yBytes + chromaBytes), stride, 2),
          new YuvPlane(bytes.slice(yBytes, yBytes + chromaBytes), stride, 2),
          width, height, YuvColorRange.VIDEO, YuvColorMatrix.BT709, this.rotation, this.params.camera !== 'back');
      } finally { await source.release(); }
      if (!this.accepting || this.ended) return;
      const result = await this.sdk.processFrame(frame);
      if (result.isFailure()) {
        const code = result.requireError().code;
        if (code !== HiFaceErrorCode.NOT_READY && code !== HiFaceErrorCode.BUSY) unwrap(result);
      }
    }
  }
  private progress(value: FaceFlowProgress): void {
    if (this.ended || this.captured !== undefined) return;
    let action: string | undefined = undefined;
    switch (value.action) {
      case FaceAction.BLINK: action = 'blink'; break;
      case FaceAction.MOUTH_OPEN: action = 'openMouth'; break;
      case FaceAction.SHAKE_HEAD: action = 'shakeHead'; break;
      case FaceAction.NOD_HEAD: action = 'nodHead'; break;
    }
    const stage = FaceFlowStage[value.stage];
    this.onStatus(stage, action, value.stepNumber, value.stepCount);
    this.progressCallback(envelope('progress', 'OK', '', { stage: stage, action: action,
      stepNumber: value.stepNumber, stepCount: value.stepCount }));
  }
  private result(value: FaceFlowResult): void {
    if (this.ended || this.captured !== undefined) return;
    if (this.method === 'enrollFace' && value.isPassed() && value.feature !== undefined) {
      this.captured = value;
      this.accepting = false;
      this.stopCamera().then(async (): Promise<void> => {
        if (this.ended) return;
        if (value.alignedRgba !== undefined) {
          try {
            this.photo = await image.createPixelMap(value.alignedRgba, {
              size: { width: value.alignedSide, height: value.alignedSide },
              // SDK 提供 RGBA；省略输入格式时系统按 BGRA 读取，确认照片会红蓝互换。
              srcPixelFormat: image.PixelMapFormat.RGBA_8888,
              pixelFormat: image.PixelMapFormat.RGBA_8888, editable: false });
            this.previews.push(this.photo);
          } catch (_) {
            // Like Android/iOS: keep the confirmation screen available for a retake.
            this.photo = undefined;
          }
        }
        if (this.ended) { if (this.photo !== undefined) this.releasePreview(this.photo); return; }
        this.onCapture(this.photo, true);
      }).catch((error: Error): void => { this.fail(error); });
    } else { this.finish(envelope('result', 'OK', '', this.resultData(value))); }
  }
  retake(): void {
    if (this.ended || this.committing || this.restarting || this.captured === undefined) return;
    this.restarting = true; this.generation++;
    this.request?.cancel(); this.request = undefined;
    this.captured = undefined; this.photo = undefined;
    this.onCapture(undefined, false);
    this.startup = this.restart().catch((error: Error): void => { this.fail(error); });
  }
  private async restart(): Promise<void> {
    await this.stopCamera(); this.checkActive();
    this.stopTask = undefined; this.needFrame = false;
    await this.setup(this.surfaceID); this.restarting = false;
  }
  releasePreview(photo: image.PixelMap): void {
    const index = this.previews.indexOf(photo);
    if (index < 0) return;
    this.previews.splice(index, 1);
    if (this.photo === photo) this.photo = undefined;
    photo.release().catch((): void => {});
  }
  confirm(): void {
    if (this.ended || this.committing || this.captured?.feature === undefined) return;
    // 保存进入提交阶段后不接受取消，避免已写入基准却向业务报告“已取消”。
    this.committing = true;
    const value = this.captured;
    new ReferenceStore(this.context).save(this.params.faceID, value.feature ?? '').then((): void => {
      this.finish(envelope('result', 'OK', '', this.resultData(value)));
    }, (error: Error): void => { this.fail(error); });
  }
  cancel(): void { if (!this.committing) this.finish(envelope('error', 'CANCELLED', 'Face operation cancelled')); }
  private resultData(value: FaceFlowResult): NativeData {
    return { feature: this.method === 'enrollFace' ? value.feature : undefined, passed: value.isPassed(),
      outcome: FaceFlowOutcome[value.outcome], similarity: value.similarity, livenessScore: value.livenessScore };
  }
  private fail(error: Error): void { this.finish(errorEnvelope(error)); }
  private finish(response: string): void {
    if (this.ended) return;
    // 先屏蔽旧事件，再释放相机/窗口；释放完成后才能归还原生操作槽。
    this.ended = true; this.generation++; this.accepting = false; this.request?.cancel();
    this.restoreScreen();
    this.shutdown().then((): void => { this.completion(response); }, (): void => { this.completion(response); });
  }
  private stopCamera(): Promise<void> {
    if (this.stopTask === undefined) this.stopTask = this.stopResources();
    return this.stopTask;
  }
  private async stopResources(): Promise<void> {
    this.accepting = false;
    // 等待正在分析的帧结束后再释放输出和接收器，防止后台任务使用已释放的资源。
    try { await this.session?.stop(); } catch (_) {}
    try { await this.frameTask; } catch (_) {}
    try { await this.session?.release(); } catch (_) {}
    try { await this.output?.release(); } catch (_) {}
    try { await this.analysis?.release(); } catch (_) {}
    try { await this.input?.close(); } catch (_) {}
    try { await this.receiver?.release(); } catch (_) {}
    this.session = undefined; this.output = undefined; this.analysis = undefined;
    this.input = undefined; this.receiver = undefined; this.frameTask = undefined;
  }
  private async shutdown(): Promise<void> {
    await this.startup;
    await this.screenTask;
    await this.stopCamera();
    this.sdk.close();
    try { this.mainWindow.off('windowEvent', this.visibility); } catch (_) {}
    if (this.dialog !== undefined) {
      try { await this.mainWindow.getUIContext().getPromptAction().closeCustomDialog(this.dialog); } catch (_) {}
      this.dialog.dispose(); this.dialog = undefined;
    }
    await this.restoreScreen();
    this.previews.slice().forEach((photo: image.PixelMap): void => { this.releasePreview(photo); });
    this.photo = undefined; this.captured = undefined;
  }
}
