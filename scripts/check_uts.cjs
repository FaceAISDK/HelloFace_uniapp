// Exercise the installed official HBuilderX UTS compiler without signing an App.
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const root = path.resolve(__dirname, '..')
const hbuilder = process.env.HBUILDERX_PATH || '/Applications/HBuilderX.app/Contents/HBuilderX'
const compiler = require(path.join(hbuilder, 'plugins/uniapp-uts-v1/node_modules/@dcloudio/uts'))
const output = fs.mkdtempSync(path.join(os.tmpdir(), 'helloface-uts-check-'))

async function main() {
  for (const [target, platform, extension, packageName] of [
    ['Kotlin', 'app-android', 'kt', 'uts.sdk.modules.HelloFaceVerify'],
    ['Swift', 'app-ios', 'swift', 'HelloFaceVerify'],
    ['ArkTS', 'app-harmony', 'ets', 'HelloFaceVerify']
  ]) {
    const result = await compiler['bundle' + target]({ hbxVersion: '5.34',
      input: { root, filename: path.join(root, 'uni_modules/HelloFace-Verify/utssdk', platform, 'index.uts'),
        paths: {}, externals: ['./HelloFaceVerifyNative.ets'] },
      output: { outDir: path.join(output, platform), package: packageName, extname: extension,
        isPlugin: true, isApp: true } })
    if (result.error) throw result.error
    if (!result.filename) throw new Error(target + ' produced no output')
    console.log('PASS UTS -> ' + target)
  }
  console.log('Generated sources: ' + output)
}
main().catch(error => { console.error(error); process.exitCode = 1 })
