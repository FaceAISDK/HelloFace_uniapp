import { common } from '@kit.AbilityKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { ComponentContent, window, display, promptAction } from '@kit.ArkUI';
import { HiFaceSdk, FaceRequest, FaceFlowListener, FaceFlowProgress, FaceFlowResult,
  FaceFlowStage, FaceFlowOutcome, FaceAction, HiFaceError, HiFaceErrorCode,
  FaceVerificationConfig, Yuv420Frame, YuvPlane, YuvColorRange, YuvColorMatrix } from 'hiface';
import { BridgeError, FaceParams, NativeData, envelope, errorEnvelope, unwrap } from './BridgeTypes';
import { ReferenceStore } from './ReferenceStore';

interface DialogParams { flow: CameraFlow; }

@Builder
function cameraDialog(params: DialogParams) { FaceCameraDialog({ flow: params.flow }); }

@Component
struct FaceCameraDialog {
  flow: CameraFlow | undefined = undefined;
  @State guidance: string = '请正对镜头，保持人脸在画面中央';
  @State captured: boolean = false;
  @State saving: boolean = false;
  @State photo: image.PixelMap | undefined = undefined;
  private controller: XComponentController = new XComponentController();
  aboutToAppear(): void {
    if (this.flow === undefined) return;
    this.flow.onStatus = (value: string): void => { this.guidance = value; };
    this.flow.onCapture = (value: image.PixelMap | undefined): void => {
      this.photo = value; this.captured = true;
    };
  }
  aboutToDisappear(): void { this.flow?.cancel(); }
  build() {
    Column({ space: 20 }) {
      Text(this.guidance).fontSize(20).fontColor(Color.White).textAlign(TextAlign.Center).margin({ top: 30 })
      Stack() {
        XComponent({ id: 'hellofaceverify-camera', type: XComponentType.SURFACE, controller: this.controller })
          .width('100%').height('100%')
          .onLoad((): void => { this.flow?.start(this.controller.getXComponentSurfaceId()); })
        if (this.captured) {
          Column() {
            if (this.photo !== undefined) { Image(this.photo).objectFit(ImageFit.Contain).width('90%').height('90%') }
          }.width('100%').height('100%').backgroundColor(Color.Black).justifyContent(FlexAlign.Center)
        }
      }.layoutWeight(1).width('100%')
      Row({ space: 32 }) {
        Button('取消').enabled(!this.saving).onClick((): void => { this.flow?.cancel(); })
        if (this.captured) {
          Button(this.saving ? '正在保存' : '确认录入').enabled(!this.saving)
            .onClick((): void => { this.saving = true; this.flow?.confirm(); })
        }
      }.margin({ bottom: 40 })
    }.width('100%').height('100%').backgroundColor(Color.Black)
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
  committing: boolean = false;
  onStatus: (value: string) => void = (): void => {};
  onCapture: (photo: image.PixelMap | undefined) => void = (): void => {};
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
      const params: DialogParams = { flow: this };
      this.dialog = new ComponentContent<DialogParams>(ui, wrapBuilder(cameraDialog), params);
      const options: promptAction.BaseDialogOptions = { autoCancel: false,
        onWillDismiss: (_: DismissDialogAction): void => { this.cancel(); } };
      ui.getPromptAction().openCustomDialog(this.dialog, options).catch((error: Error): void => { this.fail(error); });
    } catch (error) { this.fail(new BridgeError('CAMERA_ERROR', String(error))); }
  }
  start(surfaceID: string): void {
    if (this.ended) return;
    this.startup = this.setup(surfaceID).catch((error: Error): void => { this.fail(error); });
  }
  private checkActive(): void { if (this.ended) throw new BridgeError('CANCELLED', 'Camera closed'); }
  private async setup(surfaceID: string): Promise<void> {
    unwrap(await this.sdk.whenReady()); this.checkActive();
    const listener: FaceFlowListener = {
      onProgress: (value: FaceFlowProgress): void => { this.progress(value); },
      onResult: (value: FaceFlowResult): void => { this.result(value); },
      onError: (error: HiFaceError): void => { this.fail(new BridgeError(HiFaceErrorCode[error.code], error.message)); }
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
    this.input.on('error', device, (): void => { this.fail(new BridgeError('CAMERA_ERROR', 'Camera input interrupted')); });
    this.session.on('error', (): void => { this.fail(new BridgeError('CAMERA_ERROR', 'Camera session interrupted')); });
    this.output.on('error', (): void => { this.fail(new BridgeError('CAMERA_ERROR', 'Camera preview interrupted')); });
    this.analysis.on('error', (): void => { this.fail(new BridgeError('CAMERA_ERROR', 'Camera analysis interrupted')); });
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
      if (result.isFailure() && result.requireError().code !== HiFaceErrorCode.NOT_READY) unwrap(result);
    }
  }
  private progress(value: FaceFlowProgress): void {
    if (this.ended) return;
    const actions: string[] = ['shakeHead', 'nodHead', 'blink', 'openMouth'];
    const action = value.action === undefined ? undefined : actions[value.action];
    const stage = FaceFlowStage[value.stage];
    const prompts: string[] = ['请正对镜头', '请保持画面中只有一人', '请靠近一些', '请完成提示动作', '请正对镜头', '请保持不动', '请正对镜头', '请保持稳定'];
    const actionPrompts: string[] = ['请摇摇头', '请点点头', '请眨眨眼', '请张张嘴'];
    this.onStatus(value.stage === FaceFlowStage.PERFORM_ACTION && value.action !== undefined ? actionPrompts[value.action] : prompts[value.stage]);
    this.progressCallback(envelope('progress', 'OK', '', { stage: stage, action: action,
      stepNumber: value.stepNumber, stepCount: value.stepCount }));
  }
  private result(value: FaceFlowResult): void {
    if (this.ended || this.captured !== undefined) return;
    if (this.method === 'enrollFace' && value.isPassed() && value.feature !== undefined) {
      this.captured = value;
      this.onStatus('采集完成，请确认录入');
      this.accepting = false;
      this.stopCamera().then(async (): Promise<void> => {
        if (this.ended) return;
        if (value.alignedRgba !== undefined) {
          this.photo = await image.createPixelMap(value.alignedRgba, {
            size: { width: value.alignedSide, height: value.alignedSide },
            pixelFormat: image.PixelMapFormat.RGBA_8888, editable: false });
        }
        if (this.ended) { await this.photo?.release(); this.photo = undefined; return; }
        this.onCapture(this.photo);
      }).catch((error: Error): void => { this.fail(error); });
    } else { this.finish(envelope('result', 'OK', '', this.resultData(value))); }
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
    this.ended = true; this.accepting = false; this.request?.cancel();
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
  }
  private async shutdown(): Promise<void> {
    await this.startup;
    await this.stopCamera();
    this.sdk.close();
    try { this.mainWindow.off('windowEvent', this.visibility); } catch (_) {}
    if (this.dialog !== undefined) {
      try { await this.mainWindow.getUIContext().getPromptAction().closeCustomDialog(this.dialog); } catch (_) {}
      this.dialog.dispose(); this.dialog = undefined;
    }
    try { await this.photo?.release(); } catch (_) {}
    this.photo = undefined; this.captured = undefined;
  }
}
