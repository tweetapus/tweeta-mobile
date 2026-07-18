package zip.tiago.tweeta;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

final class Tweet {
    final String id;
    final String authorName;
    final String authorUsername;
    final String avatar;
    final String content;
    final String createdAt;
    final String mediaUrl;
    final String mediaType;
    final int replies;
    final int likes;
    final int retweets;
    boolean liked;
    boolean retweeted;
    boolean bookmarked;

    private Tweet(JSONObject object) {
        JSONObject author = object.optJSONObject("author");
        id = object.optString("id");
        authorName = author == null ? object.optString("name", "Unknown")
                : author.optString("name", "Unknown");
        authorUsername = author == null ? object.optString("username", "unknown")
                : author.optString("username", "unknown");
        avatar = author == null ? object.optString("avatar", "") : author.optString("avatar", "");
        content = object.optString("content", "");
        createdAt = object.optString("created_at", "");
        JSONArray attachments = object.optJSONArray("attachments");
        JSONObject first = attachments == null ? null : attachments.optJSONObject(0);
        mediaUrl = first == null ? "" : first.optString("file_url", first.optString("url", ""));
        mediaType = first == null ? "" : first.optString("file_type", first.optString("type", ""));
        replies = object.optInt("reply_count", object.optInt("replies", 0));
        likes = object.optInt("like_count", object.optInt("likes", 0));
        retweets = object.optInt("retweet_count", object.optInt("retweets", 0));
        JSONObject interaction = object.optJSONObject("interaction");
        liked = bool(object, "liked") || bool(interaction, "liked");
        retweeted = bool(object, "retweeted") || bool(interaction, "retweeted");
        bookmarked = bool(object, "bookmarked") || bool(interaction, "bookmarked");
    }

    static List<Tweet> list(JSONObject response) {
        String[] keys = {"posts", "timeline", "tweets", "bookmarks", "articles", "highlights"};
        JSONArray array = null;
        for (String key : keys) {
            array = response.optJSONArray(key);
            if (array != null) break;
        }
        List<Tweet> result = new ArrayList<>();
        if (array == null) return result;
        for (int i = 0; i < array.length(); i++) {
            JSONObject item = array.optJSONObject(i);
            if (item != null) result.add(new Tweet(item));
        }
        return result;
    }

    private static boolean bool(JSONObject object, String key) {
        return object != null && object.optBoolean(key, false);
    }
}
