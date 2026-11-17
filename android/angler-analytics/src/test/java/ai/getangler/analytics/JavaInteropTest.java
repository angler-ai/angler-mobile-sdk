package ai.getangler.analytics;

import static org.junit.Assert.assertEquals;

import java.util.HashMap;
import java.util.Map;
import org.junit.Test;

/** Compiling this file is the main check: the public API must be callable from Java. */
public class JavaInteropTest {
    @Test
    public void publicApiIsCallableFromJava() {
        AnglerConfiguration config = new AnglerConfiguration("ws", "tok");
        assertEquals("data.getangler.ai", config.getDomain());
        assertEquals("native", config.getWrapper());
        config.setWrapper("native");
        AnglerConfiguration full = new AnglerConfiguration("ws", "tok", "dev-data.getangler.ai", "crm-1", false, 10, 15L, 500, true);
        assertEquals(10, full.getFlushAt());

        Map<String, Object> data = new HashMap<>();
        data.put("customData", null);
        Angler.track("x");
        Angler.track("x", data);
        Map<String, String> props = new HashMap<>();
        props.put("a", "1");
        Angler.track("x", data, props);
        Angler.track("x", data, props, "event-1");
        Angler.handleDeepLink("myapp://x");
        Angler.setUserId(null);
        Angler.setIdentifier("appsflyer_id", "af-1");
        Angler.setApplicationTrackingEnabled(true);
        Angler.setEnabled(true);
        Angler.flush();
        Angler.reset();

        // Typed events and data from Java.
        Angler.track(AnglerEvent.ProductViewed.INSTANCE);
        Angler.track(new AnglerEvent.Custom("level_up"), new AnglerData(null, new AnglerCartLine(null, new AnglerProductVariant("variant-1"), 1)));
    }

    @Test
    public void nullsFromJavaNeverThrow() {
        Angler.track((String) null);
        Angler.track((String) null, null, null, null);
        Angler.track((AnglerEvent) null);
        Angler.handleDeepLink((String) null);
        Angler.handleDeepLink((android.net.Uri) null);
        Angler.setIdentifier(null, "x");
        Angler.configure(null, null);
    }
}
