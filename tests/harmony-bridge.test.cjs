const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const { test } = require('node:test')
let ts
try { ts = require('typescript') } catch (_) {
  ts = require(path.join(process.env.HBUILDERX_PATH || '/Applications/HBuilderX.app/Contents/HBuilderX',
    'plugins/uniapp-uts-v1/node_modules/@dcloudio/uni-uts-v1/lib/typescript'))
}
const flush = () => new Promise(resolve => setImmediate(resolve))
const envelope = (event = 'result', code = 'OK', message = '', data = {}) => JSON.stringify({ event, code, message, data })

// Exercise the actual ArkTS operation coordinator. Camera/permission/storage are
// controllable boundaries; no face capture or algorithm success is simulated.
function loadBridge() {
  const state = { reads: [], writes: [], cameras: [], sdkCreates: 0, localFeature: 'local-reference',
    permission: Promise.resolve({ authResults: [0] }), permissionRequests: 0,
    imageExtractions: [], imageResult: Promise.resolve('extracted-reference') }
  class BridgeError extends Error { constructor(code, message) { super(message); this.code = code } }
  class ReferenceStore {
    async get(id) { state.reads.push(id); return state.localFeature }
    async save(id, value) { state.writes.push({ id, value }) }
    async delete() {}
  }
  class CameraFlow {
    committing = false
    constructor(context, window, sdk, method, params, reference, progress, completion) {
      Object.assign(this, { method, params, reference, completion, cancels: 0 })
      state.cameras.push(this)
    }
    open() {}
    cancel() { this.cancels++ }
    finishCancellation() { this.completion(envelope('error', 'CANCELLED', 'Cancelled')) }
  }
  const exports = {}
  const filename = path.resolve(__dirname, '../uni_modules/HelloFace-Verify/utssdk/app-harmony/HelloFaceVerifyNative.ets')
  const source = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    fileName: 'native.ts', compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText
  vm.runInNewContext(source, { exports, require(name) {
    if (name === '@kit.AbilityKit') return { abilityAccessCtrl: { createAtManager: () => ({
      requestPermissionsFromUser() { state.permissionRequests++; return state.permission }
    }) } }
    if (name === '@kit.ArkUI') return { window: { getLastWindow: async () => ({}) } }
    if (name === 'hiface') return { HiFaceSdk: { create() { state.sdkCreates++; return {} } } }
    if (name === './BridgeTypes') return { BridgeError, envelope,
      errorEnvelope: e => envelope('error', e.code || 'SDK_ERROR', e.message) }
    if (name === './ReferenceStore') return { ReferenceStore }
    if (name === './FaceImageImporter') return { FaceImageImporter: { extract(context, encoded) {
      state.imageExtractions.push(encoded); return state.imageResult
    } } }
    if (name === './HelloFaceVerifyCamera') return { CameraFlow }
    throw new Error(name)
  } }, { filename })
  const native = exports.HelloFaceVerifyNative
  return { state, invoke(method, params, callback) { native.invoke({}, method, JSON.stringify(params), raw => callback(JSON.parse(raw))) } }
}

test('Harmony: image sync holds the operation slot and never opens camera permission/UI', async () => {
  const { state, invoke } = loadBridge()
  state.localFeature = undefined
  let resolveImage
  state.imageResult = new Promise(resolve => { resolveImage = resolve })
  const results = [], blocked = []
  invoke('syncFaceImage', { faceID: 'external', imageBase64: 'encoded-photo' }, result => results.push(result))
  await flush()
  invoke('syncFaceFeature', { faceID: 'external', feature: 'other' }, result => blocked.push(result))
  assert.equal(blocked[0].code, 'BUSY')
  assert.equal(state.permissionRequests, 0)
  assert.equal(state.cameras.length, 0)
  assert.equal(state.writes.length, 0)
  resolveImage('extracted-reference')
  await flush()
  assert.deepEqual(state.writes, [{ id: 'external', value: 'extracted-reference' }])
  assert.equal(results[0].data.feature, 'extracted-reference')
  assert.equal(results[0].data.passed, undefined)
})

test('Harmony: both sync methods protect existing references; image errors preserve storage', async () => {
  const { state, invoke } = loadBridge()
  const results = []
  for (const method of ['syncFaceImage', 'syncFaceFeature']) {
    invoke(method, { faceID: 'u', imageBase64: 'encoded', feature: 'incoming' }, result => results.push(result))
    await flush()
    assert.equal(results.at(-1).code, 'ALREADY_EXISTS')
  }
  assert.equal(state.imageExtractions.length, 0)
  const imageError = Object.assign(new Error('No face'), { code: 'IMAGE_NO_FACE' })
  state.imageResult = Promise.reject(imageError)
  invoke('syncFaceImage', { faceID: 'u', imageBase64: 'encoded', overwrite: true }, result => results.push(result))
  await flush()
  assert.equal(results.at(-1).code, 'IMAGE_NO_FACE')
  assert.equal(state.writes.length, 0)
  invoke('syncFaceFeature', { faceID: 'u', feature: 'incoming', overwrite: true }, result => results.push(result))
  await flush()
  assert.equal(results.at(-1).code, 'OK')
  assert.equal(state.permissionRequests, 0)
})

test('Harmony: an explicit reference bypasses local storage and never writes it', async () => {
  const { state, invoke } = loadBridge()
  invoke('verifyFace', { faceID: 'u', referenceFeature: 'provided-reference', featureSpaceID: 'jdx-feature-v1' }, () => {})
  await flush()
  assert.deepEqual(state.reads, [])
  assert.deepEqual(state.writes, [])
  assert.equal(state.sdkCreates, 1)
  assert.equal(state.cameras[0].reference, 'provided-reference')
})

test('Harmony: a missing local reference fails before requesting camera permission', async () => {
  const { state, invoke } = loadBridge()
  state.localFeature = undefined
  const results = []
  invoke('verifyFace', { faceID: 'u' }, result => results.push(result))
  await flush()
  assert.equal(results[0].code, 'NOT_FOUND')
  assert.equal(state.permissionRequests, 0)
  assert.equal(state.sdkCreates, 0)
})

test('Harmony: cancel acknowledges after teardown and permits starting from its success callback', async () => {
  const { state, invoke } = loadBridge()
  const order = []
  invoke('verifyFace', { faceID: 'u' }, result => order.push(result.code))
  await flush()
  assert.equal(state.cameras[0].reference, 'local-reference')
  invoke('cancel', {}, result => {
    order.push('cancel:' + result.code)
    invoke('getFaceFeature', { faceID: 'u' }, value => order.push('read:' + value.code))
  })
  invoke('cancel', {}, result => order.push('second:' + result.code))
  assert.deepEqual(order, [])
  invoke('getFaceFeature', { faceID: 'u' }, result => order.push('during:' + result.code))
  assert.deepEqual(order, ['during:BUSY'])
  state.cameras[0].finishCancellation()
  await flush()
  assert.deepEqual(order, ['during:BUSY', 'CANCELLED', 'cancel:OK', 'second:OK', 'read:OK'])
  state.cameras[0].finishCancellation()
  assert.equal(order.length, 5)
})

test('Harmony: confirmed storage cannot be cancelled as if nothing was saved', async () => {
  const { state, invoke } = loadBridge()
  invoke('enrollFace', { faceID: 'u', overwrite: true }, () => {})
  await flush()
  state.cameras[0].committing = true
  const results = []
  invoke('cancel', {}, result => results.push(result))
  assert.equal(results[0].code, 'BUSY')
  assert.equal(state.cameras[0].cancels, 0)
})

test('Harmony: cancelling a pending permission request isolates its late resolution', async () => {
  const { state, invoke } = loadBridge()
  let grant
  state.permission = new Promise(resolve => { grant = resolve })
  const results = []
  invoke('enrollFace', { faceID: 'u', overwrite: true }, result => results.push(result.code))
  await flush()
  invoke('cancel', {}, result => results.push('cancel:' + result.code))
  assert.deepEqual(results, ['CANCELLED', 'cancel:OK'])
  grant({ authResults: [0] })
  await flush()
  assert.equal(state.cameras.length, 0)
  assert.equal(state.sdkCreates, 0)
  assert.deepEqual(results, ['CANCELLED', 'cancel:OK'])
})

test('Harmony: enrollment preview declares RGBA input so red and blue stay in order', async () => {
  const filename = path.resolve(__dirname, '../uni_modules/HelloFace-Verify/utssdk/app-harmony/HelloFaceVerifyCamera.ets')
  const camera = fs.readFileSync(filename, 'utf8')
  // Run the real confirmation method without compiling ArkUI's component syntax.
  const method = camera.slice(camera.indexOf('  private result('), camera.indexOf('  retake():'))
  const source = ts.transpileModule('exports.Flow = class {' + method + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText
  const exports = {}
  vm.runInNewContext(source, { exports, image: {
    PixelMapFormat: { RGBA_8888: 'rgba' },
    async createPixelMap(buffer, options) {
      // Match ImageKit's default BGRA source interpretation using synthetic pixels.
      const pixels = new Uint8Array(buffer).slice()
      if (options.srcPixelFormat !== 'rgba') {
        for (let i = 0; i < pixels.length; i += 4) [pixels[i], pixels[i + 2]] = [pixels[i + 2], pixels[i]]
      }
      return { pixels }
    }
  } }, { filename })
  const flow = new exports.Flow()
  const pixels = new Uint8Array([255, 0, 0, 255, 0, 255, 0, 255,
    0, 0, 255, 255, 255, 255, 255, 255])
  let preview
  Object.assign(flow, { method: 'enrollFace', previews: [], stopCamera: async () => {},
    onCapture(photo, ready) { assert.equal(ready, true); preview = photo },
    fail(error) { throw error } })
  flow.result({ isPassed: () => true, feature: 'test-only', alignedRgba: pixels.buffer, alignedSide: 2 })
  await flush()
  assert.deepEqual(Array.from(preview.pixels), Array.from(pixels))
  assert.equal(flow.previews[0], preview)
})
