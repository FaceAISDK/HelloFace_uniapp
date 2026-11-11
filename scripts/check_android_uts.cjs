// Compile the public UTS bridge AND Kotlin with the installed official toolchain.
// No signing, AppID ownership, cloud build, installation or device is required.
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { execFileSync } = require('node:child_process')
const root = path.resolve(__dirname, '..')
const exists = value => value && fs.existsSync(value)
function required(value, label) {
  if (!exists(value)) throw new Error(label)
  return value
}
function gradleHome() {
  if (process.env.GRADLE_HOME) return process.env.GRADLE_HOME
  const distributions = path.join(os.homedir(), '.gradle/wrapper/dists')
  if (!exists(distributions)) return ''
  const versions = fs.readdirSync(distributions).filter(name => /^gradle-8\.[\d.]+-(bin|all)$/.test(name))
    .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }))
  for (const version of versions) {
    const directory = path.join(distributions, version)
    for (const hash of fs.readdirSync(directory)) {
      const home = path.join(directory, hash, version.replace(/-(bin|all)$/, ''))
      if (exists(path.join(home, 'bin', process.platform === 'win32' ? 'gradle.bat' : 'gradle'))) return home
    }
  }
  return ''
}
async function main() {
  const isX = process.argv.includes('--uni-app-x')
  const hbuilder = required(process.env.HBUILDERX_PATH || (process.platform === 'darwin'
    ? '/Applications/HBuilderX.app/Contents/HBuilderX' : ''), 'Set HBUILDERX_PATH to the installed HBuilderX directory.')
  const plugins = path.join(hbuilder, 'plugins')
  required(path.join(plugins, 'uts-development-android'), 'Install the HBuilderX Android UTS development extension first.')
  const sdk = [process.env.ANDROID_HOME, process.env.ANDROID_SDK_ROOT,
    path.join(os.homedir(), 'Library/Android/sdk'), path.join(os.homedir(), 'Android/Sdk'),
    process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, 'Android/Sdk') : '']
    .find(value => value && exists(path.join(value, 'platforms')) && exists(path.join(value, 'build-tools')))
  required(sdk, 'Set ANDROID_HOME to an Android SDK containing platforms and build-tools.')
  let java = process.env.GRADLE_JAVA_HOME || process.env.JAVA_HOME
  if (!java && process.platform === 'darwin') {
    java = execFileSync('/usr/libexec/java_home', ['-v', '17'], { encoding: 'utf8' }).trim()
  }
  required(java && path.join(java, 'bin', process.platform === 'win32' ? 'java.exe' : 'java'), 'Set GRADLE_JAVA_HOME to JDK 17 or a compatible installed JDK.')
  const gradle = required(gradleHome(), 'Set GRADLE_HOME, or install a Gradle 8 distribution in the standard wrapper cache.')
  const userData = required(process.env.USER_DATA_PATH || (process.platform === 'darwin'
    ? path.join(os.homedir(), 'Library/Application Support/HBuilder X')
    : process.platform === 'win32' && process.env.APPDATA ? path.join(process.env.APPDATA, 'HBuilder X') : ''),
    'Set USER_DATA_PATH to the HBuilderX user data directory.')
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'))
  Object.assign(process.env, {
    NODE_ENV: 'development', UNI_PLATFORM: 'app', UNI_UTS_PLATFORM: 'app-android',
    UNI_INPUT_DIR: root, UNI_OUTPUT_DIR: path.join(root, 'unpackage/uts-native-check' + (isX ? '-x' : '')),
    UNI_HBUILDERX_PLUGINS: plugins, HX_DEPENDENCIES_DIR: path.join(root, 'unpackage/cache/uts_api_check_android'),
    HX_Version: JSON.parse(fs.readFileSync(path.join(plugins, 'about/package.json'), 'utf8')).version,
    UNI_APPID: manifest.appid, USER_DATA_PATH: userData, JDK_PATH: sdk, GRADLE_HOME: gradle,
    APP_ROOT: hbuilder, GRADLE_JAVA_HOME: java
  })
  const compiler = require(path.join(plugins, 'uniapp-uts-v1/node_modules/@dcloudio/uni-uts-v1'))
  const result = await compiler.compile(path.join(root, 'uni_modules/HelloFace-Verify'), {
    isX, isPlugin: true, isSingleThread: true
  })
  if (!result || result.errMsg) throw new Error(result?.errMsg || 'The compiler returned no result.')
  require('./check_android_bridge_abi.cjs').assertBridgeAbi(path.join(process.env.UNI_OUTPUT_DIR,
    'uni_modules/HelloFace-Verify/utssdk/app-android/classes.dex'))
  console.log('PASS stable Android bridge JVM names')
  console.log('PASS official UTS + Kotlin compilation: ' + (isX ? 'uni-app x' : 'uni-app'))
}
// The compiler owns persistent worker handles; close this CLI once compilation ends.
main().then(() => process.exit(0)).catch(error => { console.error(error.message); process.exit(1) })
