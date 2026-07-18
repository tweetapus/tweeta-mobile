package zip.tiago.tweeta;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.widget.TextView;

import com.google.android.material.color.MaterialColors;
import com.google.android.material.textview.MaterialTextView;

final class Ui {
    static final int BLUE = Color.rgb(20, 103, 216);
    static final int INK = Color.rgb(28, 31, 36);
    static final int MUTED = Color.rgb(97, 105, 117);
    static final int SURFACE = Color.rgb(255, 253, 249);
    static final int LINE = Color.rgb(224, 226, 230);

    static int dp(Context context, int value) {
        return Math.round(value * context.getResources().getDisplayMetrics().density);
    }

    static TextView label(Context context, String text, float sp, int color) {
        TextView view = new MaterialTextView(context);
        view.setText(text);
        view.setTextSize(sp);
        view.setTextColor(resolveLegacyColor(context, color));
        view.setGravity(Gravity.CENTER_VERTICAL);
        return view;
    }

    static void bold(TextView view) { view.setTypeface(Typeface.DEFAULT, Typeface.BOLD); }

    static GradientDrawable rounded(int color, int radiusDp, Context context) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(resolveLegacyColor(context, color));
        drawable.setCornerRadius(dp(context, radiusDp));
        return drawable;
    }

    static int color(Context context, int attribute, int fallback) {
        return MaterialColors.getColor(context, attribute, fallback);
    }

    static int primary(Context context) {
        return color(context, androidx.appcompat.R.attr.colorPrimary, BLUE);
    }

    static int onPrimary(Context context) {
        return color(context, com.google.android.material.R.attr.colorOnPrimary, Color.WHITE);
    }

    static int surface(Context context) {
        return color(context, com.google.android.material.R.attr.colorSurface, SURFACE);
    }

    static int surfaceContainer(Context context) {
        return color(context, com.google.android.material.R.attr.colorSurfaceContainer,
                Color.rgb(244, 242, 247));
    }

    static int onSurface(Context context) {
        return color(context, com.google.android.material.R.attr.colorOnSurface, INK);
    }

    static int onSurfaceVariant(Context context) {
        return color(context, com.google.android.material.R.attr.colorOnSurfaceVariant, MUTED);
    }

    static int outlineVariant(Context context) {
        return color(context, com.google.android.material.R.attr.colorOutlineVariant, LINE);
    }

    static int resolveLegacyColor(Context context, int color) {
        if (color == BLUE) return primary(context);
        if (color == INK) return onSurface(context);
        if (color == MUTED) return onSurfaceVariant(context);
        if (color == SURFACE) return surface(context);
        if (color == LINE) return outlineVariant(context);
        return color;
    }

    static int attr(Context context, int attribute) {
        TypedValue value = new TypedValue();
        context.getTheme().resolveAttribute(attribute, value, true);
        return value.resourceId;
    }

    static void touchTarget(View view) {
        view.setMinimumHeight(dp(view.getContext(), 48));
        view.setMinimumWidth(dp(view.getContext(), 48));
    }

    private Ui() {}
}
