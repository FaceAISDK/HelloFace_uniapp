<template>
  <scroll-view class="page" scroll-y :show-scrollbar="false">
    <view class="content">
      <text class="brand">HelloFaceVerify · 离线 1:1 人脸识别</text>
      <text class="heading">插件调用示例</text>
      <view class="identity">
        <text class="label">faceID</text>
        <input class="input" v-model="faceID" :disabled="busy" maxlength="64" placeholder="录入与验证使用同一标识" />
      </view>
      <button class="action" :disabled="busy" @click="enroll">相机录入人脸</button>
      <button class="action" :disabled="busy" @click="verify(false)">1:1 人脸识别 + 静默活体</button>
      <button class="action" :disabled="busy" @click="verify(true)">1:1 人脸识别 + 动作活体</button>
      <button class="action" :disabled="busy" @click="syncImage">同步外部人脸图片</button>
      <button class="action" :disabled="busy" @click="syncFeature">同步外部人脸特征</button>
      <button class="action" :disabled="busy" @click="remove">删除人脸信息</button>
      <text class="sync-hint">同步示例使用 AI 人脸，faceID 为 external-demo；本人验证请先相机录入。</text>
      <view class="result-card">
        <view class="result-heading">
          <text class="result-title">调用结果</text>
          <text class="result-label">RESULT</text>
        </view>
        <text class="result-text">{{ resultText }}</text>
        <text class="hint">是否通过以 passed 为准，分数仅供参考。</text>
      </view>
    </view>
  </scroll-view>
</template>
<script>
// #ifdef APP
import { enrollFace, verifyFace, syncFaceImage, syncFaceFeature, deleteFace, cancel } from '@/uni_modules/HelloFace-Verify'
import { demoImageBase64, demoFeature, demoFeatureSpaceID } from '@/demo/face-reference.js'
// #endif
export default {
  data() {
    return { faceID: 'demo-user', busy: false, resultText: '先录入或同步基准，再使用同一 faceID 验证。' }
  },
  onUnload() {
    // #ifdef APP
    if (this.busy) cancel()
    // #endif
  },
  methods: {
    enroll() {
      if (!this.begin('正在录入人脸…')) return
      // #ifdef APP
      enrollFace({
        faceID: this.faceID,
        overwrite: true, // 方便重复体验；仍需在原生页面确认保存。
        success: (result) => { this.showResult(result) },
        fail: (error) => { this.showError(error) },
        complete: (_) => { this.busy = false }
      })
      // #endif
    },
    verify(withActions) {
      if (!this.begin('正在验证身份…')) return
      // #ifdef APP
      verifyFace({
        faceID: this.faceID,
        threshold: 0.80,
        silentLiveness: true,
        actions: withActions ? ['blink', 'nodHead'] : [], // 动作模式同时保留静默活体。
        success: (result) => { this.showResult(result) },
        fail: (error) => { this.showError(error) },
        complete: (_) => { this.busy = false }
      })
      // #endif
    },
    syncImage() {
      if (!this.begin('正在同步示例基准…')) return
      // #ifdef APP
      this.faceID = 'external-demo' // 独立示例标识，保留相机录入的 demo-user。
      syncFaceImage({
        faceID: this.faceID, imageBase64: demoImageBase64, overwrite: true,
        success: (result) => { this.showResult(result) },
        fail: (error) => { this.showError(error) },
        complete: (_) => { this.busy = false }
      })
      // #endif
    },
    syncFeature() {
      if (!this.begin('正在同步示例基准…')) return
      // #ifdef APP
      this.faceID = 'external-demo' // 独立示例标识，保留相机录入的 demo-user。
      syncFaceFeature({
        faceID: this.faceID, feature: demoFeature, featureSpaceID: demoFeatureSpaceID, overwrite: true,
        success: (result) => { this.showResult(result) },
        fail: (error) => { this.showError(error) },
        complete: (_) => { this.busy = false }
      })
      // #endif
    },
    remove() {
      if (!this.begin('等待删除确认…')) return
      // #ifdef APP
      uni.showModal({
        title: '删除人脸信息', content: '确认删除「' + this.faceID + '」的本机人脸基准？',
        success: (modal) => {
          if (!modal.confirm) { this.busy = false; this.resultText = '已取消'; return }
          deleteFace({
            faceID: this.faceID,
            success: (result) => { this.showResult(result) },
            fail: (error) => { this.showError(error) },
            complete: (_) => { this.busy = false }
          })
        },
        fail: (_) => { this.busy = false; this.resultText = '操作未完成' }
      })
      // #endif
    },
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
      this.resultText = message
      return true
      // #endif
    },
    // #ifdef APP
    showResult(result) {
      const lines = ['code: ' + result.code, 'msg: ' + result.msg, 'faceID: ' + result.faceID]
      if (result.passed != null) lines.push('passed: ' + result.passed)
      if (result.similarity != null) lines.push('similarity: ' + result.similarity.toFixed(3))
      if (result.livenessScore != null) lines.push('livenessScore: ' + result.livenessScore.toFixed(3))
      this.resultText = lines.join('\n')
    },
    showError(error) {
      this.resultText = 'code: ' + error.code + '\nmsg: ' + error.msg + '\nfaceID: ' + error.faceID
    }
    // #endif
  }
}
</script>
<style>
.page { height: 100%; flex: 1; background-color: #F4F5F9; }
.content { display: flex; flex-direction: column; width: 100%; max-width: 680px; margin: 0 auto; padding: 22px 16px 28px; }
.brand { color: #6865C6; font-size: 12px; font-weight: bold; }
.heading { color: #6865C6; font-size: 24px; font-weight: bold; margin-top: 7px; margin-bottom: 20px; }
.identity { display: flex; flex-direction: row; align-items: center; padding: 0 4px; margin-bottom: 14px; }
.label { color: #7C8190; font-size: 13px; margin-right: 12px; }
.input { flex: 1; height: 36px; padding: 0 10px; border: 1px solid #E2E5EA; border-radius: 6px; background-color: #FFFFFF; color: #374151; font-size: 14px; }
.action { width: 100%; height: 54px; line-height: 52px; margin: 0 0 12px; padding: 0 18px; text-align: left; border: 1px solid #72CCAE; border-radius: 9px; background-color: #FFFFFF; color: #397D4B; font-size: 16px; font-weight: bold; }
.sync-hint { color: #7C8190; font-size: 11px; line-height: 18px; margin-bottom: 12px; }
.result-card { display: flex; flex-direction: column; margin-top: 18px; padding: 14px; border: 1px solid #E2E5EA; border-radius: 11px; background-color: #FFFFFF; }
.result-heading { display: flex; flex-direction: row; align-items: center; justify-content: space-between; margin-bottom: 12px; }
.result-title { color: #303540; font-size: 14px; font-weight: bold; }
.result-label { color: #9A9DA6; font-size: 11px; }
.result-text { min-height: 150px; padding: 12px; border: 1px solid #E9EBEF; border-radius: 8px; background-color: #F6F7F9; color: #6865C6; font-size: 14px; line-height: 23px; }
.hint { color: #9A9DA6; font-size: 10px; line-height: 18px; text-align: left; margin-top: 10px; }
</style>
