package zip.tiago.tweeta;

import android.app.Application;

import com.google.android.material.color.DynamicColors;

/** Applies Material You wallpaper colors on Android 12 and newer. */
public final class TweetaApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        DynamicColors.applyToActivitiesIfAvailable(this);
    }
}
