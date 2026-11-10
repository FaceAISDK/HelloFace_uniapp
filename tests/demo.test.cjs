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
  const sandbox = { exports, uni: { hideKeyboard() {}, showModal: options => modals.push(options) } }
  for (const name of ['enrollFace', 'verifyFace', 'getFaceFeature', 'deleteFace', 'cancel']) {
    sandbox[name] = options => calls.push({ name, options })
  }
  vm.runInNewContext(outputText, sandbox, { filename })
  const page = exports.default
  const state = page.data()
  for (const [name, method] of Object.entries(page.methods)) state[name] = method.bind(state)
  return { state, calls, modals, unload: () => page.onUnload.call(state) }
}

for (const file of ['pages/index/index.vue', 'examples/uni-app-x/pages/index/index.uvue']) {
  test(`${file}: verification displays the SDK verdict and uses the chosen action mode`, () => {
    const { state, calls } = loadPage(file)
    state.verify(true)
    const options = calls[0].options
    assert.equal(options.faceID, 'demo-user')
    assert.equal(options.threshold, 0.8)
    assert.equal(options.silentLiveness, true)
    assert.deepEqual(Array.from(options.actions), ['blink', 'nodHead'])
    options.success({ errMsg: 'verifyFace:ok', faceID: 'demo-user', passed: false,
      outcome: 'SPOOF_DETECTED', similarity: 0.999, livenessScore: null })
    options.complete({})
    assert.match(state.resultText, /passed: false/)
    assert.match(state.resultText, /outcome: SPOOF_DETECTED/)
    assert.match(state.resultText, /similarity: 0\.999/)
    assert.ok(!state.resultText.includes('livenessScore:'))
    assert.equal(state.busy, false)
    state.verify(false)
    assert.deepEqual(Array.from(calls[1].options.actions), [])
    assert.equal(calls[1].options.silentLiveness, true)
  })

  test(`${file}: enrollment calls the plugin directly without retaining biometric features`, () => {
    const { state, calls } = loadPage(file)
    state.enroll()
    state.enroll()
    state.verify(false)
    assert.equal(calls.length, 1)
    assert.equal(calls[0].name, 'enrollFace')
    assert.equal(calls[0].options.overwrite, true)
    calls[0].options.success({ errMsg: 'enrollFace:ok', faceID: 'demo-user', passed: true,
      outcome: 'PASSED', feature: 'private-test-feature' })
    calls[0].options.complete({})
    assert.match(state.resultText, /msg: enrollFace:ok/)
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
    calls[0].options.success({ errMsg: 'deleteFace:ok', faceID: 'demo-user', passed: null })
    calls[0].options.complete({})
    assert.match(state.resultText, /msg: deleteFace:ok/)
    assert.ok(!state.resultText.includes('passed:'))
    assert.equal(state.busy, false)
  })

  test(`${file}: failures release the buttons and unloading cancels active work`, () => {
    const { state, calls, unload } = loadPage(file)
    state.verify(false)
    calls[0].options.fail({ errCode: 9011002, sdkCode: 'CAMERA_PERMISSION_DENIED', faceID: 'demo-user', errMsg: '需要相机权限' })
    calls[0].options.complete({})
    assert.match(state.resultText, /errCode: 9011002/)
    assert.match(state.resultText, /sdkCode: CAMERA_PERMISSION_DENIED/)
    assert.match(state.resultText, /msg: 需要相机权限/)
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
    assert.equal(state.resultText, 'showModal:fail')
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
