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
function loadPage(filename, app = true, windowWidth = 480) {
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
  const calls = [], modals = [], toasts = [], loading = [], uiEvents = [], exports = {}
  const sandbox = {
    exports, demoImageBase64: 'demo-photo', demoFeature: 'demo-feature', demoFeatureSpaceID: 'jdx-feature-v1',
    uni: {
      getWindowInfo: () => ({ windowWidth }), hideKeyboard() {}, showModal: options => modals.push(options),
      showToast: options => { toasts.push(options); uiEvents.push('toast') },
      showLoading: options => { loading.push(options); uiEvents.push('loading') }, hideLoading: () => uiEvents.push('hideLoading')
    }
  }
  for (const name of ['syncFaceImage', 'syncFaceFeature', 'enrollFace', 'verifyFace', 'detectLiveness', 'getFaceFeature', 'deleteFace', 'cancel']) {
    sandbox[name] = options => calls.push({ name, options })
  }
  vm.runInNewContext(outputText, sandbox, { filename })
  const page = exports.default
  const state = page.data()
  state.$nextTick = callback => callback()
  for (const [name, getter] of Object.entries(page.computed || {})) {
    Object.defineProperty(state, name, { get: getter.bind(state) })
  }
  for (const [name, method] of Object.entries(page.methods)) state[name] = method.bind(state)
  return { state, calls, modals, toasts, loading, uiEvents, unload: () => page.onUnload.call(state) }
}

for (const file of ['pages/index/index.vue', 'examples/uni-app-x/pages/index/index.uvue']) {
  test(`${file}: camera results display the latest frame at its original aspect ratio`, () => {
    const { state, calls, unload } = loadPage(file)
    const frame = { code: 0, msg: '检测通过', faceID: '', passed: true, frameJpegBase64: '/9j/2Q==' }
    state.detect()
    calls[0].options.success({ ...frame, frameWidth: 540, frameHeight: 720 })
    calls[0].options.complete({})
    const first = state.resultFrames[0]
    assert.equal(first.src, 'data:image/jpeg;base64,/9j/2Q==')
    assert.deepEqual([first.width, first.height], [90, 120])
    assert.equal(state.resultScrollTarget, 'demo-result')
    assert.equal(state.resultTitle, '独立活体检测')
    state.verify()
    assert.equal(state.resultFrames.length, 0)
    assert.equal(state.resultScrollTarget, '')
    calls[1].options.success({ ...frame, code: 201, msg: '人脸不匹配', passed: false, frameWidth: 720, frameHeight: 405 })
    const second = state.resultFrames[0]
    assert.deepEqual([second.width, second.height], [160, 90])
    assert.equal(state.resultStatus, '人脸不匹配')
    state.onResultFrameError(first.generation)
    assert.equal(state.resultFrames[0], second)
    calls[1].options.complete({})
    unload()
    assert.equal(state.resultFrames.length, 0)
  })

  test(`${file}: narrow layouts and image decode failures keep the outcome readable`, () => {
    const { state, calls, unload } = loadPage(file, true, 320)
    const scrolls = []
    state.$nextTick = callback => scrolls.push(callback)
    state.detect()
    calls[0].options.success({ code: 0, msg: '活体通过', passed: true, livenessScore: 0.99,
      frameJpegBase64: '/9j/2Q==', frameWidth: 720, frameHeight: 405 })
    calls[0].options.complete({})
    const frame = state.resultFrames[0]
    assert.deepEqual([frame.width, frame.height], [108, 61])
    state.onResultFrameError(frame.generation)
    assert.equal(state.resultFrames.length, 0)
    assert.equal(state.resultStatus, '活体通过')
    assert.equal(state.resultText, '活体分数：0.9900')
    state.verify()
    scrolls.shift()()
    assert.equal(state.resultScrollTarget, '')
    calls[1].options.fail({ code: 103, msg: '已取消', faceID: 'demo-user' })
    calls[1].options.complete({})
    assert.equal(state.resultStatusTone, 'result-cancelled')
    assert.equal(state.resultFrames.length, 0)
    unload()
    scrolls.shift()()
    assert.equal(state.resultScrollTarget, '')
  })

  test(`${file}: missing reference shows an immediate toast and complete unlocks retry`, () => {
    const { state, calls, toasts } = loadPage(file)
    state.verify()
    calls[0].options.fail({ code: 105, msg: '请先录入', faceID: 'demo-user' })
    assert.equal(toasts.length, 1)
    assert.equal(toasts[0].title, '请先录入，code: 105')
    assert.equal(toasts[0].icon, 'none')
    assert.equal(state.resultText, '返回码：105')
    assert.equal(state.busy, true)
    calls[0].options.complete({})
    assert.equal(state.busy, false)
    state.verify()
    assert.equal(calls.length, 2)
    calls[1].options.fail({ code: 103, msg: '已取消', faceID: 'demo-user' })
    assert.equal(toasts.length, 2)
    assert.equal(toasts[1].title, '已取消，code: 103')
  })
  test(`${file}: demo sync keeps the current faceID without enrollment or reading device features`, () => {
    const { state, calls, loading, uiEvents } = loadPage(file)
    state.syncImage()
    assert.equal(calls[0].name, 'syncFaceImage')
    assert.equal(loading[0].title, '正在同步图片')
    assert.equal(loading[0].mask, true)
    assert.equal(state.busy, true)
    assert.equal(calls[0].options.imageBase64, 'demo-photo')
    assert.equal(calls[0].options.faceID, 'demo-user')
    assert.equal(state.faceID, 'demo-user')
    assert.equal(calls[0].options.overwrite, true)
    calls[0].options.success({ code: 0, msg: '同步成功', faceID: 'demo-user', passed: null })
    calls[0].options.complete({})
    assert.ok(!state.resultText.includes('passed:'))
    assert.deepEqual(uiEvents.slice(-2), ['hideLoading', 'toast'])
    assert.equal(state.busy, false)
    state.faceID = 'chosen-user'
    state.syncFeature()
    assert.equal(calls[1].name, 'syncFaceFeature')
    assert.equal(calls[1].options.feature, 'demo-feature')
    assert.equal(calls[1].options.featureSpaceID, 'jdx-feature-v1')
    assert.equal(calls[1].options.faceID, 'chosen-user')
    assert.equal(state.faceID, 'chosen-user')
    assert.equal(calls[1].options.overwrite, true)
    assert.equal(loading[1].title, '正在同步特征')
    calls[1].options.fail({ code: 302, msg: '存储异常', faceID: 'chosen-user' })
    calls[1].options.complete({})
    assert.deepEqual(uiEvents.slice(-2), ['hideLoading', 'toast'])
    assert.equal(state.busy, false)
    assert.equal(calls.length, 2)
  })
  test(`${file}: verification displays the SDK verdict and retains the submitted liveness mode`, () => {
    const { state, calls } = loadPage(file)
    state.changeActions({ detail: { value: true } })
    state.verify()
    const options = calls[0].options
    assert.equal(options.faceID, 'demo-user')
    // 阈值使用插件默认值；静默活体必须显式传递用户选择。
    assert.equal(options.threshold, undefined)
    assert.equal(options.silentLiveness, true)
    assert.deepEqual(Array.from(options.actions), ['blink', 'nodHead'])
    options.success({ code: 202, msg: '活体未通过', errMsg: 'verifyFace:ok', faceID: 'demo-user', passed: false,
      outcome: 'SPOOF_DETECTED', similarity: 0.999, livenessScore: null })
    options.complete({})
    assert.equal(state.resultStatus, '活体未通过')
    assert.equal(state.resultStatusTone, 'result-rejected')
    assert.equal(state.resultText, '相似度：0.9990')
    assert.equal(state.busy, false)
    assert.equal(state.resultMode, '静默 + 动作活体 · 眨眼、点头')
    state.changeActions({ detail: { value: false } })
    assert.equal(state.resultMode, '静默 + 动作活体 · 眨眼、点头') // 切换下次选项不改写上次结果的模式。
    state.verify()
    assert.deepEqual(Array.from(calls[1].options.actions), [])
    assert.equal(calls[1].options.silentLiveness, true)
  })

  test(`${file}: all four liveness choices reach verifyFace independently and stay locked while busy`, () => {
    for (const [silent, actions, mode] of [
      [false, false, '仅人脸比对'], [true, false, '仅静默活体'],
      [false, true, '仅动作活体'], [true, true, '静默 + 动作活体']
    ]) {
      const { state, calls } = loadPage(file)
      assert.equal(state.silentLiveness, true)
      assert.equal(state.actionLiveness, false)
      state.changeSilent({ detail: { value: silent } })
      state.changeActions({ detail: { value: actions } })
      assert.equal(state.verificationMode, mode)
      state.verify()
      assert.equal(calls[0].name, 'verifyFace')
      assert.equal(calls[0].options.silentLiveness, silent)
      assert.deepEqual(Array.from(calls[0].options.actions), actions ? ['blink', 'nodHead'] : [])
      assert.equal(state.resultMode, mode + (actions ? ' · 眨眼、点头' : ''))
      state.changeSilent({ detail: { value: !silent } })
      state.changeActions({ detail: { value: !actions } })
      state.verify()
      assert.equal(calls.length, 1)
      assert.equal(state.silentLiveness, silent)
      assert.equal(state.actionLiveness, actions)
      calls[0].options.complete({})
      state.syncImage()
      assert.equal(state.resultMode, '')
    }
  })

  test(`${file}: standalone liveness needs no faceID, keeps its own action choice and snapshots the submitted mode`, () => {
    const { state, calls } = loadPage(file)
    state.faceID = ''
    state.changeSilent({ detail: { value: false } })
    state.changeActions({ detail: { value: false } })
    assert.equal(state.livenessActions, false)
    state.detect()
    const options = calls[0].options
    assert.equal(calls[0].name, 'detectLiveness')
    assert.equal(options.faceID, undefined)
    assert.equal(options.referenceFeature, undefined)
    assert.equal(options.silentLiveness, undefined) // SDK 始终静默；页面不传虚假的关闭参数。
    assert.deepEqual(Array.from(options.actions), [])
    state.changeLivenessActions({ detail: { value: true } })
    state.detect()
    state.verify()
    assert.equal(state.livenessActions, false)
    assert.equal(calls.length, 1)
    options.success({ code: 203, msg: '未检测到人脸', faceID: '', passed: false,
      similarity: null, livenessScore: 0.123, feature: null })
    options.complete({})
    assert.equal(state.busy, false)
    assert.equal(state.resultStatus, '未检测到人脸')
    assert.equal(state.resultStatusTone, 'result-rejected')
    assert.equal(state.resultText, '活体分数：0.1230')
    assert.equal(state.resultMode, '独立活体 · 仅静默活体')
    state.changeLivenessActions({ detail: { value: true } })
    assert.equal(state.resultMode, '独立活体 · 仅静默活体')
    state.detect()
    assert.equal(calls[1].name, 'detectLiveness')
    assert.deepEqual(Array.from(calls[1].options.actions), ['blink', 'nodHead'])
    assert.equal(state.resultMode, '独立活体 · 静默 + 动作活体 · 眨眼、点头')
    assert.equal(state.actionLiveness, false) // 独立活体选项不改写身份验证的选择。
  })

  test(`${file}: standalone liveness reports permission errors and cancels on leaving`, () => {
    const { state, calls, unload } = loadPage(file)
    state.detect()
    calls[0].options.fail({ code: 102, msg: '相机未授权', faceID: '' })
    calls[0].options.complete({})
    assert.equal(state.busy, false)
    assert.equal(state.resultStatus, '相机未授权')
    assert.equal(state.resultText, '返回码：102')
    state.detect()
    unload()
    assert.deepEqual(calls.map(call => call.name), ['detectLiveness', 'detectLiveness', 'cancel'])
  })

  test(`${file}: every nonempty action selection reaches both APIs in displayed order`, () => {
    const available = ['blink', 'openMouth', 'shakeHead', 'nodHead']
    for (const standalone of [false, true]) {
      for (let mask = 1; mask < 16; mask++) {
        const { state, calls } = loadPage(file)
        const selected = available.filter((_, index) => mask & (1 << index))
        state[standalone ? 'changeLivenessActions' : 'changeActions']({ detail: { value: true } })
        state.changeSelectedActions({ detail: { value: selected.slice().reverse() } }, standalone)
        state[standalone ? 'detect' : 'verify']()
        assert.equal(calls[0].name, standalone ? 'detectLiveness' : 'verifyFace')
        assert.deepEqual(Array.from(calls[0].options.actions), selected)
        assert.ok(state.resultMode.endsWith(state.actionNames(selected)))
      }
    }
  })

  test(`${file}: enabled actions cannot become empty or silently submit without a challenge`, () => {
    for (const standalone of [false, true]) {
      const { state, calls, toasts } = loadPage(file)
      const switchMethod = standalone ? 'changeLivenessActions' : 'changeActions'
      const selectedKey = standalone ? 'detectActions' : 'verifyActions'
      const start = standalone ? 'detect' : 'verify'
      state[switchMethod]({ detail: { value: true } })
      state.changeSelectedActions({ detail: { value: ['openMouth'] } }, standalone)
      state.changeSelectedActions({ detail: { value: [] } }, standalone)
      assert.deepEqual(Array.from(state[selectedKey]), ['openMouth'])
      assert.equal(toasts.at(-1).title, '请至少选择一个动作')
      // 提交处也校验，避免状态被外部清空时降级成无动作验证。
      state[selectedKey] = []
      state[start]()
      assert.equal(calls.length, 0)
      assert.equal(state.busy, false)
      state[switchMethod]({ detail: { value: false } })
      state[switchMethod]({ detail: { value: true } })
      assert.ok(state[selectedKey].length > 0)
      state[start]()
      assert.ok(calls[0].options.actions.length > 0)
    }
  })

  test(`${file}: action selections stay independent, locked while busy and retained when switched off`, () => {
    const { state, calls } = loadPage(file)
    state.changeActions({ detail: { value: true } })
    state.changeSelectedActions({ detail: { value: ['openMouth', 'shakeHead'] } }, false)
    state.changeLivenessActions({ detail: { value: true } })
    state.changeSelectedActions({ detail: { value: ['nodHead'] } }, true)
    state.verify()
    const submitted = calls[0].options.actions
    const snapshot = state.resultMode
    assert.match(snapshot, /张嘴、摇头/)
    state.changeSelectedActions({ detail: { value: ['blink'] } }, false)
    state.changeSelectedActions({ detail: { value: ['blink'] } }, true)
    assert.deepEqual(Array.from(state.verifyActions), ['openMouth', 'shakeHead'])
    assert.deepEqual(Array.from(state.detectActions), ['nodHead'])
    calls[0].options.complete({})
    state.changeSelectedActions({ detail: { value: ['blink'] } }, false)
    assert.equal(state.resultMode, snapshot)
    assert.deepEqual(Array.from(submitted), ['openMouth', 'shakeHead'])
    state.changeActions({ detail: { value: false } })
    state.verify()
    assert.deepEqual(Array.from(calls[1].options.actions), [])
    calls[1].options.complete({})
    state.changeActions({ detail: { value: true } })
    assert.deepEqual(Array.from(state.verifyActions), ['blink'])
    state.detect()
    assert.deepEqual(Array.from(calls[2].options.actions), ['nodHead'])
  })

  test(`${file}: enrollment calls the plugin directly without retaining biometric features`, () => {
    const { state, calls } = loadPage(file)
    state.enroll()
    state.enroll()
    state.verify()
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
    const { state, calls, modals, unload } = loadPage(file)
    state.remove()
    assert.equal(calls.length, 0)
    state.verify()
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
    state.remove()
    unload()
    modals[2].success({ confirm: true }) // 离页后的系统弹窗不能再删除基准。
    assert.equal(calls.filter(call => call.name == 'deleteFace').length, 1)
  })

  test(`${file}: failures release the buttons and unloading cancels active work`, () => {
    const { state, calls, unload, toasts } = loadPage(file)
    state.verify()
    calls[0].options.fail({ code: 102, msg: '相机未授权', errCode: 9011002, sdkCode: 'PERMISSION_DENIED',
      faceID: 'demo-user', errMsg: 'verifyFace:fail 相机未授权', detail: 'Original camera diagnostics' })
    calls[0].options.complete({})
    assert.equal(state.resultStatus, '相机未授权')
    assert.equal(state.resultText, '返回码：102')
    assert.equal(state.busy, false)
    state.verify()
    unload()
    assert.equal(calls[2].name, 'cancel')
    assert.equal(state.busy, false)
    const message = state.resultText, toastCount = toasts.length
    calls[1].options.fail({ code: 103, msg: '已取消', faceID: 'demo-user' })
    calls[1].options.complete({})
    assert.equal(toasts.length, toastCount)
    assert.equal(state.resultText, message)
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
    for (const action of ['enroll', 'verify', 'detect', 'remove']) {
      state[action]()
      assert.match(state.resultText, /请在 App 真机体验/)
      assert.equal(state.busy, false)
      assert.equal(calls.length, 0)
    }
  })
}
