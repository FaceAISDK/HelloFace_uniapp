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

// Exercise the actual page scripts; native calls and system dialogs stay mocked.
function loadPage(filename, app = true) {
  const source = fs.readFileSync(path.resolve(__dirname, '..', filename), 'utf8')
  const script = source.match(/<script[^>]*>([\s\S]*?)<\/script>/)[1]
  let enabled = true
  const parents = []
  const processed = script.split('\n').filter(line => {
    const directive = line.match(/^\s*\/\/ #(ifdef|ifndef|endif)\s*(APP)?\s*$/)
    if (!directive) return enabled
    if (directive[1] === 'endif') enabled = parents.pop()
    else {
      parents.push(enabled)
      enabled = enabled && (directive[1] === 'ifdef' ? app : !app)
    }
    return false
  }).join('\n').replace(/^import .+ from .+$/gm, '')
  const { outputText, diagnostics } = ts.transpileModule(processed, {
    fileName: 'demo.ts', reportDiagnostics: true,
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  })
  assert.equal(diagnostics.length, 0)
  const calls = [], modals = [], exports = {}
  const sandbox = { exports, demoImageBase64: 'external-demo-photo', demoFeature: 'external-demo-feature', demoFeatureSpaceID: 'jdx-feature-v1', uni: { hideKeyboard() {}, showModal: options => modals.push(options) } }
  for (const name of ['syncFaceImage', 'syncFaceFeature', 'enrollFace', 'verifyFace', 'getFaceFeature', 'deleteFace', 'cancel']) {
    sandbox[name] = options => calls.push({ name, options })
  }
  vm.runInNewContext(outputText, sandbox, { filename })
  const page = exports.default
  const state = page.data()
  for (const [name, method] of Object.entries(page.methods)) state[name] = method.bind(state)
  return { state, calls, modals, unload: () => page.onUnload.call(state) }
}

for (const file of ['pages/index/index.vue', 'examples/uni-app-x/pages/index/index.uvue']) {
  test(`${file}: external demo sync works without local enrollment or reading a device feature`, () => {
    const { state, calls } = loadPage(file)
    state.syncImage()
    assert.equal(calls[0].name, 'syncFaceImage')
    assert.equal(calls[0].options.imageBase64, 'external-demo-photo')
    assert.equal(calls[0].options.faceID, 'external-demo')
    calls[0].options.success({ code: 0, msg: '同步成功', faceID: 'external-demo', passed: null })
    calls[0].options.complete({})
    assert.ok(!state.resultText.includes('passed:'))
    state.syncFeature()
    assert.equal(calls[1].name, 'syncFaceFeature')
    assert.equal(calls[1].options.feature, 'external-demo-feature')
    assert.equal(calls[1].options.featureSpaceID, 'jdx-feature-v1')
    assert.equal(calls.length, 2)
  })
  test(`${file}: verification displays the SDK verdict and uses the chosen action mode`, () => {
    const { state, calls } = loadPage(file)
    state.verify(true)
    const options = calls[0].options
    assert.equal(options.faceID, 'demo-user')
    // Demo 省略默认项，由插件统一提供阈值与静默活体默认值。
    assert.equal(options.threshold, undefined)
    assert.equal(options.silentLiveness, undefined)
    assert.deepEqual(Array.from(options.actions), ['blink', 'nodHead'])
    options.success({ code: 202, msg: '活体未通过', errMsg: 'verifyFace:ok', faceID: 'demo-user', passed: false,
      outcome: 'SPOOF_DETECTED', similarity: 0.999, livenessScore: null })
    options.complete({})
    assert.match(state.resultText, /passed: false/)
    assert.match(state.resultText, /code: 202/)
    assert.match(state.resultText, /msg: 活体未通过/)
    assert.ok(!state.resultText.includes('SPOOF_DETECTED'))
    assert.match(state.resultText, /similarity: 0\.999/)
    assert.ok(!state.resultText.includes('livenessScore:'))
    assert.equal(state.busy, false)
    state.verify(false)
    assert.deepEqual(Array.from(calls[1].options.actions), [])
    assert.equal(calls[1].options.silentLiveness, undefined)
  })

  test(`${file}: enrollment calls the plugin directly without retaining biometric features`, () => {
    const { state, calls } = loadPage(file)
    state.enroll()
    state.enroll()
    state.verify(false)
    assert.equal(calls.length, 1)
    assert.equal(calls[0].name, 'enrollFace')
    assert.equal(calls[0].options.overwrite, true)
    calls[0].options.success({ code: 0, msg: '录入成功', errMsg: 'enrollFace:ok', faceID: 'demo-user', passed: true,
      outcome: 'PASSED', feature: 'private-test-feature' })
    calls[0].options.complete({})
    assert.match(state.resultText, /code: 0/)
    assert.match(state.resultText, /msg: 录入成功/)
    assert.match(state.resultText, /passed: true/)
    assert.ok(!JSON.stringify(state).includes('private-test-feature'))
  })

  test(`${file}: deleting a reference requires confirmation`, () => {
    const { state, calls, modals } = loadPage(file)
    state.remove()
    assert.equal(calls.length, 0)
    state.verify(false)
    assert.equal(calls.length, 0)
    modals[0].success({ confirm: false })
    assert.equal(calls.length, 0)
    assert.equal(state.busy, false)
    state.remove()
    modals[1].success({ confirm: true })
    assert.equal(calls[0].name, 'deleteFace')
    assert.equal(calls[0].options.faceID, 'demo-user')
    calls[0].options.success({ code: 0, msg: '删除成功', errMsg: 'deleteFace:ok', faceID: 'demo-user', passed: null })
    calls[0].options.complete({})
    assert.match(state.resultText, /msg: 删除成功/)
    assert.ok(!state.resultText.includes('passed:'))
    assert.equal(state.busy, false)
  })

  test(`${file}: failures release the buttons and unloading cancels active work`, () => {
    const { state, calls, unload } = loadPage(file)
    state.verify(false)
    calls[0].options.fail({ code: 102, msg: '相机未授权', errCode: 9011002, sdkCode: 'PERMISSION_DENIED',
      faceID: 'demo-user', errMsg: 'verifyFace:fail 相机未授权', detail: 'Original camera diagnostics' })
    calls[0].options.complete({})
    assert.match(state.resultText, /code: 102/)
    assert.match(state.resultText, /msg: 相机未授权/)
    assert.ok(!state.resultText.includes('Original camera diagnostics'))
    assert.match(state.resultText, /faceID: demo-user/)
    assert.equal(state.busy, false)
    state.verify(false)
    unload()
    assert.equal(calls[2].name, 'cancel')
  })

  test(`${file}: a failed confirmation dialog releases the buttons without deleting`, () => {
    const { state, calls, modals } = loadPage(file)
    state.remove()
    modals[0].fail({ errMsg: 'showModal:fail' })
    assert.equal(state.busy, false)
    assert.equal(state.resultText, '操作未完成')
    assert.equal(calls.length, 0)
  })

  test(`${file}: browser preview never simulates recognition success`, () => {
    const { state, calls } = loadPage(file, false)
    for (const action of ['enroll', 'verify', 'remove']) {
      state[action](false)
      assert.match(state.resultText, /请在 App 真机体验/)
      assert.equal(state.busy, false)
      assert.equal(calls.length, 0)
    }
  })
}
