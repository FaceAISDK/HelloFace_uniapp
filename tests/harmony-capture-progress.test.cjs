const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const { test } = require('node:test')
const ts = require('typescript')

function loadProgress(enrollment = true) {
  const filename = path.resolve(__dirname, '../uni_modules/HelloFace-Verify/utssdk/app-harmony/HelloFaceVerifyCamera.ets')
  const source = fs.readFileSync(filename, 'utf8')
  const methods = source.slice(source.indexOf('  private updateCaptureProgress('), source.indexOf('  private drawMask('))
  const disappear = source.slice(source.indexOf('  aboutToDisappear():'), source.indexOf('  private contentLeft('))
  const constants = source.match(/^const CAPTURE_.*;$/gm).join('\n')
  const compiled = ts.transpileModule(constants + '\nexports.Overlay = class {' + methods + disappear + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText
  let now = 0, nextID = 0, cancelled = 0
  const timers = new Map(), exports = {}
  vm.runInNewContext(compiled, { exports,
    systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => now },
    setInterval(tick, interval) { assert.equal(interval, 33); timers.set(++nextID, tick); return nextID },
    clearInterval(id) { timers.delete(id) }
  }, { filename })
  const overlay = new exports.Overlay()
  Object.assign(overlay, { visible: true, canvasReady: true, captured: false,
    captureStartedAt: -1, captureTimer: -1, captureProgress: 0, draws: 0,
    drawMask() { this.draws++ }, flow: { isEnrollment: () => enrollment, cancel() { cancelled++ } } })
  return { overlay, timers, cancelled: () => cancelled,
    tick(at) { now = at; for (const tick of [...timers.values()]) tick() } }
}

test('Harmony capture ring: one 700ms hold animates, repeated progress does not restart or confirm capture', () => {
  const { overlay, timers, tick } = loadProgress()
  overlay.updateCaptureProgress('WAITING_FOR_FACE')
  assert.equal(timers.size, 0)
  overlay.updateCaptureProgress('HOLD_STILL')
  tick(350)
  assert.equal(overlay.captureProgress, 0.5)
  overlay.updateCaptureProgress('HOLD_STILL')
  assert.equal(timers.size, 1)
  tick(700)
  assert.equal(overlay.captureProgress, 1)
  assert.equal(timers.size, 0)
  overlay.updateCaptureProgress('HOLD_STILL')
  assert.equal(timers.size, 0)
  assert.equal(overlay.captured, false)
})

test('Harmony capture ring: lost, small, multiple, nonfrontal or unstable face resets the hold', () => {
  const { overlay, timers, tick } = loadProgress()
  let now = 0
  for (const stage of ['WAITING_FOR_FACE', 'MULTIPLE_FACES', 'FACE_TOO_SMALL', 'FACE_NOT_FRONTAL', 'FACE_FORWARD', 'FACE_UNSTABLE']) {
    overlay.updateCaptureProgress('HOLD_STILL')
    tick(now += 350)
    assert.equal(overlay.captureProgress, 0.5)
    overlay.updateCaptureProgress(stage)
    assert.equal(overlay.captureProgress, 0)
    assert.equal(overlay.captureStartedAt, -1)
    assert.equal(timers.size, 0)
  }
})

test('Harmony capture ring: verification does not start it, leaving the camera releases its timer', () => {
  const verification = loadProgress(false)
  verification.overlay.updateCaptureProgress('HOLD_STILL')
  assert.equal(verification.timers.size, 0)
  const { overlay, timers, cancelled, tick } = loadProgress()
  overlay.updateCaptureProgress('HOLD_STILL')
  tick(350)
  const pendingTick = [...timers.values()][0]
  overlay.aboutToDisappear()
  assert.equal(timers.size, 0)
  assert.equal(cancelled(), 1)
  assert.equal(overlay.captureProgress, 0)
  assert.equal(overlay.visible, false)
  assert.equal(overlay.canvasReady, false)
  pendingTick()
  assert.equal(overlay.draws, 1)
})
