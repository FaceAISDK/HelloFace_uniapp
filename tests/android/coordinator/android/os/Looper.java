package android.os;

import java.util.ArrayDeque;

/** Deterministic main-loop boundary; no SDK or camera behavior is simulated. */
public final class Looper {
    private static final Looper MAIN = new Looper();
    private final ArrayDeque<Runnable> tasks = new ArrayDeque<>();
    public static Looper getMainLooper() { return MAIN; }
    void post(Runnable task) { tasks.add(task); }
    public static void idle() { while (!MAIN.tasks.isEmpty()) MAIN.tasks.remove().run(); }
}
