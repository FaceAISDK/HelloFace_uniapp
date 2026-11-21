// Kotlin internal members normally include a compilation-module suffix in their
// JVM names. Cloud bases and HBuilderX local compilation use different modules.
const fs = require('node:fs')
const required = {
  'Luts/sdk/modules/HelloFaceVerify/HelloFaceVerifyNative;':
    ['getMain', 'getWorker', 'getJob', 'setJob', 'getCamera', 'setCamera', 'envelope', 'finish', 'progress'],
  'Luts/sdk/modules/HelloFaceVerify/HelloFaceVerifyCameraActivity;':
    ['getJobID', 'setJobID', 'shutdownCamera']
}

const jsOptions = {
  enrollFaceByJs: 'EnrollFaceOptionsJSONObject', verifyFaceByJs: 'VerifyFaceOptionsJSONObject',
  detectLivenessByJs: 'DetectLivenessOptionsJSONObject', extractFaceFeatureByJs: 'ExtractFaceFeatureOptionsJSONObject',
  getFaceStatueByJs: 'FaceIDOptionsJSONObject', getFaceFeatureByJs: 'FaceIDOptionsJSONObject',
  setFaceFeatureByJs: 'SetFaceFeatureOptionsJSONObject', syncFaceFeatureByJs: 'SetFaceFeatureOptionsJSONObject',
  syncFaceImageByJs: 'SyncFaceImageOptionsJSONObject', deleteFaceByJs: 'FaceIDOptionsJSONObject', cancelByJs: 'CancelOptionsJSONObject'
}

function assertBridgeAbi(filename, options = {}) {
  const dex = fs.readFileSync(filename)
  if (dex.length < 112 || dex.toString('ascii', 0, 4) !== 'dex\n') throw new Error('Expected a compiled DEX file: ' + filename)
  const stringCount = dex.readUInt32LE(56), stringOffset = dex.readUInt32LE(60)
  const typeOffset = dex.readUInt32LE(68)
  const protoOffset = dex.readUInt32LE(76)
  const methodCount = dex.readUInt32LE(88), methodOffset = dex.readUInt32LE(92)
  const strings = new Map()
  function string(index) {
    if (!strings.has(index)) {
      if (index >= stringCount) throw new Error('Invalid DEX string index')
      let offset = dex.readUInt32LE(stringOffset + index * 4)
      while (dex[offset++] & 0x80) {} // Skip the UTF-16 length (ULEB128).
      const end = dex.indexOf(0, offset)
      if (end < 0) throw new Error('Unterminated DEX string')
      strings.set(index, dex.toString('utf8', offset, end))
    }
    return strings.get(index)
  }
  const methods = new Map(Object.keys(required).map(name => [name, new Set()]))
  const bridges = new Map()
  for (let index = 0; index < methodCount; index++) {
    const offset = methodOffset + index * 8
    const owner = string(dex.readUInt32LE(typeOffset + dex.readUInt16LE(offset) * 4))
    const name = string(dex.readUInt32LE(offset + 4))
    if (methods.has(owner)) methods.get(owner).add(name)
    if (owner === 'Luts/sdk/modules/HelloFaceVerify/IndexKt;' && jsOptions[name]) {
      const parameters = dex.readUInt32LE(protoOffset + dex.readUInt16LE(offset + 2) * 12 + 8)
      const count = parameters ? dex.readUInt32LE(parameters) : 0
      const type = count === 1 ? string(dex.readUInt32LE(typeOffset + dex.readUInt16LE(parameters + 4) * 4)) : ''
      bridges.set(name, type)
    }
  }
  // Vue 的 ByJs 必须接收 JSONObject 适配器；二级 type 别名可能只生成普通 Kotlin 类型，编译通过但回调不返回。
  if (options.requireJsBridge) {
    for (const [method, type] of Object.entries(jsOptions)) {
      const expected = 'Luts/sdk/modules/HelloFaceVerify/' + type + ';'
      if (bridges.get(method) !== expected) throw new Error('Invalid JS option adapter for ' + method + ': expected ' + expected + ', got ' + bridges.get(method))
    }
  }
  for (const [owner, names] of Object.entries(required)) {
    const missing = names.filter(name => !methods.get(owner).has(name))
    if (missing.length) throw new Error('Module-dependent Kotlin bridge ABI in ' + owner + ': missing stable ' + missing.join(', ') +
      '. Cross-file internal bridge members must use @PublishedApi; rebuild the base after changing their ABI.')
  }
}

module.exports = { assertBridgeAbi }
if (require.main === module) {
  try {
    assertBridgeAbi(process.argv[2])
    console.log('PASS stable Android bridge JVM names')
  } catch (error) { console.error(error.message); process.exitCode = 1 }
}
