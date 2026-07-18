package zip.tiago.tweeta;

import android.app.DatePickerDialog;
import android.app.TimePickerDialog;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputType;
import android.text.util.Linkify;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.inputmethod.EditorInfo;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.google.android.material.bottomsheet.BottomSheetDialog;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.button.MaterialButtonToggleGroup;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.floatingactionbutton.ExtendedFloatingActionButton;
import com.google.android.material.progressindicator.CircularProgressIndicator;
import com.google.android.material.snackbar.Snackbar;
import com.google.android.material.textfield.TextInputEditText;
import com.google.android.material.textfield.TextInputLayout;
import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.color.MaterialColors;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Calendar;
import java.util.Locale;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.text.NumberFormat;

/** Native Java handset/tablet UI for Tweetapus. */
public final class MainActivity extends AppCompatActivity implements TweetAdapter.Listener {
    private static final int NAV_HOME = 100;
    private static final int NAV_SEARCH = 101;
    private static final int NAV_POST = 102;
    private static final int NAV_ALERTS = 103;
    private static final int NAV_MENU = 104;
    private SessionStore session;
    private ApiClient api;
    private FrameLayout content;
    private TextView title;
    private MaterialToolbar toolbar;
    private BottomNavigationView navigation;
    private MenuItem accountItem;
    private String activeTimeline = "public";
    private Runnable refreshAction;
    private String pendingPostText;
    private Tweet pendingReply;
    private ActivityResultLauncher<String[]> mediaPicker;
    private int searchGeneration;
    private boolean changingNavigation;
    private Runnable backAction;
    private String lastSearchQuery = "";
    private boolean lastSearchPeople;

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        session = new SessionStore(this);
        api = new ApiClient(this, session);
        mediaPicker = registerForActivityResult(new ActivityResultContracts.OpenDocument(),
                this::handlePickedMedia);
        configureWindow();
        setContentView(buildShell());
        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override public void handleOnBackPressed() {
                if (backAction != null) {
                    Runnable destination = backAction;
                    backAction = null;
                    destination.run();
                } else {
                    setEnabled(false);
                    getOnBackPressedDispatcher().onBackPressed();
                }
            }
        });
        showTimeline("public");
    }

    private void configureWindow() {
        Window window = getWindow();
        WindowCompat.setDecorFitsSystemWindows(window, false);
        WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window,
                window.getDecorView());
        boolean light = MaterialColors.isColorLight(Ui.surface(this));
        controller.setAppearanceLightStatusBars(light);
        controller.setAppearanceLightNavigationBars(light);
    }

    private View buildShell() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Ui.surface(this));
        ViewCompat.setOnApplyWindowInsetsListener(root, (view, insets) -> {
            androidx.core.graphics.Insets bars = insets.getInsets(WindowInsetsCompat.Type.systemBars());
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
            return insets;
        });

        toolbar = new MaterialToolbar(this);
        toolbar.setBackgroundColor(Ui.surface(this));
        toolbar.setTitleCentered(false);
        toolbar.setLogoDescription("Tweeta");
        toolbar.setNavigationOnClickListener(view -> getOnBackPressedDispatcher().onBackPressed());
        title = Ui.label(this, "Tweeta", 21, Ui.INK);
        Ui.bold(title);
        MaterialToolbar.LayoutParams titleParams = new MaterialToolbar.LayoutParams(-2, -1);
        titleParams.gravity = Gravity.START | Gravity.CENTER_VERTICAL;
        toolbar.addView(title, titleParams);
        Menu toolbarMenu = toolbar.getMenu();
        MenuItem refresh = toolbarMenu.add("Refresh");
        refresh.setIcon(R.drawable.ic_refresh);
        refresh.setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM);
        refresh.setOnMenuItemClickListener(item -> {
            if (refreshAction != null) refreshAction.run();
            return true;
        });
        accountItem = toolbarMenu.add(session.signedIn() ? "@" + session.username() : "Sign in");
        accountItem.setIcon(R.drawable.ic_account);
        accountItem.setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM);
        accountItem.setOnMenuItemClickListener(item -> { showAccount(); return true; });

        content = new FrameLayout(this);
        navigation = new BottomNavigationView(this);
        navigation.setBackgroundColor(Ui.surfaceContainer(this));
        navigation.setItemActiveIndicatorEnabled(true);
        navigation.setLabelVisibilityMode(com.google.android.material.navigation.NavigationBarView.LABEL_VISIBILITY_LABELED);
        navigation.getMenu().add(Menu.NONE, NAV_HOME, 0, "Home").setIcon(R.drawable.ic_home);
        navigation.getMenu().add(Menu.NONE, NAV_SEARCH, 1, "Search").setIcon(R.drawable.ic_search);
        navigation.getMenu().add(Menu.NONE, NAV_POST, 2, "Post").setIcon(R.drawable.ic_add);
        navigation.getMenu().add(Menu.NONE, NAV_ALERTS, 3, "Alerts").setIcon(R.drawable.ic_notifications);
        navigation.getMenu().add(Menu.NONE, NAV_MENU, 4, "Menu").setIcon(R.drawable.ic_menu);
        navigation.setSelectedItemId(NAV_HOME);
        navigation.setOnItemSelectedListener(item -> {
            if (changingNavigation) return true;
            if (item.getItemId() == NAV_HOME) showTimeline(activeTimeline);
            else if (item.getItemId() == NAV_SEARCH) showSearchScreen(null);
            else if (item.getItemId() == NAV_POST) { showComposerMenu(); return false; }
            else if (item.getItemId() == NAV_ALERTS)
                loadPath("Notifications", "/notifications", true, "notifications");
            else if (item.getItemId() == NAV_MENU) { showMenu(); return false; }
            return true;
        });
        navigation.setOnItemReselectedListener(item -> {
            if (item.getItemId() == NAV_HOME) chooseTimeline();
            else if (refreshAction != null) refreshAction.run();
        });

        toolbar.setMinimumHeight(Ui.dp(this, 64));
        root.addView(toolbar, new LinearLayout.LayoutParams(-1, -2));
        root.addView(content, new LinearLayout.LayoutParams(-1, 0, 1));
        root.addView(navigation, new LinearLayout.LayoutParams(-1, -2));
        return root;
    }

    private Button textButton(String text) {
        MaterialButton button = new MaterialButton(this, null,
                com.google.android.material.R.attr.materialButtonTonalStyle);
        button.setText(text);
        button.setTextSize(14);
        button.setAllCaps(false);
        Ui.touchTarget(button);
        return button;
    }

    private void chooseTimeline() {
        String[] feeds = session.signedIn()
                ? new String[]{"Public", "Following", "For You"}
                : new String[]{"Public"};
        new MaterialAlertDialogBuilder(this).setTitle("Timeline")
                .setItems(feeds, (dialog, which) -> {
                    if (which == 1) showTimeline("following");
                    else if (which == 2) showTimeline("for-you");
                    else showTimeline("public");
                }).show();
    }

    private void showTimeline(String kind) {
        activeTimeline = kind;
        String path;
        if ("following".equals(kind)) path = "/timeline/following";
        else if ("for-you".equals(kind)) path = "/timeline/";
        else path = "/public-tweets?limit=30";
        String heading = "public".equals(kind) ? "Home" : titleCase(kind);
        setScreenTitle(heading, true);
        selectNavigation(NAV_HOME);
        showLoading("Loading " + heading.toLowerCase(Locale.getDefault()) + "…");
        String requestPath = path;
        refreshAction = () -> showTimeline(activeTimeline);
        api.get(requestPath, (body, error) -> {
            if (error != null) { showError(error); return; }
            List<Tweet> tweets = Tweet.list(body);
            if (tweets.isEmpty()) showEmpty("No posts here yet", "Pull back later or try another timeline.");
            else replaceContent(tweetList(tweets));
        });
    }

    private void showSearchScreen(String initialQuery) {
        showSearchScreen(initialQuery, false);
    }

    private void showSearchScreen(String initialQuery, boolean initialPeople) {
        setScreenTitle("Search", false);
        lastSearchQuery = initialQuery == null ? "" : initialQuery;
        lastSearchPeople = initialPeople;
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(Ui.dp(this, 12), Ui.dp(this, 8), Ui.dp(this, 12), 0);
        page.setBackgroundColor(Ui.surface(this));

        TextInputLayout searchBox = new TextInputLayout(this, null,
                com.google.android.material.R.attr.textInputOutlinedStyle);
        TextInputEditText input = new TextInputEditText(searchBox.getContext());
        input.setSingleLine(true);
        input.setHint("Search people and posts");
        input.setImeOptions(EditorInfo.IME_ACTION_SEARCH);
        if (initialQuery != null) input.setText(initialQuery);
        searchBox.addView(input, new LinearLayout.LayoutParams(-1, -2));
        searchBox.setEndIconMode(TextInputLayout.END_ICON_CUSTOM);
        searchBox.setEndIconDrawable(R.drawable.ic_search);
        searchBox.setEndIconContentDescription("Search");

        MaterialButtonToggleGroup scopes = new MaterialButtonToggleGroup(this);
        scopes.setSingleSelection(true);
        scopes.setSelectionRequired(true);
        MaterialButton posts = new MaterialButton(this, null,
                com.google.android.material.R.attr.materialButtonTonalStyle);
        MaterialButton people = new MaterialButton(this, null,
                com.google.android.material.R.attr.materialButtonTonalStyle);
        posts.setId(View.generateViewId());
        people.setId(View.generateViewId());
        posts.setText(R.string.search_posts);
        people.setText(R.string.search_people);
        posts.setMinimumHeight(Ui.dp(this, 48));
        people.setMinimumHeight(Ui.dp(this, 48));
        scopes.addView(posts, new LinearLayout.LayoutParams(0, -2, 1));
        scopes.addView(people, new LinearLayout.LayoutParams(0, -2, 1));
        scopes.check(posts.getId());

        FrameLayout results = new FrameLayout(this);
        final View[] postResults = {stateView("Search public posts", "Try a phrase, topic, or username.", false)};
        final View[] peopleResults = {stateView("Find people", "Search by display name or @username.", false)};
        final boolean[] showingPeople = {false};
        results.addView(postResults[0], new FrameLayout.LayoutParams(-1, -1));

        Runnable render = () -> {
            results.removeAllViews();
            results.addView(showingPeople[0] ? peopleResults[0] : postResults[0],
                    new FrameLayout.LayoutParams(-1, -1));
        };
        scopes.addOnButtonCheckedListener((group, checkedId, isChecked) -> {
            if (!isChecked) return;
            showingPeople[0] = checkedId == people.getId();
            lastSearchPeople = showingPeople[0];
            render.run();
        });
        if (initialPeople) scopes.check(people.getId());

        Runnable submit = () -> {
            String query = input.getText() == null ? "" : input.getText().toString().trim();
            if (query.isEmpty()) {
                searchBox.setError("Enter something to search for");
                return;
            }
            searchBox.setError(null);
            lastSearchQuery = query;
            input.clearFocus();
            WindowCompat.getInsetsController(getWindow(), input)
                    .hide(WindowInsetsCompat.Type.ime());
            int generation = ++searchGeneration;
            String encoded = Uri.encode(query);
            postResults[0] = stateView("Searching posts…", "", true);
            peopleResults[0] = stateView("Searching people…", "", true);
            render.run();
            api.get("/search/posts?q=" + encoded, (body, error) -> {
                if (generation != searchGeneration) return;
                if (error != null) {
                    postResults[0] = stateView("Posts couldn’t be loaded", error.getMessage(), false);
                } else {
                    List<Tweet> tweets = Tweet.list(body);
                    postResults[0] = tweets.isEmpty()
                            ? stateView("No posts found", "Try a broader search.", false)
                            : tweetList(tweets);
                }
                if (!showingPeople[0]) render.run();
            });
            api.get("/search/users?q=" + encoded, (body, error) -> {
                if (generation != searchGeneration) return;
                if (error != null) {
                    peopleResults[0] = stateView("People couldn’t be loaded", error.getMessage(), false);
                } else {
                    JSONArray users = findArray(body, "users");
                    peopleResults[0] = users == null || users.length() == 0
                            ? stateView("No people found", "Try a name without the @ symbol.", false)
                            : peopleList(users);
                }
                if (showingPeople[0]) render.run();
            });
        };
        input.setOnEditorActionListener((view, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_SEARCH) { submit.run(); return true; }
            return false;
        });
        searchBox.setEndIconOnClickListener(view -> submit.run());
        refreshAction = submit;

        page.addView(searchBox, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout.LayoutParams scopeParams = new LinearLayout.LayoutParams(-1, -2);
        scopeParams.setMargins(0, Ui.dp(this, 10), 0, Ui.dp(this, 6));
        page.addView(scopes, scopeParams);
        page.addView(results, new LinearLayout.LayoutParams(-1, 0, 1));
        replaceContent(page);
        input.requestFocus();
        if (initialQuery != null && !initialQuery.trim().isEmpty()) submit.run();
    }

    private void compose(Tweet replyTo) {
        if (!requireLogin()) return;
        String prompt = replyTo == null ? "What’s happening?" : "Reply to @" + replyTo.authorUsername;
        EditText input = input(prompt);
        input.setMinLines(5);
        input.setGravity(Gravity.TOP);
        new MaterialAlertDialogBuilder(this)
                .setTitle(replyTo == null ? "New post" : "Reply")
                .setView(wrapField(input, prompt))
                .setNegativeButton("Cancel", null)
                .setNeutralButton("Add media", (dialog, which) -> {
                    pendingPostText = input.getText().toString().trim();
                    pendingReply = replyTo;
                    mediaPicker.launch(new String[]{"image/*", "video/*", "image/gif"});
                })
                .setPositiveButton("Post", (dialog, which) -> {
                    String value = input.getText().toString().trim();
                    if (value.isEmpty()) return;
                    sendPost(value, replyTo, null);
                }).show();
    }

    private void showComposerMenu() {
        if (!requireLogin()) return;
        String[] options = {"Post", "Poll", "Schedule post", "Write article"};
        new MaterialAlertDialogBuilder(this).setTitle("Create").setItems(options, (dialog, which) -> {
            if (which == 0) compose(null);
            else if (which == 1) composePoll();
            else if (which == 2) composeScheduled();
            else composeArticle();
        }).show();
    }

    private void composePoll() {
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        int inset = Ui.dp(this, 20);
        form.setPadding(inset, 0, inset, 0);
        EditText contentInput = input("Post text");
        EditText optionsInput = input("Poll options, one per line");
        optionsInput.setMinLines(4);
        form.addView(wrapField(contentInput, "Post text"));
        LinearLayout.LayoutParams optionParams = new LinearLayout.LayoutParams(-1, -2);
        optionParams.setMargins(0, Ui.dp(this, 10), 0, 0);
        form.addView(wrapField(optionsInput, "Poll options, one per line"), optionParams);
        new MaterialAlertDialogBuilder(this).setTitle("New poll").setView(form)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Post", (dialog, which) -> {
                    String[] lines = optionsInput.getText().toString().split("\\n");
                    JSONArray options = new JSONArray();
                    for (String line : lines) if (!line.trim().isEmpty()) options.put(line.trim());
                    if (options.length() < 2) { showError("A poll needs at least two options."); return; }
                    JSONObject poll = json("options", options);
                    put(poll, "duration", 1440);
                    JSONObject payload = json("content", contentInput.getText().toString().trim());
                    put(payload, "source", "Tweeta Android");
                    put(payload, "poll", poll);
                    api.post("/tweets/", payload, (body, error) -> {
                        if (error != null) showError(error); else showTimeline(activeTimeline);
                    });
                }).show();
    }

    private void composeScheduled() {
        EditText input = input("Post text");
        input.setMinLines(4);
        new MaterialAlertDialogBuilder(this).setTitle("Schedule post")
                .setView(wrapField(input, "Post text"))
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Choose time", (dialog, which) -> chooseScheduleTime(input.getText().toString()))
                .show();
    }

    private void chooseScheduleTime(String contentText) {
        Calendar calendar = Calendar.getInstance();
        new DatePickerDialog(this, (datePicker, year, month, day) -> {
            new TimePickerDialog(this, (timePicker, hour, minute) -> {
                Calendar selected = Calendar.getInstance();
                selected.set(year, month, day, hour, minute, 0);
                selected.set(Calendar.MILLISECOND, 0);
                String iso = Instant.ofEpochMilli(selected.getTimeInMillis()).toString();
                JSONObject payload = json("content", contentText.trim());
                put(payload, "scheduled_for", iso);
                api.post("/scheduled/", payload, (body, error) -> {
                    if (error != null) showError(error); else toast("Post scheduled");
                });
            }, calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), false).show();
        }, calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH),
                calendar.get(Calendar.DAY_OF_MONTH)).show();
    }

    private void composeArticle() {
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        int inset = Ui.dp(this, 20);
        form.setPadding(inset, 0, inset, 0);
        EditText articleTitle = input("Article title");
        EditText markdown = input("Article body in Markdown");
        markdown.setMinLines(8);
        markdown.setGravity(Gravity.TOP);
        form.addView(wrapField(articleTitle, "Article title"));
        LinearLayout.LayoutParams bodyParams = new LinearLayout.LayoutParams(-1, -2);
        bodyParams.setMargins(0, Ui.dp(this, 10), 0, 0);
        form.addView(wrapField(markdown, "Article body in Markdown"), bodyParams);
        new MaterialAlertDialogBuilder(this).setTitle("Write article").setView(form)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Publish", (dialog, which) -> {
                    JSONObject payload = json("title", articleTitle.getText().toString().trim());
                    put(payload, "markdown", markdown.getText().toString());
                    put(payload, "source", "tweeta-android");
                    api.post("/articles", payload, (body, error) -> {
                        if (error != null) showError(error); else loadPath("Articles", "/articles", false, null);
                    });
                }).show();
    }

    private void sendPost(String value, Tweet replyTo, JSONObject file) {
        JSONObject payload = new JSONObject();
        put(payload, "content", value);
        put(payload, "source", "Tweeta Android");
        if (replyTo != null) put(payload, "reply_to", replyTo.id);
        if (file != null) {
            JSONArray files = new JSONArray();
            files.put(file);
            put(payload, "files", files);
        }
        api.post("/tweets/", payload, (body, error) -> {
            if (error != null) showError(error);
            else { toast("Posted"); showTimeline(activeTimeline); }
        });
    }

    private void handlePickedMedia(Uri uri) {
        if (uri == null) return;
        showLoading("Uploading media…");
        String mime = getContentResolver().getType(uri);
        api.upload(uri, (body, error) -> {
            if (error != null) { showError(error); return; }
            String url = body.optString("file_url", body.optString("url", ""));
            JSONObject nested = body.optJSONObject("file");
            if (url.trim().isEmpty() && nested != null)
                url = nested.optString("file_url", nested.optString("url", ""));
            if (url.trim().isEmpty()) { showError("The upload response did not include a file URL."); return; }
            JSONObject file = json("url", url);
            put(file, "type", mime == null ? "application/octet-stream" : mime);
            put(file, "name", "mobile-upload");
            put(file, "hash", "");
            put(file, "size", 0);
            sendPost(pendingPostText == null ? "" : pendingPostText, pendingReply, file);
            pendingPostText = null;
            pendingReply = null;
        });
    }

    private void showMenu() {
        List<FeatureCatalog.Feature> features = FeatureCatalog.available(session);
        BottomSheetDialog sheet = new BottomSheetDialog(this);
        LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        list.setPadding(Ui.dp(this, 16), Ui.dp(this, 12),
                Ui.dp(this, 16), Ui.dp(this, 28));
        TextView heading = Ui.label(this, "More in Tweeta", 24, Ui.INK);
        Ui.bold(heading);
        heading.setPadding(Ui.dp(this, 8), 0, 0, Ui.dp(this, 8));
        list.addView(heading, new LinearLayout.LayoutParams(-1, Ui.dp(this, 52)));

        MaterialButton profile = menuButton(session.signedIn()
                ? "My profile\n@" + session.username()
                : "Sign in\nAccess your account", R.drawable.ic_account);
        profile.setOnClickListener(view -> { sheet.dismiss(); showAccount(); });
        list.addView(profile, menuRowParams());

        String section = "";
        for (FeatureCatalog.Feature feature : features) {
            if (!section.equals(feature.section)) {
                section = feature.section;
                TextView label = Ui.label(this, section, 13, Ui.MUTED);
                label.setAllCaps(true);
                label.setLetterSpacing(0.08f);
                label.setPadding(Ui.dp(this, 10), Ui.dp(this, 18), 0, Ui.dp(this, 6));
                list.addView(label, new LinearLayout.LayoutParams(-1, -2));
            }
            MaterialButton action = menuButton(feature.title + "\n" + feature.description,
                    iconForFeature(feature));
            action.setOnClickListener(view -> { sheet.dismiss(); openFeature(feature); });
            list.addView(action, menuRowParams());
        }
        TextView appSection = Ui.label(this, "APP", 13, Ui.MUTED);
        appSection.setLetterSpacing(0.08f);
        appSection.setPadding(Ui.dp(this, 10), Ui.dp(this, 18), 0, Ui.dp(this, 6));
        list.addView(appSection);
        MaterialButton settings = menuButton("Settings\nInstance, privacy and session",
                android.R.drawable.ic_menu_preferences);
        settings.setOnClickListener(view -> { sheet.dismiss(); showSettings(); });
        list.addView(settings, menuRowParams());

        ScrollView scroll = new ScrollView(this);
        scroll.addView(list);
        sheet.setContentView(scroll);
        sheet.setOnShowListener(dialog -> {
            View bottom = sheet.findViewById(com.google.android.material.R.id.design_bottom_sheet);
            if (bottom != null) bottom.getLayoutParams().height =
                    Math.min(getResources().getDisplayMetrics().heightPixels,
                            Ui.dp(this, 700));
        });
        sheet.show();
    }

    private void openFeature(FeatureCatalog.Feature feature) {
        if (feature.requiresAuth && !requireLogin()) return;
        String path = feature.path.replace("%USERNAME%",
                Uri.encode(session.username() == null ? "" : session.username()));
        loadPath(feature.title, path, feature.requiresAuth, null);
    }

    private void loadPath(String heading, String path, boolean auth, String preferredKey) {
        loadPath(heading, path, auth, preferredKey, () -> showTimeline(activeTimeline));
    }

    private void loadPath(String heading, String path, boolean auth, String preferredKey,
                          Runnable returnTo) {
        if (auth && !requireLogin()) return;
        setScreenTitle(heading, returnTo);
        showLoading("Loading " + heading.toLowerCase(Locale.getDefault()) + "…");
        refreshAction = () -> loadPath(heading, path, auth, preferredKey, returnTo);
        api.get(path, (body, error) -> {
            if (error != null) { showError(error); return; }
            if (looksLikeTweets(body)) {
                List<Tweet> tweets = Tweet.list(body);
                if (tweets.isEmpty()) showEmpty("Nothing here", "This section is currently empty.");
                else replaceContent(tweetList(tweets));
                return;
            }
            JSONArray array = findArray(body, preferredKey);
            if (array == null) {
                showObject(body);
            } else {
                if (array.length() == 0) showEmpty("Nothing here", "This section is currently empty.");
                else replaceContent(jsonList(heading, path, array));
            }
        });
    }

    private void openGenericItem(String heading, String sourcePath, JSONObject item) {
        String id = item.optString("id", "");
        if (sourcePath.startsWith("/dm/conversations") && !id.isEmpty()) {
            showConversation(id, item.optString("display_name", item.optString("title", "Messages")));
        } else if (sourcePath.equals("/lists") && !id.isEmpty()) {
            loadPath(item.optString("name", "List"), "/lists/" + Uri.encode(id), true, null);
        } else if (sourcePath.startsWith("/communities") && !id.isEmpty()) {
            loadPath(item.optString("name", "Community"), "/communities/" + Uri.encode(id), true, null);
        } else if (item.has("username")) {
            profile(item.optString("username"));
        } else {
            showObject(item);
        }
    }

    private void showConversation(String id, String heading) {
        if (!requireLogin()) return;
        setScreenTitle(heading, false);
        showLoading("Loading conversation…");
        refreshAction = () -> showConversation(id, heading);
        api.get("/dm/conversations/" + Uri.encode(id), (body, error) -> {
            if (error != null) { showError(error); return; }
            JSONArray messages = findArray(body, "messages");
            View messageContent;
            if (messages == null || messages.length() == 0) {
                messageContent = stateView("No messages yet", "Start the conversation below.", false);
            } else {
                ListView list = new ListView(this);
                list.setDivider(null);
                list.setClipToPadding(false);
                list.setPadding(0, 0, 0, Ui.dp(this, 88));
                list.setAdapter(new JsonAdapter(this, messages));
                messageContent = list;
            }
            FrameLayout screen = new FrameLayout(this);
            screen.addView(messageContent, new FrameLayout.LayoutParams(-1, -1));
            ExtendedFloatingActionButton send = new ExtendedFloatingActionButton(this);
            send.setText(R.string.message);
            send.setIconResource(R.drawable.ic_send);
            send.setContentDescription("Send a message");
            send.setOnClickListener(view -> messageDialog(id, heading));
            FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(-2,
                    Ui.dp(this, 56), Gravity.END | Gravity.BOTTOM);
            params.setMargins(Ui.dp(this, 16), Ui.dp(this, 16),
                    Ui.dp(this, 16), Ui.dp(this, 16));
            screen.addView(send, params);
            replaceContent(screen);
        });
    }

    private void messageDialog(String conversationId, String heading) {
        EditText input = input("Message");
        new MaterialAlertDialogBuilder(this).setTitle("Message " + heading)
                .setView(wrapField(input, "Message"))
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Send", (dialog, which) -> {
                    String message = input.getText().toString().trim();
                    if (message.isEmpty()) { toast("Write a message first"); return; }
                    JSONObject payload = new JSONObject();
                    put(payload, "content", message);
                    api.post("/dm/conversations/" + Uri.encode(conversationId) + "/messages",
                            payload, (body, error) -> {
                                if (error != null) showError(error);
                                else showConversation(conversationId, heading);
                            });
                }).show();
    }

    @Override public void profile(String username) {
        if (username == null || username.trim().isEmpty()) return;
        Runnable returnTo;
        if (navigation != null && navigation.getSelectedItemId() == NAV_SEARCH) {
            String query = lastSearchQuery;
            boolean people = lastSearchPeople;
            returnTo = () -> showSearchScreen(query, people);
        } else {
            returnTo = () -> showTimeline(activeTimeline);
        }
        profileScreen(username, returnTo);
    }

    private void profileScreen(String username, Runnable returnTo) {
        setScreenTitle("@" + username, returnTo);
        showLoading("Loading profile…");
        refreshAction = () -> profileScreen(username, returnTo);
        api.get("/profile/" + Uri.encode(username), (body, error) -> {
            if (error != null) { showError(error); return; }
            JSONObject resolved = body.optJSONObject("profile");
            if (resolved == null) resolved = body.optJSONObject("user");
            if (resolved == null) resolved = body;
            final JSONObject value = resolved;
            LinearLayout profile = new LinearLayout(this);
            profile.setOrientation(LinearLayout.VERTICAL);
            profile.setPadding(Ui.dp(this, 16), Ui.dp(this, 12),
                    Ui.dp(this, 16), Ui.dp(this, 28));
            com.google.android.material.card.MaterialCardView header =
                    new com.google.android.material.card.MaterialCardView(this);
            header.setCardBackgroundColor(Ui.surfaceContainer(this));
            header.setCardElevation(0);
            header.setRadius(Ui.dp(this, 28));
            LinearLayout headerBody = new LinearLayout(this);
            headerBody.setOrientation(LinearLayout.VERTICAL);
            headerBody.setGravity(Gravity.CENTER_HORIZONTAL);
            headerBody.setPadding(Ui.dp(this, 20), Ui.dp(this, 22),
                    Ui.dp(this, 20), Ui.dp(this, 18));
            com.google.android.material.imageview.ShapeableImageView avatar =
                    new com.google.android.material.imageview.ShapeableImageView(this);
            avatar.setScaleType(android.widget.ImageView.ScaleType.CENTER_CROP);
            avatar.setImageResource(R.drawable.ic_account);
            avatar.setShapeAppearanceModel(com.google.android.material.shape.ShapeAppearanceModel
                    .builder().setAllCornerSizes(Ui.dp(this, 44)).build());
            String avatarUrl = cleanValue(value, "avatar",
                    cleanValue(value, "avatar_url", ""));
            if (!avatarUrl.trim().isEmpty()) ImageLoader.load(avatar, avatarUrl, session);
            headerBody.addView(avatar, new LinearLayout.LayoutParams(Ui.dp(this, 88), Ui.dp(this, 88)));
            TextView displayName = Ui.label(this, cleanValue(value, "name", username), 24, Ui.INK);
            Ui.bold(displayName);
            displayName.setGravity(Gravity.CENTER);
            headerBody.addView(displayName, new LinearLayout.LayoutParams(-1, Ui.dp(this, 42)));
            TextView handle = Ui.label(this, "@" + username, 14, Ui.MUTED);
            handle.setGravity(Gravity.CENTER);
            headerBody.addView(handle, new LinearLayout.LayoutParams(-1, Ui.dp(this, 28)));
            String bio = cleanValue(value, "bio", "");
            if (!bio.isEmpty()) {
                TextView bioView = Ui.label(this, bio, 15, Ui.INK);
                bioView.setGravity(Gravity.CENTER);
                bioView.setTextAlignment(View.TEXT_ALIGNMENT_CENTER);
                bioView.setPadding(0, Ui.dp(this, 6), 0, Ui.dp(this, 10));
                headerBody.addView(bioView, new LinearLayout.LayoutParams(-1, -2));
            }
            NumberFormat numbers = NumberFormat.getIntegerInstance();
            String stats = numbers.format(value.optInt("follower_count", value.optInt("followers", 0)))
                    + " followers  ·  "
                    + numbers.format(value.optInt("following_count", value.optInt("following", 0)))
                    + " following";
            TextView statsView = Ui.label(this, stats, 14, Ui.MUTED);
            statsView.setGravity(Gravity.CENTER);
            headerBody.addView(statsView, new LinearLayout.LayoutParams(-1, Ui.dp(this, 36)));
            LinearLayout actions = new LinearLayout(this);
            actions.setGravity(Gravity.CENTER);
            Button posts = textButton("Posts");
            posts.setOnClickListener(view -> {
                String before = Uri.encode(Instant.now().plusSeconds(60).toString());
                loadPath("@" + username, "/profile/" + Uri.encode(username)
                        + "/posts?before=" + before + "&limit=20", false, "posts",
                        () -> profileScreen(username, returnTo));
            });
            Button replies = textButton("Replies");
            replies.setOnClickListener(view -> loadPath("Replies",
                    "/profile/" + Uri.encode(username) + "/replies", false, "replies",
                    () -> profileScreen(username, returnTo)));
            boolean following = value.optBoolean("is_following", value.optBoolean("following", false));
            Button follow = textButton(!session.signedIn() ? "Sign in" : following ? "Unfollow" : "Follow");
            follow.setOnClickListener(view -> {
                if (!requireLogin()) return;
                ApiClient.Callback complete = (result, failure) -> {
                    if (failure != null) showError(failure); else profileScreen(username, returnTo);
                };
                String followPath = "/profile/" + Uri.encode(username) + "/follow";
                if (following) api.delete(followPath, null, complete);
                else api.post(followPath, new JSONObject(), complete);
            });
            actions.addView(posts, new LinearLayout.LayoutParams(0, Ui.dp(this, 52), 1));
            actions.addView(replies, new LinearLayout.LayoutParams(0, Ui.dp(this, 52), 1));
            if (!username.equals(session.username()))
                actions.addView(follow, new LinearLayout.LayoutParams(0, Ui.dp(this, 52), 1));
            headerBody.addView(actions, new LinearLayout.LayoutParams(-1, -2));
            header.addView(headerBody);
            profile.addView(header, new LinearLayout.LayoutParams(-1, -2));
            String location = cleanValue(value, "location", "");
            String website = cleanValue(value, "website", cleanValue(value, "url", ""));
            String joined = cleanValue(value, "created_at", cleanValue(value, "joined_at", ""));
            List<String> accountLabels = new ArrayList<>();
            if (value.optBoolean("verified") || value.optInt("verified", 0) == 1)
                accountLabels.add("Verified");
            if (value.optBoolean("gold") || value.optInt("gold", 0) == 1)
                accountLabels.add("Gold");
            if (value.optBoolean("private") || value.optBoolean("is_private"))
                accountLabels.add("Private");
            if (!location.isEmpty() || !website.isEmpty() || !joined.isEmpty() || !accountLabels.isEmpty()) {
                TextView aboutHeading = Ui.label(this, "About", 18, Ui.INK);
                Ui.bold(aboutHeading);
                aboutHeading.setPadding(Ui.dp(this, 4), Ui.dp(this, 20), 0, Ui.dp(this, 8));
                profile.addView(aboutHeading, new LinearLayout.LayoutParams(-1, -2));
                if (!location.isEmpty()) addProfileDetail(profile, "Location", location);
                if (!website.isEmpty()) addProfileDetail(profile, "Website", website);
                if (!joined.isEmpty()) addProfileDetail(profile, "Joined", formatProfileDate(joined));
                if (!accountLabels.isEmpty())
                    addProfileDetail(profile, "Account", String.join(" · ", accountLabels));
            }
            ScrollView scroll = new ScrollView(this);
            scroll.addView(profile);
            replaceContent(scroll);
        });
    }

    @Override public void reply(Tweet tweet) { compose(tweet); }

    @Override public void like(Tweet tweet, Runnable refresh) {
        mutate("/tweets/" + Uri.encode(tweet.id) + "/like", new JSONObject(), () -> {
            tweet.liked = !tweet.liked; refresh.run();
        });
    }

    @Override public void retweet(Tweet tweet, Runnable refresh) {
        mutate("/tweets/" + Uri.encode(tweet.id) + "/retweet", new JSONObject(), () -> {
            tweet.retweeted = !tweet.retweeted; refresh.run();
        });
    }

    @Override public void bookmark(Tweet tweet, Runnable refresh) {
        String path = tweet.bookmarked ? "/bookmarks/remove" : "/bookmarks/add";
        mutate(path, json("postId", tweet.id), () -> {
            tweet.bookmarked = !tweet.bookmarked; refresh.run();
        });
    }

    @Override public void more(Tweet tweet) {
        String[] choices = session.username() != null && session.username().equals(tweet.authorUsername)
                ? new String[]{"Copy text", "View author", "Quote", "Edit", "Delete", "Report", "Translate"}
                : new String[]{"Copy text", "View author", "Quote", "Report", "Translate"};
        new MaterialAlertDialogBuilder(this).setTitle("Post actions").setItems(choices, (dialog, which) -> {
            String action = choices[which];
            if ("Copy text".equals(action)) {
                ClipboardManager clipboard = (ClipboardManager)getSystemService(Context.CLIPBOARD_SERVICE);
                clipboard.setPrimaryClip(ClipData.newPlainText("Post", tweet.content));
            } else if ("View author".equals(action)) profile(tweet.authorUsername);
            else if ("Quote".equals(action)) quotePost(tweet);
            else if ("Edit".equals(action)) editPost(tweet);
            else if ("Delete".equals(action)) confirmDelete(tweet);
            else if ("Report".equals(action)) reportPost(tweet);
            else translatePost(tweet);
        }).show();
    }

    private void quotePost(Tweet tweet) {
        if (!requireLogin()) return;
        EditText input = input("Add a comment");
        new MaterialAlertDialogBuilder(this).setTitle("Quote post")
                .setView(wrapField(input, "Add a comment"))
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Post", (dialog, which) -> {
                    JSONObject payload = json("content", input.getText().toString().trim());
                    put(payload, "quote_tweet_id", tweet.id);
                    put(payload, "source", "Tweeta Android");
                    api.post("/tweets/", payload, (body, error) -> {
                        if (error != null) showError(error); else showTimeline(activeTimeline);
                    });
                }).show();
    }

    private void editPost(Tweet tweet) {
        EditText input = input("Post text");
        input.setText(tweet.content);
        new MaterialAlertDialogBuilder(this).setTitle("Edit post")
                .setView(wrapField(input, "Post text"))
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Save", (d, w) -> api.put("/tweets/" + Uri.encode(tweet.id),
                        json("content", input.getText().toString()), (body, error) -> {
                            if (error != null) showError(error); else showTimeline(activeTimeline);
                        })).show();
    }

    private void confirmDelete(Tweet tweet) {
        new MaterialAlertDialogBuilder(this).setTitle("Delete post?")
                .setMessage("This cannot be undone.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Delete", (d, w) -> api.delete("/tweets/" + Uri.encode(tweet.id),
                        null, (body, error) -> {
                            if (error != null) showError(error); else showTimeline(activeTimeline);
                        })).show();
    }

    private void reportPost(Tweet tweet) {
        EditText reason = input("Reason and additional information");
        new MaterialAlertDialogBuilder(this).setTitle("Report post")
                .setView(wrapField(reason, "Reason and additional information"))
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Report", (d, w) -> {
                    JSONObject payload = json("reported_type", "tweet");
                    put(payload, "reported_id", tweet.id);
                    put(payload, "reason", "other");
                    put(payload, "additional_info", reason.getText().toString());
                    mutate("/reports/create", payload, () -> toast("Report sent"));
                }).show();
    }

    private void translatePost(Tweet tweet) {
        JSONObject payload = json("text", tweet.content);
        mutate("/translate/", payload, () -> toast("Translation requested"));
    }

    private void mutate(String path, JSONObject payload, Runnable success) {
        if (!requireLogin()) return;
        api.post(path, payload, (body, error) -> {
            if (error != null) showError(error); else success.run();
        });
    }

    private void showAccount() {
        if (!session.signedIn()) { loginDialog(); return; }
        String[] actions = {"My profile", "Account settings", "Switch account", "Sign out"};
        new MaterialAlertDialogBuilder(this).setTitle("@" + session.username())
                .setItems(actions, (dialog, which) -> {
                    if (which == 0) profile(session.username());
                    else if (which == 1) showSettings();
                    else if (which == 2) loginDialog();
                    else if (which == 3) {
                        session.logout(); updateAccount(); showTimeline("public");
                    }
                }).show();
    }

    private void loginDialog() {
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        int inset = Ui.dp(this, 22);
        form.setPadding(inset, 0, inset, 0);
        TextInputLayout usernameBox = outlinedField("Username", false);
        TextInputLayout passwordBox = outlinedField("Password", true);
        EditText username = usernameBox.getEditText();
        EditText password = passwordBox.getEditText();
        password.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        form.addView(usernameBox, new LinearLayout.LayoutParams(-1, -2));
        LinearLayout.LayoutParams passwordParams = new LinearLayout.LayoutParams(-1, -2);
        passwordParams.setMargins(0, Ui.dp(this, 10), 0, 0);
        form.addView(passwordBox, passwordParams);
        new MaterialAlertDialogBuilder(this).setTitle("Sign in to Tweeta").setView(form)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Sign in", (dialog, which) -> {
                    JSONObject payload = json("username", username.getText().toString().trim());
                    put(payload, "password", password.getText().toString());
                    api.post("/auth/basic-login", payload, (body, error) -> {
                        if (error != null) { showError(error); return; }
                        String token = body.optString("token", null);
                        JSONObject user = body.optJSONObject("user");
                        if (token == null) { showError("The server did not return a session token."); return; }
                        String name = user == null ? username.getText().toString().trim()
                                : user.optString("username", username.getText().toString().trim());
                        boolean admin = user != null && (user.optBoolean("admin") || user.optBoolean("superadmin"));
                        session.saveLogin(token, name, admin);
                        updateAccount(); showTimeline("following");
                    });
                }).show();
    }

    private void showSettings() {
        String[] actions = {"Change server instance", "Profile settings", "Privacy settings",
                "Notification settings", "Manage passkeys", "Sign out"};
        new MaterialAlertDialogBuilder(this).setTitle("Settings").setItems(actions, (dialog, which) -> {
            if (which == 0) instanceDialog();
            else if (which == 1 && requireLogin()) profile(session.username());
            else if (which == 2 && requireLogin()) loadPath("Privacy", "/profile/settings/private", true, null);
            else if (which == 3 && requireLogin()) loadPath("Notifications", "/push/status", true, null);
            else if (which == 4 && requireLogin()) loadPath("Passkeys", "/auth/passkeys", true, null);
            else if (which == 5 && session.signedIn()) { session.logout(); updateAccount(); }
        }).show();
    }

    private void instanceDialog() {
        EditText input = input("https://example.org/api");
        input.setSingleLine(true);
        input.setText(session.apiBase());
        new MaterialAlertDialogBuilder(this).setTitle("Tweetapus server")
                .setView(wrapField(input, "Server URL"))
                .setMessage("Only HTTPS servers are accepted.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Save", (dialog, which) -> {
                    String value = input.getText().toString().trim();
                    if (!value.startsWith("https://")) { showError("Use an HTTPS server URL."); return; }
                    session.logout();
                    session.setApiBase(value);
                    updateAccount(); showTimeline("public");
                }).show();
    }

    private boolean requireLogin() {
        if (session.signedIn()) return true;
        loginDialog();
        return false;
    }

    private void updateAccount() {
        String label = session.signedIn() ? "@" + session.username() : "Sign in";
        accountItem.setTitle(label);
        accountItem.setContentDescription(label);
    }

    private void setScreenTitle(String value, boolean isTimelineRoot) {
        setScreenTitle(value, isTimelineRoot ? null : () -> showTimeline(activeTimeline));
    }

    private void setScreenTitle(String value, Runnable returnTo) {
        title.setText(value);
        backAction = returnTo;
        toolbar.setLogo(returnTo == null
                ? ContextCompat.getDrawable(this, R.drawable.ic_tweeta_logo)
                : null);
        toolbar.setNavigationIcon(returnTo == null ? null :
                ContextCompat.getDrawable(this, R.drawable.ic_arrow_back));
    }

    private void selectNavigation(int itemId) {
        if (navigation == null || navigation.getSelectedItemId() == itemId) return;
        changingNavigation = true;
        navigation.setSelectedItemId(itemId);
        changingNavigation = false;
    }

    private void showLoading(String message) {
        replaceContent(stateView(message, "", true));
    }

    private void showEmpty(String heading, String detail) {
        replaceContent(stateView(heading, detail, false));
    }

    private void showError(ApiClient.ApiException error) { showError(error.getMessage()); }
    private void showError(String message) {
        new MaterialAlertDialogBuilder(this).setTitle("Couldn’t complete request")
                .setMessage(message).setPositiveButton("OK", null).show();
    }

    private void showObject(JSONObject object) {
        ScrollView scroll = new ScrollView(this);
        scroll.addView(objectView(object));
        replaceContent(scroll);
    }

    private LinearLayout objectView(JSONObject object) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(Ui.dp(this, 20), Ui.dp(this, 16), Ui.dp(this, 20), Ui.dp(this, 28));
        Iterator<String> keys = object.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = object.opt(key);
            if (value instanceof JSONArray || value instanceof JSONObject || value == JSONObject.NULL) continue;
            com.google.android.material.card.MaterialCardView card =
                    new com.google.android.material.card.MaterialCardView(this);
            card.setCardBackgroundColor(Ui.surfaceContainer(this));
            card.setCardElevation(0);
            card.setRadius(Ui.dp(this, 18));
            LinearLayout field = new LinearLayout(this);
            field.setOrientation(LinearLayout.VERTICAL);
            field.setPadding(Ui.dp(this, 16), Ui.dp(this, 12),
                    Ui.dp(this, 16), Ui.dp(this, 12));
            TextView name = Ui.label(this, key.replace('_', ' '), 12, Ui.MUTED);
            TextView data = Ui.label(this, String.valueOf(value), 16, Ui.INK);
            data.setTextIsSelectable(true);
            field.addView(name, new LinearLayout.LayoutParams(-1, Ui.dp(this, 26)));
            field.addView(data, new LinearLayout.LayoutParams(-1, -2));
            card.addView(field);
            LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, -2);
            params.setMargins(0, 0, 0, Ui.dp(this, 8));
            box.addView(card, params);
        }
        return box;
    }

    private View tweetList(List<Tweet> tweets) {
        TweetAdapter adapter = new TweetAdapter(this, this);
        adapter.replace(tweets);
        ListView list = new ListView(this);
        list.setDivider(new ColorDrawable(Color.TRANSPARENT));
        list.setDividerHeight(Ui.dp(this, 8));
        list.setClipToPadding(false);
        list.setPadding(Ui.dp(this, 8), Ui.dp(this, 8),
                Ui.dp(this, 8), Ui.dp(this, 16));
        list.setAdapter(adapter);
        return list;
    }

    private View peopleList(JSONArray users) {
        UserSearchAdapter adapter = new UserSearchAdapter(this, users);
        ListView list = new ListView(this);
        list.setDivider(new ColorDrawable(Color.TRANSPARENT));
        list.setDividerHeight(Ui.dp(this, 8));
        list.setClipToPadding(false);
        list.setPadding(Ui.dp(this, 8), Ui.dp(this, 8),
                Ui.dp(this, 8), Ui.dp(this, 16));
        list.setAdapter(adapter);
        list.setOnItemClickListener((parent, view, position, id) ->
                profile(adapter.username(position)));
        return list;
    }

    private View jsonList(String heading, String sourcePath, JSONArray array) {
        ListView list = new ListView(this);
        JsonAdapter adapter = new JsonAdapter(this, array);
        list.setDivider(null);
        list.setClipToPadding(false);
        list.setPadding(Ui.dp(this, 8), Ui.dp(this, 6),
                Ui.dp(this, 8), Ui.dp(this, 16));
        list.setAdapter(adapter);
        list.setOnItemClickListener((parent, view, position, id) ->
                openGenericItem(heading, sourcePath, adapter.item(position)));
        return list;
    }

    private View stateView(String heading, String detail, boolean loading) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setGravity(Gravity.CENTER);
        box.setPadding(Ui.dp(this, 28), Ui.dp(this, 32),
                Ui.dp(this, 28), Ui.dp(this, 32));
        if (loading) {
            CircularProgressIndicator progress = new CircularProgressIndicator(this);
            progress.setIndeterminate(true);
            box.addView(progress, new LinearLayout.LayoutParams(
                    Ui.dp(this, 48), Ui.dp(this, 48)));
        }
        TextView h = Ui.label(this, heading, 21, Ui.INK);
        Ui.bold(h);
        h.setGravity(Gravity.CENTER);
        h.setPadding(0, Ui.dp(this, 12), 0, Ui.dp(this, 4));
        box.addView(h, new LinearLayout.LayoutParams(-1, -2));
        if (detail != null && !detail.trim().isEmpty()) {
            TextView d = Ui.label(this, detail, 15, Ui.MUTED);
            d.setGravity(Gravity.CENTER);
            box.addView(d, new LinearLayout.LayoutParams(-1, -2));
        }
        return box;
    }

    private MaterialButton menuButton(String text, int icon) {
        MaterialButton button = new MaterialButton(this, null,
                com.google.android.material.R.attr.materialButtonTonalStyle);
        button.setText(text);
        button.setTextSize(14);
        button.setAllCaps(false);
        button.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        button.setTextAlignment(View.TEXT_ALIGNMENT_VIEW_START);
        button.setIconResource(icon);
        button.setIconGravity(MaterialButton.ICON_GRAVITY_TEXT_START);
        button.setIconPadding(Ui.dp(this, 14));
        button.setCornerRadius(Ui.dp(this, 20));
        button.setInsetTop(0);
        button.setInsetBottom(0);
        return button;
    }

    private LinearLayout.LayoutParams menuRowParams() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, Ui.dp(this, 68));
        params.setMargins(0, Ui.dp(this, 3), 0, Ui.dp(this, 3));
        return params;
    }

    private int iconForFeature(FeatureCatalog.Feature feature) {
        if (feature.title.contains("Bookmark")) return R.drawable.ic_bookmark;
        if (feature.title.contains("Message")) return R.drawable.ic_send;
        if (feature.section.equals("Discover")) return R.drawable.ic_search;
        if (feature.section.equals("Administration")) return R.drawable.ic_account;
        if (feature.section.equals("Account")) return R.drawable.ic_account;
        return R.drawable.ic_menu;
    }

    private void replaceContent(View view) {
        content.removeAllViews();
        content.addView(view, new FrameLayout.LayoutParams(-1, -1));
    }

    private EditText input(String hint) {
        EditText input = new TextInputEditText(this);
        input.setHint(hint);
        input.setTextSize(16);
        input.setSingleLine(false);
        input.setPadding(Ui.dp(this, 14), Ui.dp(this, 12), Ui.dp(this, 14), Ui.dp(this, 12));
        return input;
    }

    private TextInputLayout outlinedField(String hint, boolean password) {
        TextInputLayout box = new TextInputLayout(this, null,
                com.google.android.material.R.attr.textInputOutlinedStyle);
        box.setHint(hint);
        TextInputEditText edit = new TextInputEditText(box.getContext());
        edit.setSingleLine(true);
        box.addView(edit, new LinearLayout.LayoutParams(-1, -2));
        if (password) box.setEndIconMode(TextInputLayout.END_ICON_PASSWORD_TOGGLE);
        return box;
    }

    private TextInputLayout wrapField(EditText edit, String hint) {
        TextInputLayout box = new TextInputLayout(this, null,
                com.google.android.material.R.attr.textInputOutlinedStyle);
        box.setHint(hint);
        edit.setHint(null);
        box.addView(edit, new LinearLayout.LayoutParams(-1, -2));
        return box;
    }

    private void addProfileDetail(LinearLayout parent, String label, String value) {
        com.google.android.material.card.MaterialCardView card =
                new com.google.android.material.card.MaterialCardView(this);
        card.setCardBackgroundColor(Ui.surfaceContainer(this));
        card.setCardElevation(0);
        card.setRadius(Ui.dp(this, 20));
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(Ui.dp(this, 18), Ui.dp(this, 12),
                Ui.dp(this, 18), Ui.dp(this, 12));
        TextView name = Ui.label(this, label, 12, Ui.MUTED);
        TextView data = Ui.label(this, value, 15, Ui.INK);
        data.setTextIsSelectable(true);
        data.setAutoLinkMask(Linkify.WEB_URLS);
        content.addView(name, new LinearLayout.LayoutParams(-1, -2));
        content.addView(data, new LinearLayout.LayoutParams(-1, -2));
        card.addView(content);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, -2);
        params.setMargins(0, 0, 0, Ui.dp(this, 8));
        parent.addView(card, params);
    }

    private static String cleanValue(JSONObject object, String key, String fallback) {
        if (object == null || object.isNull(key)) return fallback;
        String value = object.optString(key, fallback).trim();
        return value.isEmpty() || "null".equalsIgnoreCase(value) ? fallback : value;
    }

    private static String formatProfileDate(String raw) {
        try {
            return DateTimeFormatter.ofPattern("MMMM yyyy", Locale.getDefault())
                    .format(Instant.parse(raw).atZone(ZoneId.systemDefault()));
        } catch (DateTimeParseException ignored) {
            return raw.length() >= 10 ? raw.substring(0, 10) : raw;
        }
    }

    private void toast(String message) {
        if (content != null) Snackbar.make(content, message, Snackbar.LENGTH_SHORT).show();
        else Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }

    private static String titleCase(String text) {
        return Character.toUpperCase(text.charAt(0)) + text.substring(1).replace('-', ' ');
    }

    private static boolean looksLikeTweets(JSONObject body) {
        for (String key : new String[]{"posts", "timeline", "tweets", "bookmarks", "articles", "highlights"})
            if (body.optJSONArray(key) != null) return true;
        return false;
    }

    private static JSONArray findArray(JSONObject body, String preferred) {
        if (preferred != null && body.optJSONArray(preferred) != null) return body.optJSONArray(preferred);
        String[] keys = {"notifications", "conversations", "messages", "users", "communities",
                "lists", "ownedLists", "followedLists", "results", "items", "products",
                "purchases", "reports", "logs", "blocks", "emojis", "badges", "requests",
                "delegates", "delegations", "invitations", "scheduled", "interests", "words"};
        for (String key : keys) if (body.optJSONArray(key) != null) return body.optJSONArray(key);
        return null;
    }

    private static JSONObject json(String key, Object value) {
        JSONObject object = new JSONObject(); put(object, key, value); return object;
    }

    private static void put(JSONObject object, String key, Object value) {
        try { object.put(key, value); } catch (JSONException ignored) { }
    }

    @Override protected void onDestroy() {
        api.shutdown();
        super.onDestroy();
    }

    private static final class JsonAdapter extends BaseAdapter {
        private final Context context;
        private final List<JSONObject> items = new ArrayList<>();

        JsonAdapter(Context context, JSONArray array) {
            this.context = context;
            for (int i = 0; i < array.length(); i++) {
                JSONObject item = array.optJSONObject(i);
                if (item != null) {
                    items.add(item);
                } else {
                    Object raw = array.opt(i);
                    if (raw != null && raw != JSONObject.NULL) items.add(json("value", raw));
                }
            }
        }
        JSONObject item(int position) { return items.get(position); }
        @Override public int getCount() { return items.size(); }
        @Override public JSONObject getItem(int position) { return item(position); }
        @Override public long getItemId(int position) { return position; }
        @Override public View getView(int position, View recycled, ViewGroup parent) {
            JSONObject item = item(position);
            com.google.android.material.card.MaterialCardView card =
                    new com.google.android.material.card.MaterialCardView(context);
            card.setCardBackgroundColor(Ui.surfaceContainer(context));
            card.setCardElevation(0);
            card.setRadius(Ui.dp(context, 20));
            LinearLayout row = new LinearLayout(context);
            row.setOrientation(LinearLayout.VERTICAL);
            row.setPadding(Ui.dp(context, 18), Ui.dp(context, 14),
                    Ui.dp(context, 18), Ui.dp(context, 14));
            TextView primary = Ui.label(context, primary(item), 16, Ui.INK); Ui.bold(primary);
            TextView secondary = Ui.label(context, secondary(item), 14, Ui.MUTED);
            secondary.setMaxLines(3);
            row.addView(primary, new LinearLayout.LayoutParams(-1, Ui.dp(context, 30)));
            row.addView(secondary, new LinearLayout.LayoutParams(-1, -2));
            card.addView(row);
            card.setClickable(true);
            card.setFocusable(true);
            card.setMinimumHeight(Ui.dp(context, 76));
            return card;
        }
        private static String primary(JSONObject item) {
            for (String key : new String[]{"display_name", "title", "name", "username", "type", "word", "value", "id"}) {
                String value = item.optString(key, ""); if (!value.trim().isEmpty()) return value;
            }
            return "Item";
        }
        private static String secondary(JSONObject item) {
            for (String key : new String[]{"content", "description", "bio", "last_message_content",
                    "subtitle", "reason", "created_at", "status"}) {
                String value = item.optString(key, ""); if (!value.trim().isEmpty()) return value;
            }
            return "Tap for details";
        }
    }
}
