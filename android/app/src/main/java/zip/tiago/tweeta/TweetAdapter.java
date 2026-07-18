package zip.tiago.tweeta;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Typeface;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.google.android.material.button.MaterialButton;
import com.google.android.material.card.MaterialCardView;
import com.google.android.material.imageview.ShapeableImageView;
import com.google.android.material.shape.ShapeAppearanceModel;

import java.util.ArrayList;
import java.util.List;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Locale;

/** Material 3 post cards with phone-sized actions and recyclable rows. */
final class TweetAdapter extends BaseAdapter {
    interface Listener {
        void profile(String username);
        void reply(Tweet tweet);
        void like(Tweet tweet, Runnable refresh);
        void retweet(Tweet tweet, Runnable refresh);
        void bookmark(Tweet tweet, Runnable refresh);
        void more(Tweet tweet);
    }

    private final Context context;
    private final Listener listener;
    private final SessionStore session;
    private final List<Tweet> tweets = new ArrayList<>();

    TweetAdapter(Context context, Listener listener) {
        this.context = context;
        this.listener = listener;
        this.session = new SessionStore(context);
    }

    void replace(List<Tweet> value) {
        tweets.clear();
        tweets.addAll(value);
        notifyDataSetChanged();
    }

    @Override public int getCount() { return tweets.size(); }
    @Override public Tweet getItem(int position) { return tweets.get(position); }
    @Override public long getItemId(int position) { return getItem(position).id.hashCode(); }
    @Override public boolean hasStableIds() { return true; }

    @Override
    public View getView(int position, View recycled, ViewGroup parent) {
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
        Holder h = new Holder();
        h.card = new MaterialCardView(context);
        h.card.setCardBackgroundColor(Ui.surface(context));
        h.card.setCardElevation(0);
        h.card.setStrokeColor(Ui.outlineVariant(context));
        h.card.setStrokeWidth(Ui.dp(context, 1));
        h.card.setRadius(Ui.dp(context, 24));
        h.card.setUseCompatPadding(false);

        LinearLayout body = new LinearLayout(context);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setPadding(Ui.dp(context, 14), Ui.dp(context, 12),
                Ui.dp(context, 14), Ui.dp(context, 8));

        LinearLayout authorRow = new LinearLayout(context);
        authorRow.setOrientation(LinearLayout.HORIZONTAL);
        authorRow.setGravity(Gravity.CENTER_VERTICAL);
        h.avatar = new ShapeableImageView(context);
        h.avatar.setScaleType(ImageView.ScaleType.CENTER_CROP);
        h.avatar.setContentDescription("Author profile photo");
        h.avatar.setShapeAppearanceModel(ShapeAppearanceModel.builder()
                .setAllCornerSizes(Ui.dp(context, 22)).build());
        h.avatar.setBackgroundColor(Ui.surfaceContainer(context));

        LinearLayout names = new LinearLayout(context);
        names.setOrientation(LinearLayout.VERTICAL);
        names.setPadding(Ui.dp(context, 12), 0, 0, 0);
        h.author = Ui.label(context, "", 15, Ui.INK);
        h.author.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        h.handle = Ui.label(context, "", 13, Ui.MUTED);
        h.author.setSingleLine(true);
        h.handle.setSingleLine(true);
        names.addView(h.author, new LinearLayout.LayoutParams(-1, Ui.dp(context, 24)));
        names.addView(h.handle, new LinearLayout.LayoutParams(-1, Ui.dp(context, 21)));
        authorRow.addView(h.avatar, new LinearLayout.LayoutParams(Ui.dp(context, 44), Ui.dp(context, 44)));
        authorRow.addView(names, new LinearLayout.LayoutParams(0, -2, 1));
        body.addView(authorRow, new LinearLayout.LayoutParams(-1, -2));

        h.content = Ui.label(context, "", 16, Ui.INK);
        h.content.setGravity(Gravity.START);
        h.content.setLineSpacing(0, 1.12f);
        h.content.setTextIsSelectable(true);
        h.content.setPadding(0, Ui.dp(context, 10), 0, Ui.dp(context, 6));
        body.addView(h.content, new LinearLayout.LayoutParams(-1, -2));

        h.media = new ShapeableImageView(context);
        h.media.setAdjustViewBounds(true);
        h.media.setScaleType(ImageView.ScaleType.CENTER_CROP);
        h.media.setContentDescription("Post image");
        h.media.setShapeAppearanceModel(ShapeAppearanceModel.builder()
                .setAllCornerSizes(Ui.dp(context, 18)).build());
        h.media.setBackgroundColor(Ui.surfaceContainer(context));
        body.addView(h.media, new LinearLayout.LayoutParams(-1, Ui.dp(context, 180)));

        h.attachment = Ui.label(context, "", 13, Ui.BLUE);
        h.attachment.setPadding(Ui.dp(context, 12), Ui.dp(context, 8),
                Ui.dp(context, 12), Ui.dp(context, 8));
        h.attachment.setBackground(Ui.rounded(Ui.surfaceContainer(context), 14, context));
        body.addView(h.attachment, new LinearLayout.LayoutParams(-1, -2));

        h.time = Ui.label(context, "", 12, Ui.MUTED);
        h.time.setPadding(0, Ui.dp(context, 8), 0, Ui.dp(context, 2));
        body.addView(h.time, new LinearLayout.LayoutParams(-1, -2));

        LinearLayout actions = new LinearLayout(context);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER_VERTICAL);
        h.reply = actionButton(R.drawable.ic_reply, "Reply");
        h.retweet = actionButton(R.drawable.ic_repeat, "Boost");
        h.like = actionButton(R.drawable.ic_favorite, "Like");
        h.bookmark = actionButton(R.drawable.ic_bookmark, "Save");
        h.more = actionButton(R.drawable.ic_more, "More post actions");
        for (MaterialButton button : new MaterialButton[]{h.reply, h.retweet, h.like, h.bookmark, h.more})
            actions.addView(button, new LinearLayout.LayoutParams(0, Ui.dp(context, 44), 1));
        body.addView(actions, new LinearLayout.LayoutParams(-1, -2));
        h.card.addView(body);
        h.card.setContentPadding(0, 0, 0, 0);
        ViewGroup.MarginLayoutParams cardParams = new ViewGroup.MarginLayoutParams(-1, -2);
        cardParams.setMargins(Ui.dp(context, 10), Ui.dp(context, 5),
                Ui.dp(context, 10), Ui.dp(context, 5));
        h.card.setLayoutParams(cardParams);
        return h;
    }

    private void bind(Holder h, Tweet tweet) {
        h.author.setText(tweet.authorName.trim().isEmpty() ? "Unknown" : tweet.authorName);
        h.handle.setText(context.getString(R.string.account_handle, tweet.authorUsername));
        h.content.setText(tweet.content);
        h.content.setVisibility(tweet.content.trim().isEmpty() ? View.GONE : View.VISIBLE);
        h.time.setText(formatTime(tweet.createdAt));
        h.time.setContentDescription(tweet.createdAt);
        h.time.setVisibility(tweet.createdAt.trim().isEmpty() ? View.GONE : View.VISIBLE);

        h.avatar.setImageResource(R.drawable.ic_account);
        h.avatar.setTag(null);
        if (!tweet.avatar.trim().isEmpty()) ImageLoader.load(h.avatar, tweet.avatar, session);

        boolean image = !tweet.mediaUrl.trim().isEmpty() && tweet.mediaType.startsWith("image");
        h.media.setVisibility(image ? View.VISIBLE : View.GONE);
        h.attachment.setVisibility(!tweet.mediaUrl.trim().isEmpty() && !image ? View.VISIBLE : View.GONE);
        if (image) {
            h.media.setImageDrawable(null);
            ImageLoader.load(h.media, tweet.mediaUrl, session);
        } else if (!tweet.mediaUrl.trim().isEmpty()) {
            h.attachment.setText(context.getString(R.string.media_attachment, tweet.mediaType));
        }

        bindCount(h.reply, tweet.replies);
        bindCount(h.retweet, tweet.retweets);
        bindCount(h.like, tweet.likes);
        h.bookmark.setText("");
        h.more.setText("");
        tintActive(h.retweet, tweet.retweeted);
        tintActive(h.like, tweet.liked);
        tintActive(h.bookmark, tweet.bookmarked);

        View.OnClickListener openAuthor = view -> listener.profile(tweet.authorUsername);
        h.avatar.setOnClickListener(openAuthor);
        h.author.setOnClickListener(openAuthor);
        h.handle.setOnClickListener(openAuthor);
        h.reply.setOnClickListener(view -> listener.reply(tweet));
        h.retweet.setOnClickListener(view -> listener.retweet(tweet, this::notifyDataSetChanged));
        h.like.setOnClickListener(view -> listener.like(tweet, this::notifyDataSetChanged));
        h.bookmark.setOnClickListener(view -> listener.bookmark(tweet, this::notifyDataSetChanged));
        h.more.setOnClickListener(view -> listener.more(tweet));
    }

    private MaterialButton actionButton(int icon, String description) {
        MaterialButton button = new MaterialButton(context, null,
                com.google.android.material.R.attr.materialIconButtonStyle);
        button.setIconResource(icon);
        button.setIconGravity(MaterialButton.ICON_GRAVITY_TEXT_START);
        button.setIconSize(Ui.dp(context, 20));
        button.setIconPadding(Ui.dp(context, 2));
        button.setMinWidth(0);
        button.setMinimumWidth(0);
        button.setInsetTop(0);
        button.setInsetBottom(0);
        button.setContentDescription(description);
        button.setTextSize(11);
        return button;
    }

    private void bindCount(MaterialButton button, int count) {
        button.setText(count > 0 ? String.valueOf(count) : "");
    }

    private void tintActive(MaterialButton button, boolean active) {
        int color = active ? Ui.primary(context) : Ui.onSurfaceVariant(context);
        button.setIconTint(ColorStateList.valueOf(color));
        button.setTextColor(color);
    }

    private static String formatTime(String raw) {
        if (raw == null || raw.trim().isEmpty()) return "";
        String value = raw.trim();
        Instant instant;
        try {
            instant = Instant.parse(value);
        } catch (DateTimeParseException first) {
            try {
                String normalized = value.replace(' ', 'T');
                instant = LocalDateTime.parse(normalized,
                        DateTimeFormatter.ISO_LOCAL_DATE_TIME).toInstant(ZoneOffset.UTC);
            } catch (DateTimeParseException second) {
                return value.replace('T', ' ').replace(".000Z", "").replace("Z", "");
            }
        }
        Duration age = Duration.between(instant, Instant.now());
        if (!age.isNegative()) {
            long minutes = age.toMinutes();
            if (minutes < 1) return "now";
            if (minutes < 60) return minutes + "m";
            long hours = age.toHours();
            if (hours < 24) return hours + "h";
            long days = age.toDays();
            if (days < 7) return days + "d";
        }
        ZonedDateTime local = instant.atZone(ZoneId.systemDefault());
        String pattern = local.getYear() == ZonedDateTime.now().getYear() ? "MMM d" : "MMM d, yyyy";
        return DateTimeFormatter.ofPattern(pattern, Locale.getDefault()).format(local);
    }

    private static final class Holder {
        MaterialCardView card;
        ShapeableImageView avatar;
        ShapeableImageView media;
        TextView author;
        TextView handle;
        TextView content;
        TextView time;
        TextView attachment;
        MaterialButton reply;
        MaterialButton retweet;
        MaterialButton like;
        MaterialButton bookmark;
        MaterialButton more;
    }
}
