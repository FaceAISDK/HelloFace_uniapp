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
  test(`${file}: verification uses the SDK verdict and selected liveness options`, () => {
    const { state, calls } = loadPage(file)
    state.useActions = true
    state.silentLiveness = false
    state.verify()
    const options = calls[0].options
    assert.equal(options.faceID, 'demo-user')
    assert.equal(options.threshold, 0.8)
    assert.equal(options.silentLiveness, false)
    assert.deepEqual(Array.from(options.actions), ['blink', 'nodHead'])
    options.success({ passed: false, outcome: 'SPOOF_DETECTED', similarity: 0.999, livenessScore: null })
    options.complete({})
    assert.equal(state.tone, 'rejected')
    assert.equal(state.title, '身份验证未通过')
    assert.equal(state.similarity, '0.999')
    assert.equal(state.liveness, '—')
    assert.equal(state.busy, false)
  })

  test(`${file}: enrollment calls the plugin directly without retaining biometric features`, () => {
    const { state, calls } = loadPage(file)
    state.enroll()
    state.enroll()
    state.verify()
    assert.equal(calls.length, 1)
    assert.equal(calls[0].name, 'enrollFace')
    assert.equal(calls[0].options.overwrite, true)
    calls[0].options.success({ passed: true, outcome: 'PASSED', feature: 'private-test-feature' })
    calls[0].options.complete({})
    assert.equal(state.title, '人脸录入成功')
    assert.equal(state.tone, 'success')
    assert.ok(!JSON.stringify(state).includes('private-test-feature'))
  })

  test(`${file}: deleting a reference requires confirmation`, () => {
    const { state, calls, modals } = loadPage(file)
    state.remove()
    assert.equal(calls.length, 0)
    modals[0].success({ confirm: false })
    assert.equal(calls.length, 0)
    state.remove()
    modals[1].success({ confirm: true })
    assert.equal(calls[0].name, 'deleteFace')
    assert.equal(calls[0].options.faceID, 'demo-user')
    calls[0].options.success({})
    calls[0].options.complete({})
    assert.equal(state.title, '基准已删除')
    assert.equal(state.busy, false)
  })

  test(`${file}: failures release the buttons and unloading cancels active work`, () => {
    const { state, calls, unload } = loadPage(file)
    state.verify()
    calls[0].options.fail({ errMsg: '需要相机权限' })
    calls[0].options.complete({})
    assert.equal(state.message, '需要相机权限')
    assert.equal(state.busy, false)
    state.verify()
    unload()
    assert.equal(calls[2].name, 'cancel')
  })

  test(`${file}: browser preview never simulates recognition success`, () => {
    const { state, calls } = loadPage(file, false)
    for (const action of ['enroll', 'verify', 'remove']) {
      state[action]()
      assert.equal(state.title, '请在 App 真机体验')
      assert.equal(state.tone, 'neutral')
      assert.equal(calls.length, 0)
    }
  })
}
