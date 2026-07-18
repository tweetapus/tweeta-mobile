package zip.tiago.tweeta;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Native-screen route catalog mirroring the C client's feature areas. Keeping
 * this centralized makes omissions visible when the server or C client grows.
 */
final class FeatureCatalog {
    static final class Feature {
        final String section;
        final String title;
        final String description;
        final String path;
        final boolean requiresAuth;
        final boolean adminOnly;

        Feature(String section, String title, String description, String path,
                boolean requiresAuth, boolean adminOnly) {
            this.section = section;
            this.title = title;
            this.description = description;
            this.path = path;
            this.requiresAuth = requiresAuth;
            this.adminOnly = adminOnly;
        }
    }

    private static final List<Feature> FEATURES;

    static {
        List<Feature> items = new ArrayList<>();
        add(items, "Connect", "Messages", "Direct-message conversations", "/dm/conversations", true);
        add(items, "Connect", "Bookmarks", "Saved posts", "/bookmarks", true);
        add(items, "Connect", "Lists", "Owned and followed lists", "/lists", true);
        add(items, "Discover", "Explore", "Trends and discovery", "/trends", false);
        add(items, "Discover", "Articles", "Long-form posts", "/articles", false);
        add(items, "Discover", "Communities", "Joined and public communities", "/communities", true);
        add(items, "Discover", "Best of the week", "Popular posts this week", "/explore/best-of-week", false);
        add(items, "Discover", "Trending users", "People gaining attention", "/explore/trending-users", false);
        add(items, "Discover", "Most bookmarked", "Frequently saved posts", "/explore/most-bookmarked", false);
        add(items, "Discover", "Most discussed", "Active conversations", "/explore/most-discussed", false);
        add(items, "Discover", "Longest threads", "In-depth discussions", "/explore/longest-threads", false);
        add(items, "Discover", "Media", "Posts with media", "/explore/with-media", false);
        add(items, "Discover", "Polls", "Active public polls", "/explore/with-polls", false);
        add(items, "Account", "Follow requests", "Approve private-account requests", "/profile/follow-requests", true);
        add(items, "Account", "Affiliate requests", "Manage profile affiliations", "/profile/affiliate-requests", true);
        add(items, "Account", "Muted words", "Words hidden from your feeds", "/muted/words", true);
        add(items, "Account", "Muted conversations", "Conversations you muted", "/muted/conversations", true);
        add(items, "Account", "For You interests", "Tune recommendations", "/timeline/for-you/interests", true);
        add(items, "Account", "Scheduled posts", "Review and edit scheduled posts", "/scheduled/", true);
        add(items, "Account", "Delegates", "Accounts and invitations", "/delegates/summary", true);
        add(items, "Account", "Shop", "Products and purchases", "/mpi/shop/user/%USERNAME%", true);
        add(items, "Account", "Passkeys", "Registered authentication devices", "/auth/passkeys", true);
        add(items, "Account", "Push notifications", "Push subscription status", "/push/status", true);
        add(items, "Account", "Moderation history", "Actions affecting your account", "/auth/moderation-history", true);
        add(items, "Account", "Blocking causes", "Understand account blocks", "/blocking/causes", true);
        admin(items, "Overview", "/admin/stats");
        admin(items, "Users", "/admin/users");
        admin(items, "Posts", "/admin/posts");
        admin(items, "Suspensions", "/admin/suspensions");
        admin(items, "Reports", "/admin/reports");
        admin(items, "Moderation logs", "/admin/moderation-logs");
        admin(items, "Blocks", "/admin/blocks");
        admin(items, "Emoji", "/admin/emojis");
        admin(items, "Badges", "/admin/badges");
        admin(items, "DM review", "/admin/dms");
        admin(items, "Shop products", "/admin/shop/products");
        admin(items, "Shop purchases", "/admin/shop/purchases");
        admin(items, "Communities", "/admin/communities");
        FEATURES = Collections.unmodifiableList(items);
    }

    static List<Feature> available(SessionStore session) {
        List<Feature> visible = new ArrayList<>();
        for (Feature feature : FEATURES) {
            if (!feature.adminOnly || session.isAdmin()) visible.add(feature);
        }
        return visible;
    }

    private static void add(List<Feature> out, String section, String title,
                            String description, String path, boolean auth) {
        out.add(new Feature(section, title, description, path, auth, false));
    }

    private static void admin(List<Feature> out, String title, String path) {
        out.add(new Feature("Administration", title, "Administration: " + title,
                path, true, true));
    }

    private FeatureCatalog() {}
}
