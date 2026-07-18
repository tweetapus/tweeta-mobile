package zip.tiago.tweeta;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** App-private session and instance settings. Credentials are never persisted. */
final class SessionStore {
    private static final String PREFS = "tweeta_session";
    private static final String DEFAULT_API = "https://tweeta.tiago.zip/api";
    private static final String KEY_ALIAS = "tweeta.session.token";
    private final SharedPreferences preferences;

    SessionStore(Context context) {
        preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    String apiBase() {
        String value = preferences.getString("api_base", DEFAULT_API);
        return value == null || value.trim().isEmpty() ? DEFAULT_API : trimSlash(value);
    }

    void setApiBase(String value) {
        preferences.edit().putString("api_base", trimSlash(value.trim())).apply();
    }

    String token() {
        String encrypted = preferences.getString("token_ciphertext", null);
        String iv = preferences.getString("token_iv", null);
        if (encrypted == null || iv == null) return null;
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key(),
                    new GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)));
            return new String(cipher.doFinal(Base64.decode(encrypted, Base64.NO_WRAP)),
                    StandardCharsets.UTF_8);
        } catch (Exception ignored) {
            return null;
        }
    }
    String username() { return preferences.getString("username", null); }
    boolean isAdmin() { return preferences.getBoolean("is_admin", false); }
    boolean signedIn() { return token() != null; }

    void saveLogin(String token, String username, boolean admin) {
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key());
            String encrypted = Base64.encodeToString(
                    cipher.doFinal(token.getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP);
            String iv = Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP);
            preferences.edit()
                    .putString("token_ciphertext", encrypted)
                    .putString("token_iv", iv)
                    .putString("username", username)
                    .putBoolean("is_admin", admin)
                    .apply();
        } catch (Exception exception) {
            throw new IllegalStateException("Android Keystore could not protect the session", exception);
        }
    }

    void logout() {
        preferences.edit().remove("token_ciphertext").remove("token_iv")
                .remove("username").remove("is_admin").apply();
    }

    private static SecretKey key() throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        java.security.Key existing = store.getKey(KEY_ALIAS, null);
        if (existing instanceof SecretKey) return (SecretKey) existing;
        KeyGenerator generator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build());
        return generator.generateKey();
    }

    private static String trimSlash(String value) {
        while (value.endsWith("/")) value = value.substring(0, value.length() - 1);
        return value;
    }
}
