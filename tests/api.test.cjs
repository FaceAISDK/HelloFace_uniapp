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
const sdkRoot = path.resolve(__dirname, '../uni_modules/HelloFace-Verify/utssdk')
function jsonObject(data) {
  const methods = {
    getString: key => typeof data[key] === 'string' ? data[key] : null,
    getNumber: key => typeof data[key] === 'number' ? data[key] : null,
    getBoolean: key => typeof data[key] === 'boolean' ? data[key] : null,
    getArray: key => Array.isArray(data[key]) ? data[key] : null,
    getJSON: key => data[key] != null && typeof data[key] === 'object' ? jsonObject(data[key]) : null
  }
  for (const [key, value] of Object.entries(methods)) Object.defineProperty(data, key, { value, configurable: true })
  return data
}
function load(platform = 'app-ios') {
  const cache = new Map()
  const calls = []
  const native = { invoke(...args) {
    if (platform === 'app-android' || platform === 'app-harmony') args.shift()
    calls.push({ method: args[0], params: JSON.parse(args[1]), reply: args[2] })
  } }
  const json = Object.create(JSON)
  json.parseObject = raw => { try { return jsonObject(JSON.parse(raw)) } catch (_) { return null } }
  function read(filename) {
    if (cache.has(filename)) return cache.get(filename)
    const source = fs.readFileSync(filename, 'utf8')
    const result = ts.transpileModule(source, { fileName: filename.replace(/\.uts$/, '.ts'),
      compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
      transformers: { before: [context => {
        const visit = node => {
          if (ts.isAsExpression(node) && ts.isTypeReferenceNode(node.type) && node.type.typeName.getText() === 'UTSJSONObject') {
            return ts.factory.createCallExpression(ts.factory.createIdentifier('__utsObject'), undefined, [ts.visitNode(node.expression, visit)])
          }
          return ts.visitEachChild(node, visit, context)
        }
        return file => ts.visitNode(file, visit)
      }] } })
    const module = { exports: {} }
    cache.set(filename, module.exports)
    const sandbox = { module, exports: module.exports, JSON: json, __utsObject: jsonObject, HelloFaceVerifyNative: native,
      UTSAndroid: { getAppContext: () => ({}) }, UniError: class UniError extends Error {},
      UTSHarmony: { getUIAbilityContext: () => ({}) },
      require(name) {
        if (name === 'uts.sdk.modules.HelloFaceVerify' || name === './HelloFaceVerifyNative.ets') return { HelloFaceVerifyNative: native }
        return read(path.resolve(path.dirname(filename), name))
      } }
    vm.runInNewContext(result.outputText, sandbox, { filename })
    return module.exports
  }
  return { api: read(path.join(sdkRoot, platform, 'index.uts')), calls }
}
for (const platform of ['app-android', 'app-ios', 'app-harmony']) {
  test(`${platform}: verification defaults and callback isolation`, () => {
    const { api, calls } = load(platform)
    const progress = [], successes = [], completed = []
    api.verifyFace({ faceID: '  user-1  ', onProgress: p => progress.push(p),
      success: r => successes.push(r), complete: r => completed.push(r) })
    assert.equal(calls.length, 1)
    assert.deepEqual(calls[0].params, { faceID: 'user-1', threshold: 0.8, silentLiveness: true,
      actions: [], actionTimeoutMs: 10000, faceTimeoutMs: 15000, camera: 'front' })
    calls[0].reply(JSON.stringify({ event: 'progress', code: 'OK', data: { stage: 'PERFORM_ACTION', action: 'blink', stepNumber: 1, stepCount: 2 } }))
    assert.equal(progress[0].action, 'blink')
    assert.equal(completed.length, 0)
    calls[0].reply(JSON.stringify({ event: 'result', code: 'OK', data: { passed: false, outcome: 'SPOOF_DETECTED', similarity: 0.99 } }))
    assert.equal(successes[0].passed, false)
    assert.equal(successes[0].similarity, 0.99)
    assert.equal(successes[0].livenessScore, null)
    assert.equal(completed.length, 1)
  })
  test(`${platform}: rejects invalid input before opening native UI`, () => {
    const { api, calls } = load(platform)
    for (const options of [{ faceID: '' }, { faceID: 'a\0b' }, { faceID: 'x'.repeat(65) },
      { faceID: 'u', threshold: NaN }, { faceID: 'u', threshold: 1.1 }, { faceID: 'u', camera: 'other' },
      { faceID: 'u', actions: ['smile'] }, { faceID: 'u', actions: ['blink', 'blink', 'blink', 'blink', 'blink'] },
      { faceID: 'u', actionTimeoutMs: 1000.5 }]) {
      let failed = 0, completed = 0
      api.verifyFace({ ...options, fail: error => { failed++; assert.equal(error.errCode, 9011001); assert.equal(error.errSubject, 'HelloFaceVerify') }, complete: () => completed++ })
      assert.equal(failed, 1); assert.equal(completed, 1)
    }
    assert.equal(calls.length, 0)
  })
  test(`${platform}: refuses incompatible imported features`, () => {
    const { api, calls } = load(platform)
    const errors = []
    api.setFaceFeature({ faceID: 'u', feature: 'HF1:' + 'A'.repeat(600), featureSpaceID: 'old-model', fail: e => errors.push(e) })
    api.setFaceFeature({ faceID: 'u', feature: 'legacy-feature', featureSpaceID: 'jdx-feature-v1', fail: e => errors.push(e) })
    assert.equal(errors.length, 2); assert.equal(calls.length, 0)
    api.setFaceFeature({ faceID: 'u', feature: 'HF1:' + 'A'.repeat(600), featureSpaceID: 'jdx-feature-v1' })
    assert.equal(calls.length, 1); assert.equal(calls[0].params.overwrite, false)
  })
  test(`${platform}: enforces native SDK timeout limits before invoking native code`, () => {
    const { api, calls } = load(platform)
    for (const actionTimeoutMs of [1000, 1999, 30001, 60000, Infinity]) {
      let failed = 0, completed = 0
      api.verifyFace({ faceID: 'u', actionTimeoutMs,
        fail: error => { failed++; assert.equal(error.errCode, 9011001) },
        complete: () => completed++ })
      assert.equal(failed, 1); assert.equal(completed, 1)
    }
    assert.equal(calls.length, 0)
    for (const [actionTimeoutMs, faceTimeoutMs] of [[2000, 1000], [30000, 60000]]) {
      api.verifyFace({ faceID: 'u', actionTimeoutMs, faceTimeoutMs })
      const call = calls.at(-1)
      assert.equal(call.params.actionTimeoutMs, actionTimeoutMs)
      assert.equal(call.params.faceTimeoutMs, faceTimeoutMs)
    }
    assert.equal(calls.length, 2)
  })
  test(`${platform}: cancellation and SDK errors use UniError`, () => {
    const { api, calls } = load(platform)
    const errors = [], completed = []
    api.enrollFace({ faceID: 'u', fail: e => errors.push(e), complete: e => completed.push(e) })
    calls[0].reply(JSON.stringify({ event: 'error', code: 'CANCELLED', message: 'Cancelled' }))
    assert.equal(errors[0].errCode, 9011003); assert.equal(completed.length, 1)
    api.getFaceFeature({ faceID: 'u', fail: e => errors.push(e) })
    calls[1].reply(JSON.stringify({ event: 'error', code: 'LICENSE_EXPIRED', message: 'Expired' }))
    assert.equal(errors[1].sdkCode, 'LICENSE_EXPIRED'); assert.equal(errors[1].errCode, 9011008)
  })
  test(`${platform}: complete runs even if a success handler throws`, () => {
    const { api, calls } = load(platform)
    let complete = 0
    api.deleteFace({ faceID: 'u', success: () => { throw new Error('consumer error') }, complete: () => complete++ })
    assert.throws(() => calls[0].reply(JSON.stringify({ event: 'result', code: 'OK', data: {} })), /consumer error/)
    assert.equal(complete, 1)
  })
}
