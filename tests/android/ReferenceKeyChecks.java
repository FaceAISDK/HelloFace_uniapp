import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.security.*;
import java.security.cert.Certificate;
import java.security.spec.AlgorithmParameterSpec;
import java.util.Collections;
import java.util.Date;
import java.util.Enumeration;
import javax.crypto.KeyGeneratorSpi;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;

/** Executes compiled production reference reads/writes. The JCE provider is a boundary fixture,
 * not Android Keystore: no phone keys, preferences or biometric data are touched.
 */
public final class ReferenceKeyChecks {
    private static SecretKey existing;
    private static int generationAttempts;
    public static final class Store extends KeyStoreSpi {
        public Key engineGetKey(String alias, char[] password) { return existing; }
        public void engineLoad(InputStream input, char[] password) {}
        public void engineStore(OutputStream output, char[] password) {}
        public Certificate[] engineGetCertificateChain(String alias) { return null; }
        public Certificate engineGetCertificate(String alias) { return null; }
        public Date engineGetCreationDate(String alias) { return null; }
        public void engineSetKeyEntry(String alias, Key key, char[] password, Certificate[] chain) { throw new AssertionError(); }
        public void engineSetKeyEntry(String alias, byte[] key, Certificate[] chain) { throw new AssertionError(); }
        public void engineSetCertificateEntry(String alias, Certificate certificate) { throw new AssertionError(); }
        public void engineDeleteEntry(String alias) { throw new AssertionError(); }
        public Enumeration<String> engineAliases() { return Collections.emptyEnumeration(); }
        public boolean engineContainsAlias(String alias) { return existing != null; }
        public int engineSize() { return existing == null ? 0 : 1; }
        public boolean engineIsKeyEntry(String alias) { return existing != null; }
        public boolean engineIsCertificateEntry(String alias) { return false; }
        public String engineGetCertificateAlias(Certificate certificate) { return null; }
    }
    public static final class Generator extends KeyGeneratorSpi {
        public Generator() { generationAttempts++; }
        protected void engineInit(SecureRandom random) { throw new AssertionError("Unexpected key generation"); }
        protected void engineInit(int size, SecureRandom random) { throw new AssertionError("Unexpected key generation"); }
        protected void engineInit(AlgorithmParameterSpec parameters, SecureRandom random) { throw new AssertionError("Unexpected key generation"); }
        protected SecretKey engineGenerateKey() { throw new AssertionError("Unexpected key generation"); }
    }
    public static void main(String[] args) throws Exception {
        Provider provider = new Provider("AndroidKeyStore", "1", "Read-only lookup boundary") {};
        provider.put("KeyStore.AndroidKeyStore", Store.class.getName());
        provider.put("KeyGenerator.AES", Generator.class.getName());
        Security.addProvider(provider);
        Class<?> type = Class.forName("uts.sdk.modules.HelloFaceVerify.ReferenceStore");
        // Bypass Android Context construction; provide only SharedPreferences/Editor boundaries.
        Class<?> unsafeType = Class.forName("sun.misc.Unsafe");
        Field singleton = unsafeType.getDeclaredField("theUnsafe"); singleton.setAccessible(true);
        Object store = unsafeType.getMethod("allocateInstance", Class.class).invoke(singleton.get(null), type);
        Field alias = type.getDeclaredField("alias"); alias.setAccessible(true);
        alias.set(store, "helloface.references.aes.v1");
        byte[] damaged = new byte[30]; damaged[0] = 1;
        String[] saved = { java.util.Base64.getEncoder().encodeToString(damaged) };
        Class<?> editorType = Class.forName("android.content.SharedPreferences$Editor");
        Object editor = Proxy.newProxyInstance(editorType.getClassLoader(), new Class<?>[]{editorType}, (proxy, method, values) -> {
            if (method.getName().equals("putString")) { saved[0] = (String) values[1]; return proxy; }
            if (method.getName().equals("commit")) return true;
            throw new AssertionError("Unexpected editor call: " + method.getName());
        });
        Class<?> preferencesType = Class.forName("android.content.SharedPreferences");
        Object preferences = Proxy.newProxyInstance(preferencesType.getClassLoader(), new Class<?>[]{preferencesType}, (proxy, method, values) -> {
            if (method.getName().equals("getString")) return saved[0];
            if (method.getName().equals("edit")) return editor;
            throw new AssertionError("Unexpected preferences call: " + method.getName());
        });
        Field stored = type.getDeclaredField("preferences"); stored.setAccessible(true); stored.set(store, preferences);
        Method read = type.getMethod("get", String.class);
        Method write = type.getMethod("save", String.class, String.class);
        try {
            read.invoke(store, "synthetic-user");
            throw new AssertionError("Missing read key must fail");
        } catch (InvocationTargetException error) {
            if (generationAttempts != 0) throw new AssertionError("Read attempted replacement-key generation", error.getCause());
            if (!(error.getCause() instanceof IllegalStateException)) throw error;
        }
        if (generationAttempts != 0) throw new AssertionError("Read must not generate a replacement key");
        System.out.println("PASS compiled ReferenceStore: missing read key fails without generation");
        existing = new SecretKeySpec(new byte[32], "AES"); // Synthetic test key, not a device key.
        String feature = "synthetic-reference";
        write.invoke(store, "synthetic-user", feature);
        if (!feature.equals(read.invoke(store, "synthetic-user")) || generationAttempts != 0) {
            throw new AssertionError("Read/write must reuse the existing key");
        }
        System.out.println("PASS compiled ReferenceStore: AES-GCM round trip reuses the existing key");
        try {
            read.invoke(store, "another-user");
            throw new AssertionError("Reference must remain bound to its account");
        } catch (InvocationTargetException error) {
            if (!(error.getCause() instanceof javax.crypto.AEADBadTagException)) throw error;
        }
        System.out.println("PASS compiled ReferenceStore: ciphertext remains bound to faceID");
    }
}
