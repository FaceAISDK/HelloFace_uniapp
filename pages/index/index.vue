<template>
  <view class="page">
    <text class="title">HelloFace</text>
    <text class="subtitle">离线 1:1 人脸录入与识别</text>
    <view class="card">
      <text>用户标识</text>
      <input v-model="faceID" class="input" maxlength="64" placeholder="请输入 faceID" />
      <view class="setting"><text>静默活体校验</text><switch :checked="silentLiveness" @change="silentLiveness = $event.detail.value" /></view>
      <view class="setting"><text>眨眼 + 点头动作</text><switch :checked="useActions" @change="useActions = $event.detail.value" /></view>
      <text class="note">录入后需确认才保存。重复录入默认保留已有特征。</text>
      <button type="primary" :disabled="busy" @click="enroll">录入人脸</button>
      <button :disabled="busy" @click="verify">验证是否本人</button>
      <button :disabled="busy" @click="remove">删除此用户的人脸</button>
    </view>
    <view class="card"><text class="result">{{ message }}</text></view>
  </view>
</template>
<script>
// #ifdef APP
import { enrollFace, verifyFace, deleteFace, cancel } from '@/uni_modules/HelloFace'
// #endif
export default {
  data() { return { faceID: 'demo-user', silentLiveness: true, useActions: false, busy: false, message: '请输入用户标识，然后录入人脸。' } },
  onUnload() {
    // #ifdef APP
    cancel({})
    // #endif
  },
  methods: {
    enroll() {
      // #ifdef APP
      this.busy = true
      enrollFace({ faceID: this.faceID, onProgress: p => { this.message = '录入中：' + p.stage },
        success: r => { this.message = r.passed ? '人脸录入成功' : '未完成录入：' + r.outcome },
        fail: e => { this.message = e.errMsg }, complete: () => { this.busy = false } })
      // #endif
      // #ifndef APP
      this.message = '请在 Android、iOS 或鸿蒙真机运行。'
      // #endif
    },
    verify() {
      // #ifdef APP
      this.busy = true
      verifyFace({ faceID: this.faceID, silentLiveness: this.silentLiveness,
        actions: this.useActions ? ['blink', 'nodHead'] : [], threshold: 0.80,
        onProgress: p => { this.message = '识别中：' + p.stage },
        success: r => { this.message = r.passed === true ? '验证通过，相似度：' + r.similarity : '验证未通过：' + r.outcome },
        fail: e => { this.message = e.errMsg }, complete: () => { this.busy = false } })
      // #endif
      // #ifndef APP
      this.message = '请在 Android、iOS 或鸿蒙真机运行。'
      // #endif
    },
    remove() {
      uni.showModal({ title: '删除人脸', content: '删除 ' + this.faceID + ' 的本地特征？', success: modal => {
        if (!modal.confirm) return
        // #ifdef APP
        this.busy = true
        deleteFace({ faceID: this.faceID, success: () => { this.message = '本地人脸特征已删除' },
          fail: e => { this.message = e.errMsg }, complete: () => { this.busy = false } })
        // #endif
      } })
    }
  }
}
</script>
<style>
.page { padding: 28px 20px; }
.title { display: block; font-size: 32px; font-weight: bold; }
.subtitle { display: block; color: #62758d; margin: 8px 0 24px; }
.card { padding: 20px; background: #fff; border-radius: 16px; margin-bottom: 20px; }
.input { background: #f0f4fa; border-radius: 8px; padding: 14px; margin: 12px 0 20px; }
.setting { display: flex; align-items: center; justify-content: space-between; margin: 16px 0; }
.note { color: #62758d; font-size: 13px; line-height: 1.6; }
.result { line-height: 1.8; word-break: break-all; }
</style>
