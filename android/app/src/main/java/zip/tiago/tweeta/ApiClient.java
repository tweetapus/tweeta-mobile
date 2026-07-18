package zip.tiago.tweeta;

import android.content.ContentResolver;
import android.content.Context;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.UUID;

/** Small dependency-free Tweetapus HTTP client. All callbacks run on the UI thread. */
final class ApiClient {
    interface Callback {
        void complete(JSONObject body, ApiException error);
    }

    static final class ApiException extends Exception {
        final int status;
        ApiException(int status, String message) {
            super(message);
            this.status = status;
        }
    }

    private final SessionStore session;
    private final ContentResolver resolver;
    private final ExecutorService executor = Executors.newFixedThreadPool(4);
    private final Handler main = new Handler(Looper.getMainLooper());

    ApiClient(Context context, SessionStore session) {
        this.session = session;
        this.resolver = context.getContentResolver();
    }

    void get(String path, Callback callback) { request("GET", path, null, callback); }
    void post(String path, JSONObject body, Callback callback) { request("POST", path, body, callback); }
    void put(String path, JSONObject body, Callback callback) { request("PUT", path, body, callback); }
    void patch(String path, JSONObject body, Callback callback) { request("PATCH", path, body, callback); }
    void delete(String path, JSONObject body, Callback callback) { request("DELETE", path, body, callback); }

    void upload(Uri uri, Callback callback) {
        executor.execute(() -> {
            JSONObject result = null;
            ApiException failure = null;
            HttpURLConnection connection = null;
            String boundary = "Tweeta-" + UUID.randomUUID();
            try {
                connection = (HttpURLConnection)new URL(session.apiBase() + "/upload/").openConnection();
                connection.setRequestMethod("POST");
                connection.setConnectTimeout(10_000);
                connection.setReadTimeout(60_000);
                connection.setDoOutput(true);
                connection.setChunkedStreamingMode(64 * 1024);
                connection.setRequestProperty("Authorization", "Bearer " + session.token());
                connection.setRequestProperty("X-Tweetapus-Client", "Tweeta Android; 1.0.0");
                connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=" + boundary);
                String mime = resolver.getType(uri);
                if (mime == null) mime = "application/octet-stream";
                try (OutputStream output = connection.getOutputStream();
                     InputStream input = resolver.openInputStream(uri)) {
                    String head = "--" + boundary + "\r\n"
                            + "Content-Disposition: form-data; name=\"file\"; filename=\"mobile-upload\"\r\n"
                            + "Content-Type: " + mime + "\r\n\r\n";
                    output.write(head.getBytes(StandardCharsets.UTF_8));
                    if (input == null) throw new IOException("Selected document is unavailable");
                    byte[] buffer = new byte[64 * 1024];
                    int count;
                    while ((count = input.read(buffer)) >= 0) output.write(buffer, 0, count);
                    output.write(("\r\n--" + boundary + "--\r\n").getBytes(StandardCharsets.UTF_8));
                }
                int status = connection.getResponseCode();
                String text = read(status >= 400 ? connection.getErrorStream() : connection.getInputStream());
                result = text.trim().isEmpty() ? new JSONObject() : new JSONObject(text);
                if (status >= 400 || result.has("error")) {
                    failure = new ApiException(status, result.optString("error", "Upload failed"));
                    result = null;
                }
            } catch (Exception exception) {
                failure = new ApiException(-1,
                        exception.getMessage() == null ? "Upload failed" : exception.getMessage());
            } finally {
                if (connection != null) connection.disconnect();
            }
            JSONObject delivered = result;
            ApiException deliveredError = failure;
            main.post(() -> callback.complete(delivered, deliveredError));
        });
    }

    void shutdown() { executor.shutdownNow(); }

    private void request(String method, String path, JSONObject payload, Callback callback) {
        executor.execute(() -> {
            JSONObject result = null;
            ApiException failure = null;
            HttpURLConnection connection = null;
            try {
                String target = path.startsWith("http") ? path : session.apiBase() + normalize(path);
                connection = (HttpURLConnection) new URL(target).openConnection();
                connection.setRequestMethod(method);
                connection.setConnectTimeout(10_000);
                connection.setReadTimeout(30_000);
                connection.setInstanceFollowRedirects(true);
                connection.setRequestProperty("Accept", "application/json");
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                connection.setRequestProperty("User-Agent", "TweetaAndroid/1.0.0");
                connection.setRequestProperty("X-Tweetapus-Client", "Tweeta Android; 1.0.0");
                if (session.token() != null) {
                    connection.setRequestProperty("Authorization", "Bearer " + session.token());
                }
                if (payload != null) {
                    connection.setDoOutput(true);
                    byte[] bytes = payload.toString().getBytes(StandardCharsets.UTF_8);
                    connection.setFixedLengthStreamingMode(bytes.length);
                    try (OutputStream output = connection.getOutputStream()) {
                        output.write(bytes);
                    }
                }
                int status = connection.getResponseCode();
                InputStream stream = status >= 400 ? connection.getErrorStream() : connection.getInputStream();
                String text = read(stream);
                result = text.trim().isEmpty() ? new JSONObject() : new JSONObject(text);
                if (status >= 400 || result.has("error")) {
                    String message = result.optString("error", "Request failed (HTTP " + status + ")");
                    failure = new ApiException(status, message);
                    result = null;
                }
            } catch (Exception exception) {
                failure = new ApiException(-1,
                        exception.getMessage() == null ? "Network request failed" : exception.getMessage());
            } finally {
                if (connection != null) connection.disconnect();
            }
            JSONObject deliveredResult = result;
            ApiException deliveredFailure = failure;
            main.post(() -> callback.complete(deliveredResult, deliveredFailure));
        });
    }

    private static String normalize(String path) {
        return path.startsWith("/") ? path : "/" + path;
    }

    private static String read(InputStream input) throws IOException {
        if (input == null) return "";
        StringBuilder text = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(input, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) text.append(line);
        }
        return text.toString();
    }
}
