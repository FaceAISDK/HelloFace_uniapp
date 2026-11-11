const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const { test } = require('node:test')
const ts = require('typescript')
const flush = () => new Promise(resolve => setImmediate(resolve))

// Run the actual flow/window cleanup. Only the OS window and camera boundary are replaced.
function loadFlow(brightness = -1, keepScreenOn = false) {
  const filename = path.resolve(__dirname, '../uni_modules/HelloFace-Verify/utssdk/app-harmony/HelloFaceVerifyCamera.ets')
  const source = fs.readFileSync(filename, 'utf8')
  const compiled = ts.transpileModule(source.slice(source.indexOf('export class CameraFlow')), {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText
  const changes = [], results = [], exports = {}
  const prompt = { openCustomDialog: async () => {}, closeCustomDialog: async () => {} }
  const mainWindow = {
    on() {}, off() {},
    getUIContext: () => ({ px2vp: n => n, getPromptAction: () => prompt }),
    getWindowProperties: () => ({ brightness, isKeepScreenOn: keepScreenOn, windowRect: { width: 360, height: 640 } }),
    getWindowAvoidArea: () => Object.fromEntries(['topRect', 'bottomRect', 'leftRect', 'rightRect'].map(k => [k, { width: 0, height: 0 }])),
    async setWindowKeepScreenOn(value) { changes.push(['keep', value]) },
    async setWindowBrightness(value) { changes.push(['brightness', value]) }
  }
  vm.runInNewContext(compiled, { exports,
    window: { WindowEventType: { WINDOW_HIDDEN: 0 }, AvoidAreaType: { TYPE_SYSTEM: 0, TYPE_NAVIGATION_INDICATOR: 1 } },
    ComponentContent: class { dispose() {} }, wrapBuilder: fn => fn, cameraDialog() {},
    Color: { Transparent: 0 }, DialogAlignment: { Center: 0 }, ImmersiveMode: { EXTEND: 0 },
    envelope: (...args) => JSON.stringify(args), errorEnvelope: error => error.message,
    BridgeError: class extends Error {}
  }, { filename })
  const flow = new exports.CameraFlow({}, mainWindow, { close() {} }, 'enrollFace', {}, undefined, () => {}, result => results.push(result))
  return { flow, mainWindow, changes, results }
}

test('Harmony screen: capture and restore original window brightness, including system-following mode', async () => {
  for (const previous of [-1, 0.35, 1]) {
    const { flow, changes } = loadFlow(previous)
    flow.open()
    await flow.screenTask
    assert.deepEqual(changes, [['keep', true], ['brightness', 1]])
    await flow.shutdown()
    assert.deepEqual(changes, [['keep', true], ['brightness', 1], ['brightness', previous], ['keep', false]])
    await flow.restoreScreen()
    assert.equal(changes.length, 4)
  }
})

test('Harmony screen: cancel waits for a pending maximum-brightness update before restoring', async () => {
  const { flow, mainWindow, changes, results } = loadFlow(0.42)
  let release
  mainWindow.setWindowBrightness = value => {
    changes.push(['brightness', value])
    return value === 1 ? new Promise(resolve => { release = resolve }) : Promise.resolve()
  }
  flow.open()
  await flush()
  flow.cancel()
  await flush()
  assert.deepEqual(changes, [['keep', true], ['brightness', 1]])
  assert.equal(results.length, 0)
  release()
  await flush()
  assert.deepEqual(changes, [['keep', true], ['brightness', 1], ['brightness', 0.42], ['keep', false]])
  assert.equal(results.length, 1)
})

test('Harmony screen: going to background restores brightness even while enrollment is committing', async () => {
  const { flow, changes, results } = loadFlow(-1, true)
  flow.open()
  await flow.screenTask
  flow.committing = true
  flow.visibility(0)
  await flow.screenTask
  assert.deepEqual(changes, [['keep', true], ['brightness', 1], ['brightness', -1], ['keep', true]])
  assert.equal(results.length, 0)
  flow.committing = false
  flow.cancel()
  await flush()
  assert.equal(changes.length, 4)
  assert.equal(results.length, 1)
})

test('Harmony screen: cancelling before screen setup finishes never applies late maximum brightness', async () => {
  const { flow, mainWindow, changes, results } = loadFlow()
  let release
  mainWindow.setWindowKeepScreenOn = value => {
    changes.push(['keep', value])
    return value ? new Promise(resolve => { release = resolve }) : Promise.resolve()
  }
  flow.open()
  flow.cancel()
  release()
  await flush()
  assert.deepEqual(changes, [['keep', true], ['keep', false]])
  assert.equal(results.length, 1)
})
