import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { HiFaceSdk } from 'hiface';
import { BridgeError, FaceParams, envelope, errorEnvelope } from './BridgeTypes';
import { ReferenceStore } from './ReferenceStore';
import { CameraFlow } from './HelloFaceVerifyCamera';

export class HelloFaceVerifyNative {
  private static busy: boolean = false;
  private static generation: number = 0;
  private static camera: CameraFlow | undefined = undefined;
  private static cameraCallback: ((value: string) => void) | undefined = undefined;
  private static cancelCallbacks: Array<(value: string) => void> = [];

  static invoke(context: common.UIAbilityContext, method: string, raw: string, callback: (value: string) => void): void {
    if (method === 'cancel') {
      if (HelloFaceVerifyNative.camera !== undefined) {
        if (HelloFaceVerifyNative.camera.committing) { callback(envelope('error', 'BUSY', 'Enrollment is being saved')); return; }
        HelloFaceVerifyNative.cancelCallbacks.push(callback);
        HelloFaceVerifyNative.camera.cancel();
        return;
      } else if (HelloFaceVerifyNative.cameraCallback !== undefined) {
        // Permission/readiness may still be pending before a dialog exists.
        const pending = HelloFaceVerifyNative.cameraCallback;
        HelloFaceVerifyNative.cameraCallback = undefined;
        HelloFaceVerifyNative.generation++;
        HelloFaceVerifyNative.busy = false;
        try { pending(envelope('error', 'CANCELLED', 'Face operation cancelled')); }
        finally { callback(envelope()); }
        return;
      }
      callback(envelope());
      return;
    }
    if (HelloFaceVerifyNative.busy) { callback(envelope('error', 'BUSY', 'A face operation is active')); return; }
    HelloFaceVerifyNative.busy = true;
    const token = ++HelloFaceVerifyNative.generation;
    let completed: boolean = false;
    const finish = (result: string): void => {
      if (completed || token !== HelloFaceVerifyNative.generation) return;
      completed = true;
      HelloFaceVerifyNative.busy = false;
      HelloFaceVerifyNative.camera = undefined;
      HelloFaceVerifyNative.cameraCallback = undefined;
      const cancellations = HelloFaceVerifyNative.cancelCallbacks;
      HelloFaceVerifyNative.cancelCallbacks = [];
      try { callback(result); }
      finally { cancellations.forEach((cancelled: (value: string) => void): void => { cancelled(envelope()); }); }
    };
    if (method === 'enrollFace' || method === 'verifyFace') HelloFaceVerifyNative.cameraCallback = callback;
    HelloFaceVerifyNative.execute(context, method, raw, token, callback, finish).catch((error: Error): void => {
      finish(errorEnvelope(error));
    });
  }

  private static async execute(context: common.UIAbilityContext, method: string, raw: string, token: number,
    callback: (value: string) => void, finish: (value: string) => void): Promise<void> {
    const params = JSON.parse(raw) as FaceParams;
    const store = new ReferenceStore(context);
    const feature = method === 'verifyFace' && params.referenceFeature !== undefined ? params.referenceFeature :
      (method === 'deleteFace' ? undefined : await store.get(params.faceID));
    if (token !== HelloFaceVerifyNative.generation) return;
    if (method === 'getFaceFeature') {
      if (feature === undefined) throw new BridgeError('NOT_FOUND', 'No enrolled face for faceID');
      finish(envelope('result', 'OK', '', { feature: feature }));
    } else if (method === 'deleteFace') {
      await store.delete(params.faceID); finish(envelope());
    } else if (method === 'setFaceFeature') {
      if (feature !== undefined && params.overwrite !== true) throw new BridgeError('ALREADY_EXISTS', 'Face already enrolled');
      await store.save(params.faceID, params.feature ?? '');
      finish(envelope('result', 'OK', '', { feature: params.feature }));
    } else if (method === 'enrollFace' || method === 'verifyFace') {
      if (method === 'enrollFace' && feature !== undefined && params.overwrite !== true) {
        throw new BridgeError('ALREADY_EXISTS', 'Face already enrolled');
      }
      if (method === 'verifyFace' && feature === undefined) throw new BridgeError('NOT_FOUND', 'Enroll this faceID first');
      const access = abilityAccessCtrl.createAtManager();
      const permission = await access.requestPermissionsFromUser(context, ['ohos.permission.CAMERA']);
      if (token !== HelloFaceVerifyNative.generation) return;
      if (permission.authResults.length !== 1 || permission.authResults[0] !== 0) {
        throw new BridgeError('PERMISSION_DENIED', 'Camera permission denied');
      }
      const mainWindow = await window.getLastWindow(context);
      if (token !== HelloFaceVerifyNative.generation) return;
      const sdk: HiFaceSdk = HiFaceSdk.create(context);
      const flow = new CameraFlow(context, mainWindow, sdk, method, params, feature,
        (value: string): void => { if (token === HelloFaceVerifyNative.generation) callback(value); }, finish);
      HelloFaceVerifyNative.camera = flow;
      flow.open();
    } else { throw new BridgeError('INVALID_ARGUMENT', 'Unknown operation'); }
  }
}
