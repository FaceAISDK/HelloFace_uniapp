<template>
  <scroll-view class="page" scroll-y :show-scrollbar="false" :scroll-into-view="resultScrollTarget" scroll-with-animation>
    <view class="content">
      <text class="brand">HelloFaceVerify · 离线 1:1 人脸识别</text>
      <view class="identity">
        <text class="label">faceID</text>
        <input class="input" v-model="faceID" :disabled="busy" maxlength="64" placeholder="录入与验证使用同一标识" />
      </view>
      <button class="action" :disabled="busy" @click="enroll">相机录入人脸</button>
      <view class="verification-card">
        <text class="section-title">1:1 人脸验证</text>
        <label class="liveness-row">
          <view class="liveness-copy">
            <text class="liveness-title">静默活体</text>
            <text class="liveness-detail">无需指定动作，检测是否为真人</text>
          </view>
          <switch class="liveness-switch" :checked="silentLiveness" :disabled="busy" color="#6865C6" @change="changeSilent" />
        </label>
        <label class="liveness-row">
          <view class="liveness-copy">
            <text class="liveness-title">动作活体</text>
            <text class="liveness-detail">勾选需要完成的动作</text>
          </view>
          <switch class="liveness-switch" :checked="actionLiveness" :disabled="busy" color="#6865C6" @change="changeActions" />
        </label>
        <view v-if="actionLiveness" class="action-selection">
          <text class="liveness-detail">至少选择一个动作，按下方顺序执行</text>
          <checkbox-group class="action-options" @change="changeSelectedActions($event, false)">
            <label v-for="item in actionOptions" :key="item.value" class="action-option">
              <checkbox class="action-checkbox" :value="item.value" :checked="verifyActions.includes(item.value)"
                :disabled="busy || (verifyActions.length == 1 && verifyActions.includes(item.value))" color="#6865C6" />
              <text class="action-name">{{ item.label }}</text>
            </label>
          </checkbox-group>
        </view>
        <view class="mode-summary">
          <text class="mode-title">{{ verificationMode }}</text>
          <text class="mode-detail">{{ verificationHint }}</text>
        </view>
        <button class="action verify-action" :disabled="busy" @click="verify">开始 1:1 验证</button>
      </view>
      <view class="verification-card">
        <text class="section-title">独立活体检测</text>
        <text class="feature-note">不比对身份，无需 faceID 或基准。静默活体始终开启，可叠加动作。</text>
        <label class="liveness-row">
          <view class="liveness-copy">
            <text class="liveness-title">动作活体</text>
            <text class="liveness-detail">勾选需要完成的动作</text>
          </view>
          <switch class="liveness-switch" :checked="livenessActions" :disabled="busy" color="#6865C6" @change="changeLivenessActions" />
        </label>
        <view v-if="livenessActions" class="action-selection">
          <text class="liveness-detail">至少选择一个动作，按下方顺序执行</text>
          <checkbox-group class="action-options" @change="changeSelectedActions($event, true)">
            <label v-for="item in actionOptions" :key="item.value" class="action-option">
              <checkbox class="action-checkbox" :value="item.value" :checked="detectActions.includes(item.value)"
                :disabled="busy || (detectActions.length == 1 && detectActions.includes(item.value))" color="#6865C6" />
              <text class="action-name">{{ item.label }}</text>
            </label>
          </checkbox-group>
        </view>
        <button class="action verify-action" :disabled="busy" @click="detect">开始活体检测</button>
      </view>
      <view id="demo-result" class="result-card">
        <view class="result-body">
          <view class="result-copy">
            <text v-if="resultStatus.length > 0" class="result-status" :class="resultStatusTone">{{ resultStatus }}</text>
            <text class="result-title">{{ resultTitle.length > 0 ? resultTitle : '调用结果' }}</text>
            <text v-if="resultMode.length > 0" class="result-mode">{{ resultMode }}</text>
            <text v-if="resultText.length > 0" :class="resultTitle.length > 0 ? 'recognition-detail' : 'result-text'">{{ resultText }}</text>
          </view>
          <image v-for="frame in resultFrames" :key="frame.generation" class="result-frame" :src="frame.src" mode="aspectFit"
            :style="{ width: frame.width + 'px', height: frame.height + 'px' }" aria-label="检测结束时的相机画面"
            @error="onResultFrameError(frame.generation)" />
        </view>
      </view>
      <button class="action" :disabled="busy" @click="syncImage">同步演示人脸图片</button>
      <button class="action" :disabled="busy" @click="syncFeature">同步演示人脸特征</button>
      <button class="action" :disabled="busy" @click="remove">删除人脸信息</button>
    </view>
  </scroll-view>
</template>
<script>
// #ifdef APP
import { enrollFace, verifyFace, detectLiveness, syncFaceImage, syncFaceFeature, deleteFace, cancel } from '@/uni_modules/HelloFace-Verify'
import { demoImageBase64, demoFeature, demoFeatureSpaceID } from '@/demo/face-reference.js'
// #endif
export default {
  data() {
    return { faceID: 'demo-user', silentLiveness: true, actionLiveness: false, livenessActions: false, busy: false,
      actionOptions: [{ value: 'blink', label: '眨眼' }, { value: 'openMouth', label: '张嘴' },
        { value: 'shakeHead', label: '摇头' }, { value: 'nodHead', label: '点头' }],
      verifyActions: ['blink', 'nodHead'], detectActions: ['blink', 'nodHead'],
      resultMode: '', resultTitle: '', resultStatus: '', resultStatusTone: '', resultScrollTarget: '', resultGeneration: 0,
      resultFrames: [], resultText: '身份验证需先录入或同步基准；独立活体可直接开始。' }
  },
  computed: {
    verificationMode() {
      if (this.silentLiveness) return this.actionLiveness ? '静默 + 动作活体' : '仅静默活体'
      return this.actionLiveness ? '仅动作活体' : '仅人脸比对'
    },
    verificationHint() {
      if (!this.silentLiveness && !this.actionLiveness) return '两个活体均已关闭，本次只做 1:1 人脸比对。'
      return this.actionLiveness ? '正对镜头，按提示完成' + this.actionNames(this.verifyActions) + '。' : '正对镜头即可，无需做指定动作。'
    }
  },
  onUnload() {
    this.resultGeneration++
    this.resultFrames = []
    // #ifdef APP
    // 先停止结果展示，再取消相机，避免迟到回调在离页后弹出 Toast。
    if (!this.busy) return
    uni.hideLoading()
    this.busy = false
    cancel()
    // #endif
  },
  methods: {
    changeSilent(event) {
      if (!this.busy) this.silentLiveness = event.detail.value
    },
    changeActions(event) {
      if (this.busy) return
      if (event.detail.value && this.verifyActions.length == 0) this.verifyActions = ['blink']
      this.actionLiveness = event.detail.value
    },
    changeLivenessActions(event) {
      if (this.busy) return
      if (event.detail.value && this.detectActions.length == 0) this.detectActions = ['blink']
      this.livenessActions = event.detail.value
    },
    changeSelectedActions(event, standalone) {
      if (this.busy) return
      // 固定执行顺序，不依赖不同平台 checkbox-group 返回值的排列。
      const actions = this.actionOptions.filter(item => event.detail.value.includes(item.value)).map(item => item.value)
      if (!this.requireAction(actions)) return
      if (standalone) this.detectActions = actions
      else this.verifyActions = actions
    },
    actionNames(actions) {
      return this.actionOptions.filter(item => actions.includes(item.value)).map(item => item.label).join('、')
    },
    requireAction(actions) {
      if (actions.length > 0) return true
      uni.showToast({ title: '请至少选择一个动作', icon: 'none' })
      return false
    },
    enroll() {
      if (!this.begin('正在录入人脸…')) return
      // #ifdef APP
      enrollFace({
        faceID: this.faceID,
        overwrite: true, // 方便重复体验；仍需在原生页面确认保存。
        success: this.showResult,
        fail: this.showError,
        complete: this.finish
      })
      // #endif
    },
    verify() {
      if (this.busy || (this.actionLiveness && !this.requireAction(this.verifyActions))) return
      if (!this.begin('正在验证身份…')) return
      this.resultTitle = '1:1 人脸验证'
      this.resultMode = this.verificationMode + (this.actionLiveness ? ' · ' + this.actionNames(this.verifyActions) : '')
      // #ifdef APP
      verifyFace({
        faceID: this.faceID,
        // 两项独立传入；同时开启时，两种活体都参与本次验证。
        silentLiveness: this.silentLiveness,
        actions: this.actionLiveness ? this.verifyActions.slice() : [],
        success: this.showResult,
        fail: this.showError,
        complete: this.finish
      })
      // #endif
    },
    detect() {
      if (this.busy || (this.livenessActions && !this.requireAction(this.detectActions))) return
      if (!this.begin('正在检测活体…')) return
      this.resultTitle = '独立活体检测'
      this.resultMode = '独立活体 · ' + (this.livenessActions ? '静默 + 动作活体 · ' + this.actionNames(this.detectActions) : '仅静默活体')
      // #ifdef APP
      // SDK 的独立活体始终静默；只传可选动作，不传 faceID 或身份基准。
      detectLiveness({
        actions: this.livenessActions ? this.detectActions.slice() : [],
        success: this.showResult,
        fail: this.showError,
        complete: this.finish
      })
      // #endif
    },
    syncImage() {
      if (!this.begin('正在同步图片…')) return
      // #ifdef APP
      uni.showLoading({ title: '正在同步图片', mask: true })
      syncFaceImage({
        faceID: this.faceID, imageBase64: demoImageBase64, overwrite: true,
        success: this.showResult,
        fail: this.showError,
        complete: this.finish
      })
      // #endif
    },
    syncFeature() {
      if (!this.begin('正在同步特征…')) return
      // #ifdef APP
      uni.showLoading({ title: '正在同步特征', mask: true })
      syncFaceFeature({
        faceID: this.faceID, feature: demoFeature, featureSpaceID: demoFeatureSpaceID, overwrite: true,
        success: this.showResult,
        fail: this.showError,
        complete: this.finish
      })
      // #endif
    },
    remove() {
      if (!this.begin('等待删除确认…')) return
      // #ifdef APP
      uni.showModal({
        title: '删除人脸信息', content: '确认删除「' + this.faceID + '」的本机人脸基准？',
        success: (modal) => {
          if (!this.busy) return
          if (!modal.confirm) { this.busy = false; this.resultText = '已取消'; return }
          deleteFace({
            faceID: this.faceID,
            success: this.showResult,
            fail: this.showError,
            complete: this.finish
          })
        },
        fail: (_) => {
          if (!this.busy) return
          this.busy = false
          this.resultText = '操作未完成'
        }
      })
      // #endif
    },
    // complete 仅解锁；加载层在结果回调中先关闭，再显示 Toast，避免互相覆盖。
    // Vue/uvue 的 methods 保持页面 this 绑定，可直接作为 API 回调。
    finish() { this.busy = false },
    // 以下仅处理按钮状态与结果展示；不参与 SDK 判定，不保存原始特征。
    begin(message) {
      if (this.busy) return false
      // #ifndef APP
      this.resultText = '请在 App 真机体验：Android、iOS 或鸿蒙。'
      return false
      // #endif
      // #ifdef APP
      uni.hideKeyboard()
      this.busy = true
      this.resultMode = ''
      this.resultTitle = ''
      this.resultStatus = ''
      this.resultScrollTarget = ''
      this.resultGeneration++
      this.resultFrames = []
      this.resultText = message
      return true
      // #endif
    },
    onResultFrameError(generation) {
      if (generation == this.resultGeneration) this.resultFrames = []
    },
    scrollToCameraResult() {
      const generation = this.resultGeneration
      this.$nextTick(() => {
        if (generation == this.resultGeneration) this.resultScrollTarget = 'demo-result'
      })
    },
    // #ifdef APP
    showResult(result) {
      if (!this.busy) return
      uni.hideLoading()
      if (this.resultTitle.length > 0) {
        this.resultStatus = result.msg
        this.resultStatusTone = result.passed === true ? 'result-passed' : 'result-rejected'
        const scores = []
        if (result.similarity != null) scores.push('相似度：' + result.similarity.toFixed(4))
        if (result.livenessScore != null) scores.push('活体分数：' + result.livenessScore.toFixed(4))
        this.resultText = scores.join('\n')
        const jpeg = result.frameJpegBase64
        const width = result.frameWidth ?? 0
        const height = result.frameHeight ?? 0
        if (typeof jpeg == 'string' && jpeg.length > 0 && width > 0 && height > 0) {
          const contentWidth = Math.min(680, uni.getWindowInfo().windowWidth) - 62
          const maxWidth = Math.max(1, Math.min(160, Math.floor(contentWidth * 0.42)))
          const scale = Math.min(maxWidth / width, 120 / height)
          this.resultFrames = [{ generation: this.resultGeneration, src: 'data:image/jpeg;base64,' + jpeg,
            width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) }]
        }
        this.scrollToCameraResult()
      } else {
        const lines = ['code: ' + result.code, 'msg: ' + result.msg]
        if (result.faceID.length > 0) lines.push('faceID: ' + result.faceID)
        if (result.passed != null) lines.push('passed: ' + result.passed)
        this.resultText = lines.join('\n')
      }
      uni.showToast({ title: result.msg + '，code: ' + result.code, icon: 'none', duration: 2000 })
    },
    showError(error) {
      if (!this.busy) return
      uni.hideLoading()
      if (this.resultTitle.length > 0) {
        this.resultStatus = error.msg
        this.resultStatusTone = error.code == 103 ? 'result-cancelled' : 'result-rejected'
        this.resultText = error.code == 103 ? '' : '返回码：' + error.code
        this.scrollToCameraResult()
      } else {
        this.resultText = 'code: ' + error.code + '\nmsg: ' + error.msg +
          (error.faceID.length > 0 ? '\nfaceID: ' + error.faceID : '')
      }
      uni.showToast({ title: error.msg + '，code: ' + error.code, icon: 'none', duration: 2000 })
    }
    // #endif
  }
}
</script>
<style>
.page { height: 100%; flex: 1; background-color: #F4F5F9; }
.content { display: flex; flex-direction: column; width: 100%; max-width: 680px; margin: 0 auto; padding: 22px 16px 28px; }
.brand { color: #6865C6; font-size: 11px; margin-bottom: 16px; }
.identity { display: flex; flex-direction: row; align-items: center; padding: 0 4px; margin-bottom: 14px; }
.label { color: #7C8190; font-size: 12px; margin-right: 12px; }
.input { flex: 1; height: 36px; padding: 0 10px; border: 1px solid #E2E5EA; border-radius: 6px; background-color: #FFFFFF; color: #374151; font-size: 14px; }
.action { width: 100%; height: 54px; line-height: 52px; margin: 0 0 12px; padding: 0 18px; text-align: left; border: 1px solid #285C5E; border-radius: 9px; background-color: #FFFFFF; color: #285C5E; font-size: 16px; font-weight: bold; }
.verification-card { display: flex; flex-direction: column; margin-bottom: 12px; padding: 16px; border: 1px solid #285C5E; border-radius: 11px; background-color: #FFFFFF; }
.section-title { color: #303540; font-size: 16px; font-weight: bold; margin-bottom: 4px; }
.feature-note { color: #7C8190; font-size: 11px; line-height: 17px; margin-top: 4px; margin-bottom: 6px; }
.liveness-row { display: flex; flex-direction: row; align-items: center; justify-content: space-between; min-height: 60px; }
.liveness-switch { transform: scale(0.8); transform-origin: 100% 50%; }
.liveness-copy { display: flex; flex-direction: column; flex: 1; margin-right: 12px; }
.liveness-title { color: #374151; font-size: 15px; font-weight: bold; }
.liveness-detail { color: #7C8190; font-size: 11px; line-height: 16px; margin-top: 3px; }
.action-selection { display: flex; flex-direction: column; margin-bottom: 6px; }
.action-options { display: flex; flex-direction: row; flex-wrap: wrap; margin-top: 4px; }
.action-option { display: flex; flex-direction: row; align-items: center; width: 25%; min-height: 44px; }
.action-checkbox { transform: scale(0.8); transform-origin: 0% 50%; }
.action-name { color: #374151; font-size: 12px; }
.mode-summary { display: flex; flex-direction: column; padding: 12px; margin-top: 8px; margin-bottom: 14px; border-radius: 8px; background-color: #F2F1FB; }
.mode-title { color: #6865C6; font-size: 14px; font-weight: bold; }
.mode-detail { color: #7C8190; font-size: 11px; line-height: 17px; margin-top: 5px; }
.verify-action { margin-bottom: 0; }
.result-mode { color: #6865C6; font-size: 11px; margin-bottom: 10px; }
.result-card { display: flex; flex-direction: column; margin: 6px 0 14px; padding: 14px; border: 1px solid #E2E5EA; border-radius: 16px; background-color: #FFFFFF; }
.result-body { display: flex; flex-direction: row; align-items: center; }
.result-copy { display: flex; flex-direction: column; flex: 1; min-width: 0; }
.result-status { font-size: 12px; font-weight: bold; margin-bottom: 6px; }
.result-passed { color: #087D65; }
.result-rejected { color: #A02D39; }
.result-cancelled { color: #626775; }
.result-title { color: #303540; font-size: 16px; font-weight: bold; margin-bottom: 8px; }
.recognition-detail { color: #626775; font-size: 13px; line-height: 20px; }
.result-frame { flex-shrink: 0; margin-left: 12px; }
.result-text { min-height: 120px; padding: 12px; border: 1px solid #E9EBEF; border-radius: 8px; background-color: #F6F7F9; color: #6865C6; font-size: 13px; line-height: 21px; }
</style>
