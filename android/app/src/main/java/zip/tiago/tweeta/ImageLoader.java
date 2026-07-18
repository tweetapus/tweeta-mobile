package zip.tiago.tweeta;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Handler;
import android.os.Looper;
import android.util.LruCache;
import android.widget.ImageView;

import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

final class ImageLoader {
    private static final LruCache<String, Bitmap> CACHE = new LruCache<>(24);
    private static final ExecutorService WORK = Executors.newFixedThreadPool(3);
    private static final Handler MAIN = new Handler(Looper.getMainLooper());

    static void load(ImageView view, String rawUrl, SessionStore session) {
        if (rawUrl == null || rawUrl.trim().isEmpty()) return;
        String url = absolute(rawUrl, session.apiBase());
        view.setTag(url);
        Bitmap cached = CACHE.get(url);
        if (cached != null) { view.setImageBitmap(cached); return; }
        WORK.execute(() -> {
            HttpURLConnection connection = null;
            try {
                connection = (HttpURLConnection)new URL(url).openConnection();
                connection.setConnectTimeout(8_000);
                connection.setReadTimeout(15_000);
                try (InputStream input = connection.getInputStream()) {
                    Bitmap bitmap = BitmapFactory.decodeStream(input);
                    if (bitmap != null) {
                        CACHE.put(url, bitmap);
                        MAIN.post(() -> {
                            if (url.equals(view.getTag())) view.setImageBitmap(bitmap);
                        });
                    }
                }
            } catch (Exception ignored) {
                // Media failure must not hide the post itself.
            } finally {
                if (connection != null) connection.disconnect();
            }
        });
    }

    private static String absolute(String value, String apiBase) {
        if (value.startsWith("https://") || value.startsWith("http://")) return value;
        String origin = apiBase.endsWith("/api") ? apiBase.substring(0, apiBase.length() - 4) : apiBase;
        return origin + (value.startsWith("/") ? value : "/" + value);
    }

    private ImageLoader() {}
}
