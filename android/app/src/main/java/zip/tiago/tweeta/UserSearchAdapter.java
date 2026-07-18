package zip.tiago.tweeta;

import android.content.Context;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.google.android.material.card.MaterialCardView;
import com.google.android.material.imageview.ShapeableImageView;
import com.google.android.material.shape.ShapeAppearanceModel;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/** Recyclable, null-safe people results instead of exposing raw server objects. */
final class UserSearchAdapter extends BaseAdapter {
    private final Context context;
    private final SessionStore session;
    private final List<JSONObject> users = new ArrayList<>();

    UserSearchAdapter(Context context, JSONArray array) {
        this.context = context;
        this.session = new SessionStore(context);
        for (int index = 0; index < array.length(); index++) {
            JSONObject user = array.optJSONObject(index);
            if (user != null) users.add(user);
        }
    }

    String username(int position) {
        return clean(users.get(position), "username");
    }

    @Override public int getCount() { return users.size(); }
    @Override public JSONObject getItem(int position) { return users.get(position); }
    @Override public long getItemId(int position) { return username(position).hashCode(); }
    @Override public boolean hasStableIds() { return true; }

    @Override public View getView(int position, View recycled, ViewGroup parent) {
        Holder holder;
        if (recycled != null && recycled.getTag() instanceof Holder) {
            holder = (Holder) recycled.getTag();
        } else {
            holder = buildHolder();
            recycled = holder.card;
            recycled.setTag(holder);
        }
        bind(holder, getItem(position));
        return recycled;
    }

    private Holder buildHolder() {
        Holder holder = new Holder();
        holder.card = new MaterialCardView(context);
        holder.card.setCardBackgroundColor(Ui.surface(context));
        holder.card.setCardElevation(0);
        holder.card.setStrokeColor(Ui.outlineVariant(context));
        holder.card.setStrokeWidth(Ui.dp(context, 1));
        holder.card.setRadius(Ui.dp(context, 22));

        LinearLayout row = new LinearLayout(context);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(Ui.dp(context, 16), Ui.dp(context, 14),
                Ui.dp(context, 16), Ui.dp(context, 14));

        holder.avatar = new ShapeableImageView(context);
        holder.avatar.setScaleType(ImageView.ScaleType.CENTER_CROP);
        holder.avatar.setShapeAppearanceModel(ShapeAppearanceModel.builder()
                .setAllCornerSizes(Ui.dp(context, 26)).build());
        holder.avatar.setBackgroundColor(Ui.surfaceContainer(context));
        holder.avatar.setContentDescription("Profile photo");
        row.addView(holder.avatar, new LinearLayout.LayoutParams(
                Ui.dp(context, 52), Ui.dp(context, 52)));

        LinearLayout details = new LinearLayout(context);
        details.setOrientation(LinearLayout.VERTICAL);
        details.setPadding(Ui.dp(context, 14), 0, 0, 0);
        holder.name = Ui.label(context, "", 16, Ui.INK);
        holder.name.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        holder.handle = Ui.label(context, "", 13, Ui.MUTED);
        holder.bio = Ui.label(context, "", 14, Ui.INK);
        holder.bio.setMaxLines(2);
        holder.meta = Ui.label(context, "", 12, Ui.MUTED);
        holder.bio.setPadding(0, Ui.dp(context, 7), 0, Ui.dp(context, 5));
        details.addView(holder.name, new LinearLayout.LayoutParams(-1, -2));
        details.addView(holder.handle, new LinearLayout.LayoutParams(-1, -2));
        details.addView(holder.bio, new LinearLayout.LayoutParams(-1, -2));
        details.addView(holder.meta, new LinearLayout.LayoutParams(-1, -2));
        row.addView(details, new LinearLayout.LayoutParams(0, -2, 1));
        holder.card.addView(row);
        return holder;
    }

    private void bind(Holder holder, JSONObject user) {
        String username = clean(user, "username");
        String name = clean(user, "name");
        String bio = clean(user, "bio");
        int followers = user.optInt("follower_count", 0);
        boolean verified = user.optBoolean("verified", false) || user.optInt("verified", 0) == 1;
        boolean gold = user.optBoolean("gold", false) || user.optInt("gold", 0) == 1;

        holder.name.setText(name.isEmpty() ? username : name);
        holder.handle.setText(context.getString(R.string.account_handle, username));
        holder.bio.setText(bio);
        holder.bio.setVisibility(bio.isEmpty() ? View.GONE : View.VISIBLE);
        String followerText = context.getResources().getQuantityString(
                R.plurals.followers_count, followers, followers);
        String badge = verified ? "Verified" : gold ? "Gold" : "";
        holder.meta.setText(badge.isEmpty() ? followerText
                : context.getString(R.string.account_badge_meta, badge, followerText));
        holder.avatar.setImageResource(R.drawable.ic_account);
        holder.avatar.setTag(null);
        String avatar = clean(user, "avatar");
        if (!avatar.isEmpty()) ImageLoader.load(holder.avatar, avatar, session);
        holder.card.setContentDescription((name.isEmpty() ? username : name)
                + ", @" + username + ", " + followerText);
    }

    private static String clean(JSONObject object, String key) {
        if (object.isNull(key)) return "";
        String value = object.optString(key, "");
        return "null".equalsIgnoreCase(value.trim()) ? "" : value.trim();
    }

    private static final class Holder {
        MaterialCardView card;
        ShapeableImageView avatar;
        TextView name;
        TextView handle;
        TextView bio;
        TextView meta;
    }
}
