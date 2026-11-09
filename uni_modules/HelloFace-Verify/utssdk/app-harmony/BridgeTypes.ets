import { HiFaceError, HiFaceErrorCode, HiFaceResult } from 'hiface';

export interface FaceParams {
  faceID: string;
  feature?: string;
  featureSpaceID?: string;
  overwrite?: boolean;
  camera?: string;
  threshold?: number;
  silentLiveness?: boolean;
  actions?: string[];
  actionTimeoutMs?: number;
  faceTimeoutMs?: number;
}
export interface NativeData {
  feature?: string;
  passed?: boolean;
  outcome?: string;
  similarity?: number;
  livenessScore?: number;
  stage?: string;
  action?: string;
  stepNumber?: number;
  stepCount?: number;
}
export interface NativeEvent {
  event: string;
  code: string;
  message: string;
  data: NativeData;
}
export function envelope(event: string = 'result', code: string = 'OK', message: string = '',
  data: NativeData = {}): string {
  const result: NativeEvent = { event: event, code: code, message: message, data: data };
  return JSON.stringify(result);
}
export class BridgeError implements Error {
  readonly name: string = 'HelloFaceVerifyError';
  readonly message: string;
  readonly code: string;
  constructor(code: string, message: string) { this.message = message; this.code = code; }
}
export function unwrap<T>(result: HiFaceResult<T>): T {
  if (result.isFailure()) {
    const error: HiFaceError = result.requireError();
    throw new BridgeError(HiFaceErrorCode[error.code], error.message);
  }
  return result.requireValue();
}
export function errorEnvelope(error: Error): string {
  return envelope('error', error instanceof BridgeError ? error.code : 'SDK_ERROR', error.message);
}
