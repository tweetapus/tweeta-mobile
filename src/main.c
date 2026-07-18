#include <gtk/gtk.h>
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpedantic"
#include <handy.h>
#pragma GCC diagnostic pop
#include <curl/curl.h>
#include <stdlib.h>
#include "globals.h"
#include "session.h"
#include "actions.h"
#include "views.h"
#include "types.h"
#include "p2p_network.h"
#include "p2p_crypto.h"

int main(int argc, char *argv[]) {
    GtkWidget *window;

    gtk_init(&argc, &argv);
    hdy_init();
    curl_global_init(CURL_GLOBAL_ALL);

    g_mutex_init(&g_globals_mutex);
    g_interaction_cache = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);

    GtkCssProvider *provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(provider,
        "window { background-color: @theme_base_color; }"
        "headerbar { min-height: 50px; padding: 2px 6px; border: none;"
        "  box-shadow: 0 1px alpha(@theme_fg_color, 0.12); }"
        "button { min-height: 42px; min-width: 42px; border-radius: 10px; }"
        "entry, textview { font-size: 1.05em; }"
        "list { background: @theme_base_color; }"
        "list row { padding: 0; background: @theme_base_color; }"
        "list row:hover { background: alpha(@theme_selected_bg_color, 0.04); }"
        ".mobile-nav { border-top: 1px solid alpha(@theme_fg_color, 0.16);"
        "  background-color: @theme_base_color; padding: 3px 2px 5px; }"
        ".mobile-nav-button { min-height: 56px; min-width: 48px; padding: 3px;"
        "  border: none; border-radius: 10px; background: transparent; box-shadow: none; }"
        ".mobile-nav-button:hover { background: alpha(@theme_selected_bg_color, 0.12); }"
        ".mobile-nav-label { font-size: 0.78em; }"
        ".post-action { min-height: 46px; border: none; box-shadow: none;"
        "  background: transparent; font-size: 1.25em; padding: 2px; }"
        ".post-action:hover { background: alpha(@theme_selected_bg_color, 0.10); }"
        ".message-action { min-height: 42px; border: none; box-shadow: none;"
        "  background: transparent; font-size: 1.15em; padding: 2px; }"
        ".message-action:hover { background: alpha(@theme_selected_bg_color, 0.10); }"
        ".mobile-icon-button { border: none; box-shadow: none; background: transparent; }"
        ".mobile-icon-button:hover { background: alpha(@theme_selected_bg_color, 0.10); }"
        ".mobile-menu-action { min-height: 44px; min-width: 220px; padding: 4px 12px;"
        "  border: none; border-radius: 8px; box-shadow: none; background: transparent; }"
        ".mobile-menu-action:hover { background: alpha(@theme_selected_bg_color, 0.10); }"
        ".pill-button { border-radius: 18px; padding: 2px 14px; }"
        ".settings-page frame > border { border: 1px solid alpha(@theme_fg_color, 0.14);"
        "  border-radius: 12px; }"
        ".settings-page button:not(.suggested-action):not(.destructive-action) {"
        "  box-shadow: none; background: transparent; }"
        ".settings-page button:hover { background: alpha(@theme_selected_bg_color, 0.10); }"
        ".search-panel { border-bottom: 1px solid alpha(@theme_fg_color, 0.12); }"
        ".search-panel entry { min-height: 44px; border-radius: 12px; }"
        ".search-switcher { min-height: 44px; }"
        ".search-placeholder { opacity: 0.65; font-size: 1.05em; }"
        ".user-result-row { min-height: 64px; padding: 0; border: none;"
        "  border-radius: 0; box-shadow: none; background: transparent; }"
        ".user-result-row:hover { background: alpha(@theme_selected_bg_color, 0.08); }"
        ".mobile-tabs header { border: none; background: @theme_base_color; }"
        ".mobile-tabs tab { min-height: 42px; padding: 2px 10px; }"
        ".unread-notification { background-color: rgba(0, 100, 255, 0.1); }"
        ".dim-label { opacity: 0.7; font-size: 0.9em; }"
        ".note-frame { border-radius: 5px; border: 1px solid #ccc; }"
        ".note-warning { background-color: rgba(255, 165, 0, 0.1); border-color: orange; }"
        ".note-danger { background-color: rgba(255, 0, 0, 0.1); border-color: red; }"
        ".note-info { background-color: rgba(0, 191, 255, 0.1); border-color: deepskyblue; }",
        -1, NULL);
    gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),
        GTK_STYLE_PROVIDER(provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(provider);

    window = create_window();

    load_session();
    update_login_ui();

    gtk_widget_show_all(window);

    start_loading_tweets(GTK_LIST_BOX(g_main_list_box));

    gtk_main();

    curl_global_cleanup();
    if (g_interaction_cache) {
        g_hash_table_unref(g_interaction_cache);
    }
    g_free(g_auth_token);
    g_free(g_current_username);
    g_free(g_community_id);

    if (g_p2p_session) {
        p2p_free_session(g_p2p_session);
    }

    p2p_network_cleanup();
    p2p_crypto_cleanup();

    g_mutex_clear(&g_globals_mutex);

    return 0;
}
