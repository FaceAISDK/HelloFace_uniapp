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
    assert.equal(progress[0].code, undefined) // A progress event is not a terminal result.
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
    calls[0].reply(JSON.stringify({ event: 'result', code: 'OK', data: {} }))
    assert.equal(complete, 1)
  })

  test(`${platform}: transient references are passed explicitly and require matching metadata`, () => {
    const { api, calls } = load(platform)
    const referenceFeature = 'HF1:' + 'A'.repeat(600)
    api.verifyFace({ faceID: 'server-user', referenceFeature, featureSpaceID: 'jdx-feature-v1' })
    assert.equal(calls[0].params.referenceFeature, referenceFeature)
    assert.equal(calls[0].params.featureSpaceID, 'jdx-feature-v1')
    for (const options of [{ referenceFeature }, { featureSpaceID: 'jdx-feature-v1' },
      { referenceFeature: '', featureSpaceID: 'jdx-feature-v1' },
      { referenceFeature, featureSpaceID: 'other-model' }]) {
      let error
      api.verifyFace({ faceID: 'server-user', ...options, fail: value => { error = value } })
      assert.equal(error.errCode, 9011001)
      assert.equal(error.faceID, 'server-user')
      assert.ok(!error.errMsg.includes(referenceFeature))
    }
    assert.equal(calls.length, 1)
  })

  test(`${platform}: cancel accepts no arguments and existing callback options`, () => {
    const { api, calls } = load(platform)
    api.cancel()
    assert.equal(calls[0].method, 'cancel')
    let result
    api.cancel({ success: value => { result = value } })
    calls[1].reply(JSON.stringify({ event: 'result', code: 'OK', data: {} }))
    assert.equal(result.faceID, '')
  })

  test(`${platform}: runtime input failures use fail and complete without native side effects`, () => {
    const { api, calls } = load(platform)
    for (const options of [{}, { faceID: null }, { faceID: 42 }, { faceID: 'u', actions: 'blink' },
      { faceID: 'u', silentLiveness: 'false' }, { faceID: 'u', threshold: '0.8' },
      { faceID: 'u', actions: [42] }]) {
      let failed = 0, completed = 0
      api.verifyFace({ ...options, fail: e => { failed++; assert.equal(e.errCode, 9011001) }, complete: () => completed++ })
      assert.equal(failed, 1); assert.equal(completed, 1)
    }
    let failed = 0
    api.enrollFace({ faceID: 'u', overwrite: 'false', fail: e => { failed++; assert.equal(e.errCode, 9011001) } })
    assert.equal(failed, 1)
    assert.equal(calls.length, 0)
  })

  test(`${platform}: duplicate terminal events and progress after completion are ignored`, () => {
    const { api, calls } = load(platform)
    let success = 0, fail = 0, complete = 0, progress = 0
    api.verifyFace({ faceID: 'u', success: () => success++, fail: () => fail++,
      complete: () => complete++, onProgress: () => progress++ })
    const reply = calls[0].reply
    reply(JSON.stringify({ event: 'result', code: 'OK', data: { passed: false, outcome: 'NOT_MATCHED', feature: 'private-probe' } }))
    reply(JSON.stringify({ event: 'error', code: 'CANCELLED' }))
    reply(JSON.stringify({ event: 'progress', code: 'OK', data: { stage: 'PERFORM_ACTION' } }))
    assert.deepEqual([success, fail, complete, progress], [1, 0, 1, 0])
  })

  test(`${platform}: malformed replies never report a completed capture or feature operation`, () => {
    for (const method of ['verifyFace', 'enrollFace', 'getFaceFeature', 'setFaceFeature']) {
      for (const raw of ['{', 'null', '42', JSON.stringify({ event: 'result', code: 'OK', data: {} }),
        JSON.stringify({ event: 'progress', code: 'OK' })]) {
        const { api, calls } = load(platform)
        let error, complete = 0
        api[method]({ faceID: 'u', ...(method === 'setFaceFeature' ?
          { feature: 'HF1:' + 'A'.repeat(600), featureSpaceID: 'jdx-feature-v1' } : {}),
          success: () => assert.fail('Unexpected success'),
          fail: value => { error = value }, complete: () => complete++ })
        calls[0].reply(raw)
        calls[0].reply(raw)
        assert.equal(error.sdkCode, 'BRIDGE_ERROR')
        assert.equal(error.code, 305)
        assert.equal(error.msg, '返回异常')
        assert.equal(error.faceID, 'u')
        assert.equal(complete, 1)
      }
    }
    const { api, calls } = load(platform)
    let failed = 0
    api.enrollFace({ faceID: 'u', success: () => assert.fail('Enrollment has no saved feature'),
      fail: e => { assert.equal(e.sdkCode, 'BRIDGE_ERROR'); failed++ } })
    calls[0].reply(JSON.stringify({ event: 'result', code: 'OK', data: { passed: true, outcome: 'PASSED' } }))
    assert.equal(failed, 1)
  })

  test(`${platform}: verification never exposes probe features and fail exceptions still complete`, () => {
    const { api, calls } = load(platform)
    let result, complete = 0
    api.verifyFace({ faceID: 'u', success: value => { result = value } })
    calls[0].reply(JSON.stringify({ event: 'result', code: 'OK', data: { passed: true, outcome: 'PASSED', feature: 'private-probe' } }))
    assert.equal(result.code, 0)
    assert.equal(result.msg, '验证通过')
    assert.equal(result.feature, null)
    api.getFaceFeature({ faceID: 'u', fail: () => { throw new Error('consumer error') }, complete: () => complete++ })
    assert.throws(() => calls[1].reply(JSON.stringify({ event: 'error', code: 'NOT_FOUND' })), /consumer error/)
    calls[1].reply(JSON.stringify({ event: 'error', code: 'NOT_FOUND' }))
    assert.equal(complete, 1)
  })

  test(`${platform}: each API returns consistent nullable fields despite native payload extras`, () => {
    const feature = 'HF1:' + 'A'.repeat(600)
    for (const method of ['enrollFace', 'verifyFace', 'getFaceFeature', 'setFaceFeature', 'deleteFace', 'cancel']) {
      const { api, calls } = load(platform)
      let result, completed
      api[method]({ faceID: 'u', ...(method === 'setFaceFeature' ? { feature, featureSpaceID: 'jdx-feature-v1' } : {}),
        success: value => { result = value }, complete: value => { completed = value } })
      calls[0].reply(JSON.stringify({ event: 'result', code: 'OK', data: {
        feature, passed: method !== 'verifyFace', outcome: method === 'verifyFace' ? 'NOT_MATCHED' : 'PASSED',
        similarity: 0, livenessScore: 0.97
      } }))
      assert.strictEqual(result, completed)
      assert.equal(result.code, method === 'verifyFace' ? 201 : 0)
      const messages = { enrollFace: '录入成功', verifyFace: '人脸不匹配', getFaceFeature: '读取成功',
        setFaceFeature: '保存成功', deleteFace: '删除成功', cancel: '已取消' }
      assert.equal(result.msg, messages[method])
      assert.equal(result.feature, ['enrollFace', 'getFaceFeature', 'setFaceFeature'].includes(method) ? feature : null)
      assert.equal(result.passed, method === 'verifyFace' ? false : method === 'enrollFace' ? true : null)
      assert.equal(result.outcome, method === 'verifyFace' ? 'NOT_MATCHED' : method === 'enrollFace' ? 'PASSED' : null)
      assert.equal(result.similarity, method === 'verifyFace' ? 0 : null)
      assert.equal(result.livenessScore, method === 'verifyFace' ? 0.97 : null)
    }
    const { api, calls } = load(platform)
    let result
    api.verifyFace({ faceID: 'u', success: value => { result = value } })
    // An overflowing JSON number must never become a usable business score.
    calls[0].reply('{"event":"result","code":"OK","data":{"passed":false,"outcome":"NOT_MATCHED","similarity":1e309,"livenessScore":-1e309}}')
    assert.equal(result.passed, false)
    assert.equal(result.similarity, null)
    assert.equal(result.livenessScore, null)
  })

  test(`${platform}: short business codes preserve the SDK verdict and raw outcome`, () => {
    const cases = [
      ['NOT_MATCHED', 201, '人脸不匹配'], ['SPOOF_DETECTED', 202, '活体未通过'],
      ['NO_FACE_TIMEOUT', 203, '未检测到人脸'], ['FACE_LOST', 204, '人脸丢失'],
      ['MULTIPLE_FACES', 205, '检测到多人'], ['ACTION_TIMEOUT', 206, '动作超时'],
      ['FINAL_CAPTURE_TIMEOUT', 207, '采集超时'], ['FUTURE_OUTCOME', 299, '未通过'],
      ['PASSED', 299, '未通过'] // A false verdict must never become code 0.
    ]
    for (const [outcome, code, msg] of cases) {
      const { api, calls } = load(platform)
      let result, completed = 0
      api.verifyFace({ faceID: 'u', success: value => { result = value },
        fail: () => assert.fail('Business rejection must remain in success'), complete: () => completed++ })
      calls[0].reply(JSON.stringify({ event: 'result', code: 'OK', data: {
        passed: false, outcome, similarity: 1, livenessScore: 1
      } }))
      assert.equal(result.code, code)
      assert.equal(result.msg, msg)
      assert.equal(result.passed, false)
      assert.equal(result.outcome, outcome)
      assert.equal(result.errMsg, 'verifyFace:ok')
      assert.equal(completed, 1)
    }
  })

  test(`${platform}: short failures keep legacy error codes and native diagnostics`, () => {
    const cases = [
      ['INVALID_ARGUMENT', 101, '参数错误', 9011001], ['PERMISSION_DENIED', 102, '相机未授权', 9011002],
      ['CANCELLED', 103, '已取消', 9011003], ['BUSY', 104, '操作中', 9011004],
      ['NOT_FOUND', 105, '请先录入', 9011005], ['ALREADY_EXISTS', 106, '已录入', 9011006],
      ['CAMERA_ERROR', 301, '相机异常', 9011008], ['STORAGE_ERROR', 302, '存储异常', 9011007],
      ['DATABASE_ERROR', 302, '存储异常', 9011008], ['NOT_READY', 303, 'SDK未就绪', 9011008],
      ['CLOSED', 303, 'SDK未就绪', 9011008], ['SDK_ERROR', 304, '识别异常', 9011008],
      ['BRIDGE_ERROR', 305, '返回异常', 9011008], ['NO_CONTEXT', 306, '环境不可用', 9011008],
      ['UNSUPPORTED_PLATFORM', 306, '环境不可用', 9011008], ['MODEL_LOAD_FAILED', 308, '模型异常', 9011008],
      ...['MISSING', 'INVALID', 'NOT_YET_VALID', 'EXPIRED', 'FEATURE_DENIED', 'CLOCK_INVALID']
        .map(suffix => ['LICENSE_' + suffix, 307, 'SDK授权异常', 9011008]),
      ['FUTURE_SDK_ERROR', 304, '识别异常', 9011008]
    ]
    for (const [sdkCode, code, msg, errCode] of cases) {
      const { api, calls } = load(platform)
      let error, complete
      api.verifyFace({ faceID: 'u', success: () => assert.fail('Unexpected success'),
        fail: value => { error = value }, complete: value => { complete = value } })
      const detail = 'Original SDK diagnostics: ' + sdkCode
      calls[0].reply(JSON.stringify({ event: 'error', code: sdkCode, message: detail }))
      assert.strictEqual(error, complete)
      assert.equal(error.code, code)
      assert.equal(error.msg, msg)
      assert.ok(error.msg.length <= 8)
      assert.equal(error.errCode, errCode)
      assert.equal(error.errSubject, 'HelloFaceVerify')
      assert.equal(error.errMsg, 'verifyFace:fail ' + msg)
      assert.equal(error.sdkCode, sdkCode)
      assert.equal(error.detail, detail)
      assert.equal(error.faceID, 'u')
    }
    const { api, calls } = load(platform)
    let error
    api.verifyFace({ faceID: '', fail: value => { error = value } })
    assert.equal(calls.length, 0)
    assert.equal(error.code, 101)
    assert.equal(error.msg, '参数错误')
    assert.match(error.detail, /faceID/)
  })
}
