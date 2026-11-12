package android.content;

/** Cancel/BUSY paths do not access application context or launch activities. */
public class Context {
    public Context getApplicationContext() { throw new AssertionError("Unexpected storage access"); }
    public void startActivity(Intent intent) { throw new AssertionError("Unexpected camera launch"); }
}
