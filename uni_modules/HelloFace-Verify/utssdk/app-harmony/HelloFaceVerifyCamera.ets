import { common } from '@kit.AbilityKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { ComponentContent, window, display, promptAction, ImmersiveMode } from '@kit.ArkUI';
import { HiFaceSdk, FaceRequest, FaceFlowListener, FaceFlowProgress, FaceFlowResult,
  FaceFlowStage, FaceFlowOutcome, FaceAction, HiFaceError, HiFaceErrorCode,
  FaceVerificationConfig, Yuv420Frame, YuvPlane, YuvColorRange, YuvColorMatrix } from 'hiface';
import { BridgeError, FaceParams, NativeData, envelope, errorEnvelope, unwrap } from './BridgeTypes';
import { ReferenceStore } from './ReferenceStore';

const CAMERA_BACKGROUND: string = '#F7F9FC';
const CAMERA_INK: string = '#19324F';
const CAMERA_MUTED: string = '#60738B';
const CAMERA_BLUE: string = '#2878EF';
const CAMERA_GREEN: string = '#28866C';
interface DialogParams { flow: CameraFlow; }

@Builder
function cameraDialog(params: DialogParams) { FaceCameraDialog({ flow: params.flow }); }

@Component
struct FaceCameraDialog {
  flow: CameraFlow | undefined = undefined;
  @State guidance: string = '请正对镜头';
  @State phase: string = '实时身份核验';
  @State warning: boolean = false;
  @State captured: boolean = false;
  @State saving: boolean = false;
  @State photo: image.PixelMap | undefined = undefined;
  @State viewportWidth: number = 360;
  @State viewportHeight: number = 640;
  private safeTop: number = 0;
  private safeBottom: number = 0;
  private safeLeft: number = 0;
  private safeRight: number = 0;
  private controller: XComponentController = new XComponentController();
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasReady: boolean = false;

  aboutToAppear(): void {
    const flow = this.flow;
    if (flow === undefined) return;
    this.safeTop = flow.safeTop; this.safeBottom = flow.safeBottom;
    this.safeLeft = flow.safeLeft; this.safeRight = flow.safeRight;
    this.viewportWidth = flow.viewportWidth; this.viewportHeight = flow.viewportHeight;
    this.phase = flow.isEnrollment() ? '第一步 · 人脸采集' : '实时身份核验';
    flow.onStatus = (guide: string, stage: string, step: number, count: number): void => {
      if (this.captured) return;
      this.guidance = guide;
      this.phase = stage === 'PERFORM_ACTION' && count > 0 ? `动作验证 · ${step}/${count}` :
        (flow.isEnrollment() ? '第一步 · 人脸采集' : '实时身份核验');
      const warning = ['MULTIPLE_FACES', 'FACE_TOO_SMALL', 'FACE_NOT_FRONTAL'].includes(stage);
      if (this.warning !== warning) { this.warning = warning; this.drawMask(); }
    };
    flow.onCapture = (value: image.PixelMap | undefined, ready: boolean): void => {
      this.photo = value; this.captured = ready; this.saving = false; this.warning = false;
      this.guidance = ready ? (value === undefined ? '未能生成预览' : '请确认人脸照片') : '请正对镜头';
      this.phase = ready ? '第二步 · 确认保存' : '第一步 · 人脸采集';
      this.drawMask();
    };
  }
  aboutToDisappear(): void { this.canvasReady = false; this.flow?.cancel(); }
  private contentLeft(): number { return this.safeLeft + 24; }
  private contentWidth(): number { return Math.max(100, this.viewportWidth - this.safeLeft - this.safeRight - 48); }
  private centerX(): number { return this.contentLeft() + this.contentWidth() / 2; }
  private titleY(): number {
    return this.safeTop + 8 + (this.viewportHeight - this.safeTop - this.safeBottom < 600 ? 55 : 70);
  }
  private circleY(): number { return this.titleY() + 104; }
  private diameter(): number {
    return Math.max(100, Math.min(this.contentWidth(), (this.viewportWidth - this.safeLeft - this.safeRight) * 0.8,
      this.viewportHeight - this.safeBottom - (this.captured ? 206 : 168) - this.circleY()));
  }
  private phaseY(): number { return this.circleY() + this.diameter() + 16; }
  private privacyY(): number { return this.viewportHeight - this.safeBottom - 49; }
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
    context.lineWidth = 1; context.strokeStyle = '#DCE6F4';
    context.beginPath(); context.arc(x, y, radius + 7, 0, Math.PI * 2); context.stroke();
    context.lineWidth = 3;
    context.strokeStyle = this.captured ? CAMERA_GREEN : (this.warning ? '#C58A27' : CAMERA_BLUE);
    context.beginPath(); context.arc(x, y, radius, 0, Math.PI * 2); context.stroke(); context.restore();
  }
  @Builder
  private CapturePhoto(photo: image.PixelMap) {
    Image(photo).objectFit(ImageFit.Cover).width(this.diameter()).height(this.diameter())
      .borderRadius(this.diameter() / 2).clip(true)
      .scale({ x: this.flow?.isFrontCamera() === false ? 1 : -1, y: 1 })
      .position({ x: this.centerX() - this.diameter() / 2, y: this.circleY() })
      .accessibilityText('已采集的人脸照片')
      .onDisAppear((): void => { this.flow?.releasePreview(photo); })
  }
  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      XComponent({ id: 'hellofaceverify-camera', type: XComponentType.SURFACE, controller: this.controller })
        .width('100%').height('100%')
        .onLoad((): void => { this.flow?.start(this.controller.getXComponentSurfaceId()); })
      if (this.captured && this.photo !== undefined) { this.CapturePhoto(this.photo) }
      Canvas(this.canvas).width('100%').height('100%').hitTestBehavior(HitTestMode.None)
        .onReady((): void => { this.canvasReady = true; this.drawMask(); })
      Button('‹', { type: ButtonType.Normal }).width(44).height(44).fontSize(32)
        .fontColor(CAMERA_INK).backgroundColor(Color.Transparent).borderRadius(22)
        .position({ x: this.safeLeft + 12, y: this.safeTop + 8 }).accessibilityText('返回')
        .enabled(!this.saving).onClick((): void => { this.flow?.cancel(); })
      Text(this.flow?.isEnrollment() === true ? '人脸录入' : '身份验证').fontSize(17).fontWeight(FontWeight.Medium)
        .fontColor(CAMERA_INK).textAlign(TextAlign.Center).width(96).height(44)
        .position({ x: this.centerX() - 48, y: this.safeTop + 8 })
      Text('● 本机处理').fontSize(11).fontColor(CAMERA_GREEN).textAlign(TextAlign.Center)
        .backgroundColor('#E8F4EF').borderRadius(13).width(76).height(25)
        .position({ x: this.contentLeft() + this.contentWidth() - 76, y: this.safeTop + 18 })
      Text(this.guidance).fontSize(25).fontWeight(FontWeight.Medium).fontColor(CAMERA_INK)
        .textAlign(TextAlign.Center).maxLines(2).width(this.contentWidth()).height(54)
        .position({ x: this.contentLeft(), y: this.titleY() })
      Text(this.saving ? '即将完成，请稍候' : (this.captured ?
        (this.photo === undefined ? '请重新采集后再确认' : '照片清晰且为本人，即可确认录入') :
        '请将面部置于圆框内，保持光线均匀')).fontSize(13).fontColor(CAMERA_MUTED)
        .textAlign(TextAlign.Center).maxLines(2).width(this.contentWidth()).height(34)
        .position({ x: this.contentLeft(), y: this.titleY() + 56 })
      Text(this.phase).fontSize(12).fontColor(CAMERA_BLUE).textAlign(TextAlign.Center)
        .backgroundColor('#EAF1FD').borderRadius(13).width(Math.min(this.contentWidth(), 176)).height(26)
        .position({ x: this.centerX() - Math.min(this.contentWidth(), 176) / 2, y: this.phaseY() })
      if (this.captured) {
        Text('确认后将加密保存人脸特征，不保存照片').fontSize(13).fontColor(CAMERA_MUTED)
          .textAlign(TextAlign.Center).maxLines(2).width(this.contentWidth()).height(36)
          .position({ x: this.contentLeft(), y: this.privacyY() - 106 })
        Row({ space: 12 }) {
          Button('重新采集', { type: ButtonType.Normal }).layoutWeight(1).height(50).borderRadius(14)
            .fontSize(15).fontColor(CAMERA_INK).backgroundColor(Color.White).border({ width: 1, color: '#DCE5F1' })
            .enabled(!this.saving).onClick((): void => { this.flow?.retake(); })
          Button(this.saving ? '正在保存…' : '确认录入', { type: ButtonType.Normal })
            .layoutWeight(1).height(50).borderRadius(14).fontSize(15).fontColor(Color.White).backgroundColor(CAMERA_BLUE)
            .enabled(!this.saving && this.photo !== undefined)
            .onClick((): void => { this.saving = true; this.guidance = '正在保存人脸基准'; this.flow?.confirm(); })
        }.width(this.contentWidth()).position({ x: this.contentLeft(), y: this.privacyY() - 64 })
      } else {
        Row() {
          Text('人脸居中').fontSize(12).fontColor(CAMERA_INK).textAlign(TextAlign.Center).layoutWeight(1)
          Divider().vertical(true).height(20).color('#E5EBF3')
          Text('光线均匀').fontSize(12).fontColor(CAMERA_INK).textAlign(TextAlign.Center).layoutWeight(1)
          Divider().vertical(true).height(20).color('#E5EBF3')
          Text('面部无遮挡').fontSize(12).fontColor(CAMERA_INK).textAlign(TextAlign.Center).layoutWeight(1)
        }.backgroundColor(Color.White).borderRadius(18).width(this.contentWidth()).height(48)
          .position({ x: this.contentLeft(), y: this.phaseY() + 39 })
      }
      Text('人脸处理在本机完成').fontSize(12).fontColor(CAMERA_MUTED).textAlign(TextAlign.Center)
        .width(this.contentWidth()).height(20).position({ x: this.contentLeft(), y: this.privacyY() })
      Text('HelloFaceVerify').fontSize(11).fontColor('#78899B').textAlign(TextAlign.Center)
        .width(this.contentWidth()).height(16).position({ x: this.contentLeft(), y: this.privacyY() + 22 })
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
  viewportWidth: number = 360;
  viewportHeight: number = 640;
  safeTop: number = 0;
  safeBottom: number = 0;
  safeLeft: number = 0;
  safeRight: number = 0;
  committing: boolean = false;
  onStatus: (value: string, stage: string, step: number, count: number) => void = (): void => {};
  onCapture: (photo: image.PixelMap | undefined, ready: boolean) => void = (): void => {};
  private readonly visibility = (event: window.WindowEventType): void => {
    if (event === window.WindowEventType.WINDOW_HIDDEN) this.cancel();
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
      this.screenTask = this.mainWindow.setWindowKeepScreenOn(true).then((): void => {
        this.changedKeepScreenOn = true;
      }, (): void => {});
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
    this.output.setPreviewRotation(this.output.getPreviewRotation(orientation), true);
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
    const actions: string[] = ['shakeHead', 'nodHead', 'blink', 'openMouth'];
    const action = value.action === undefined ? undefined : actions[value.action];
    const stage = FaceFlowStage[value.stage];
    const prompts: string[] = ['请正对镜头', '请保持画面中只有一人', '请靠近一些', '请完成提示动作', '请正对镜头', '请保持不动', '请正对镜头', '请保持稳定'];
    const actionPrompts: string[] = ['请摇摇头', '请点点头', '请眨眨眼', '请张张嘴'];
    this.onStatus(value.stage === FaceFlowStage.PERFORM_ACTION && value.action !== undefined ? actionPrompts[value.action] : prompts[value.stage],
      stage, value.stepNumber, value.stepCount);
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
          this.photo = await image.createPixelMap(value.alignedRgba, {
            size: { width: value.alignedSide, height: value.alignedSide },
            pixelFormat: image.PixelMapFormat.RGBA_8888, editable: false });
          this.previews.push(this.photo);
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
    this.ended = true; this.generation++; this.accepting = false; this.request?.cancel();
    this.shutdown().then((): void => { this.completion(response); }, (): void => { this.completion(response); });
  }
  private stopCamera(): Promise<void> {
    if (this.stopTask === undefined) this.stopTask = this.stopResources();
    return this.stopTask;
  }
  private async stopResources(): Promise<void> {
    this.accepting = false;
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
    if (this.changedKeepScreenOn) {
      try { await this.mainWindow.setWindowKeepScreenOn(this.previousKeepScreenOn); } catch (_) {}
      this.changedKeepScreenOn = false;
    }
    this.previews.slice().forEach((photo: image.PixelMap): void => { this.releasePreview(photo); });
    this.photo = undefined; this.captured = undefined;
  }
}
