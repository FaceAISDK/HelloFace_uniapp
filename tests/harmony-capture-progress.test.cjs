const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')
const { test } = require('node:test')
const ts = require('typescript')

function loadProgress(enrollment = true, timeoutMs = 3000) {
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
    UI: { countdownSuffix: "秒" },
    systemDateTime: { TimeType: { STARTUP: 0 }, getUptime: () => now },
    setInterval(tick, interval) { assert.equal(interval, 33); timers.set(++nextID, tick); return nextID },
    clearInterval(id) { timers.delete(id) }
  }, { filename })
  const overlay = new exports.Overlay()
  Object.assign(overlay, { visible: true, canvasReady: true, captured: false,
    captureStartedAt: -1, captureTimer: -1, captureProgress: 0, draws: 0,
    actionTimer: -1, actionDeadline: -1, actionDuration: 0, actionProgress: 0, phase: "动作验证 · 1/2",
    drawMask() { this.draws++ }, flow: { isEnrollment: () => enrollment, actionTimeout: () => timeoutMs, cancel() { cancelled++ } } })
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

test('Harmony confirmation: preview is bounded to 188vp and fits a narrow dialog', () => {
  const source = fs.readFileSync(path.resolve(__dirname, '../uni_modules/HelloFace-Verify/utssdk/app-harmony/HelloFaceVerifyCamera.ets'), 'utf8')
  const methods = source.slice(source.indexOf('  private confirmationWidth('), source.indexOf('  @Builder\n  private ConfirmationDialog('))
  const compiled = ts.transpileModule('exports.Dialog = class {' + methods + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText
  const exports = {}
  vm.runInNewContext(compiled, { exports, UI: { dialogMaxWidth: 360, dialogInset: 24, dialogPadding: 24, dialogPhotoSide: 188 } })
  for (const [width, expected] of [[420, 188], [800, 188], [200, 104]]) {
    const dialog = new exports.Dialog()
    Object.assign(dialog, { viewportWidth: width, safeLeft: 0, safeRight: 0 })
    assert.equal(dialog.confirmationPhotoSide(), expected)
    assert.ok(dialog.confirmationPhotoSide() + 48 <= dialog.confirmationWidth())
  }
})

test('Harmony confirmation: missing preview releases space and short screens keep a scrollable body', () => {
  const source = fs.readFileSync(path.resolve(__dirname, '../uni_modules/HelloFace-Verify/utssdk/app-harmony/HelloFaceVerifyCamera.ets'), 'utf8')
  const methods = source.slice(source.indexOf('  private confirmationWidth('), source.indexOf('  @Builder\n  private ConfirmationDialog('))
  const spec = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../uni_modules/HelloFace-Verify/native-ui.json'), 'utf8'))
  const exports = {}
  vm.runInNewContext(ts.transpileModule('exports.Dialog = class {' + methods + '}', {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS }
  }).outputText, { exports, UI: spec.metrics })
  const dialog = new exports.Dialog()
  Object.assign(dialog, { viewportWidth: 390, viewportHeight: 844, safeLeft: 0, safeRight: 0, safeTop: 47, safeBottom: 34, photo: {} })
  const full = dialog.confirmationBodyHeight()
  dialog.photo = undefined
  assert.equal(full - dialog.confirmationBodyHeight(), 188 + 16)
  dialog.photo = {}
  dialog.viewportHeight = 360
  const body = dialog.confirmationBodyHeight()
  const fixed = 24 * 2 + 32 + 16 * 2 + 50
  assert.ok(body > 0 && body < full)
  assert.ok(body + fixed + 24 * 2 + 47 + 34 <= 360)
})


test('Harmony action countdown: total duration, repeated progress and next action retain one deadline', () => {
  const { overlay, timers, tick } = loadProgress(false)
  overlay.updateActionCountdown('HOLD_STILL', undefined, 2)
  assert.equal(timers.size, 0)
  overlay.updateActionCountdown('PERFORM_ACTION', 'blink', 2)
  assert.equal(overlay.actionDuration, 6000)
  assert.equal(overlay.phase, '动作验证 · 1/2 · 6秒')
  tick(1500)
  assert.equal(overlay.actionProgress, 0.75)
  overlay.phase = '动作验证 · 2/2'
  overlay.updateActionCountdown('PERFORM_ACTION', 'nodHead', 2)
  assert.equal(overlay.actionDeadline, 6000)
  assert.equal(overlay.phase, '动作验证 · 2/2 · 5秒')
  assert.equal(timers.size, 1)
  overlay.updateActionCountdown('WAITING_FOR_FACE', 'nodHead', 2)
  tick(4500)
  assert.equal(overlay.actionProgress, 0.25)
  tick(7000)
  assert.equal(overlay.actionProgress, 0)
  assert.equal(timers.size, 0)
  overlay.updateActionCountdown('PERFORM_ACTION', 'nodHead', 2)
  assert.equal(overlay.actionDeadline, 6000)
  assert.equal(timers.size, 0)
  assert.equal(overlay.captured, false)
})

test('Harmony action countdown: explicit timeout, exit, absent action and frontal hold reset safely', () => {
  const { overlay, timers, tick } = loadProgress(false, 5000)
  for (const stage of ['HOLD_STILL', 'FACE_FORWARD', 'FACE_UNSTABLE', 'FACE_NOT_FRONTAL', 'WAITING_FOR_FACE']) {
    overlay.updateActionCountdown('PERFORM_ACTION', 'blink', 4)
    assert.equal(overlay.actionDuration, 20000)
    overlay.updateActionCountdown(stage, undefined, 4)
    assert.equal(overlay.actionDeadline, -1)
    assert.equal(timers.size, 0)
  }
  overlay.updateActionCountdown('PERFORM_ACTION', 'blink', 4)
  const pending = [...timers.values()][0]
  overlay.aboutToDisappear()
  const draws = overlay.draws
  pending()
  tick(5000)
  assert.equal(timers.size, 0)
  assert.equal(overlay.actionDeadline, -1)
  assert.equal(overlay.draws, draws)
  const enrollment = loadProgress(true)
  enrollment.overlay.updateActionCountdown('PERFORM_ACTION', 'blink', 2)
  assert.equal(enrollment.timers.size, 0)
})
