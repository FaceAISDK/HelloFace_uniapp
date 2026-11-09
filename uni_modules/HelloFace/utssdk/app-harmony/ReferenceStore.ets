import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { huks } from '@kit.UniversalKeystoreKit';
import { BridgeError } from './BridgeTypes';

/** HUKS owns the nonexportable AES key. Preferences contains only AES-GCM ciphertext. */
export class ReferenceStore {
  private readonly context: common.UIAbilityContext;
  private readonly alias: string = 'helloface.references.aes.v1';
  private readonly base64: util.Base64Helper = new util.Base64Helper();
  private readonly encoder: util.TextEncoder = util.TextEncoder.create('utf-8');
  private readonly decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { fatal: true });
  constructor(context: common.UIAbilityContext) { this.context = context; }
  private account(faceID: string): string { return `jdx-feature-v1:${faceID}`; }

  async get(faceID: string): Promise<string | undefined> {
    try {
      const store = await preferences.getPreferences(this.context, 'helloface.references.v1');
      const encoded = await store.get(this.account(faceID), '');
      if (typeof encoded !== 'string') throw new Error('Invalid stored reference');
      if (encoded.length === 0) return undefined;
      const data: Uint8Array = this.base64.decodeSync(encoded);
      if (data.byteLength <= 29 || data[0] !== 1) throw new Error('Invalid reference envelope');
      const nonce: Uint8Array = data.slice(1, 13);
      const payload: Uint8Array = data.slice(13, data.byteLength - 16);
      const tag: Uint8Array = data.slice(data.byteLength - 16);
      const clear: Uint8Array = await this.crypt(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT,
        payload, nonce, this.encoder.encodeInto(this.account(faceID)), tag);
      try { return this.decoder.decodeToString(clear); } finally { clear.fill(0); }
    } catch (error) { throw new BridgeError('STORAGE_ERROR', `Unable to read face reference: ${error}`); }
  }
  async save(faceID: string, feature: string): Promise<void> {
    try {
      const exists: boolean = await huks.hasKeyItem(this.alias, { properties: [] });
      if (!exists) {
        await huks.generateKeyItem(this.alias, { properties: [
          { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
          { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
          { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT }
        ] });
      }
      const nonce: Uint8Array = (await cryptoFramework.createRandom().generateRandom(12)).data;
      const clear: Uint8Array = this.encoder.encodeInto(feature);
      let encrypted: Uint8Array;
      try {
        encrypted = await this.crypt(huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT,
          clear, nonce, this.encoder.encodeInto(this.account(faceID)), undefined);
      } finally { clear.fill(0); }
      const data: Uint8Array = new Uint8Array(13 + encrypted.byteLength);
      data[0] = 1; data.set(nonce, 1); data.set(encrypted, 13);
      const store = await preferences.getPreferences(this.context, 'helloface.references.v1');
      await store.put(this.account(faceID), this.base64.encodeToStringSync(data));
      await store.flush();
    } catch (error) { throw new BridgeError('STORAGE_ERROR', `Unable to save face reference: ${error}`); }
  }
  async delete(faceID: string): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.context, 'helloface.references.v1');
      await store.delete(this.account(faceID));
      await store.flush();
    } catch (error) { throw new BridgeError('STORAGE_ERROR', `Unable to delete face reference: ${error}`); }
  }
  private async crypt(purpose: huks.HuksKeyPurpose, input: Uint8Array, nonce: Uint8Array,
    aad: Uint8Array, tag: Uint8Array | undefined): Promise<Uint8Array> {
    const properties: huks.HuksParam[] = [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
      { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
      { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: aad }
    ];
    if (tag !== undefined) properties.push({ tag: huks.HuksTag.HUKS_TAG_AE_TAG, value: tag });
    const options: huks.HuksOptions = { properties: properties, inData: input };
    const handle: number = (await huks.initSession(this.alias, options)).handle;
    try {
      const output = (await huks.finishSession(handle, options)).outData;
      if (output === undefined) throw new Error('HUKS returned no output');
      return output;
    } catch (error) {
      try { await huks.abortSession(handle, { properties: [] }); } catch (_) {}
      throw new Error(`HUKS operation failed: ${error}`);
    }
  }
}
