# Mobile feature parity

This repository has two mobile targets, not a desktop and mobile pair. The
GNU/Linux phone application is the complete C client; Android is a native Java
implementation of the same server-facing product areas.

| Feature area | GNU/Linux phone (C/GTK3) | Android (Java) |
|---|---|---|
| Public, following, and recommended timelines | Full | Native timeline |
| Compose, reply, edit, delete | Full | Native dialogs |
| Like, boost, bookmark, report, translate | Full | Native post actions |
| Rich media attachments | Full | Native document picker, upload, and image rendering |
| Polls, quotes, scheduling, article authoring | Full | Native composer flows |
| GIF/Unsplash media search | Full | Android document picker is the native substitute; service search is tracked below |
| Search users and posts | Full | Native search and results |
| Profiles, follow state, profile feeds | Full | Native profile actions and feeds |
| Notifications | Full | Native collection screen |
| Server direct messages | Full | Native conversations, messages, and send flow |
| Bookmarks, lists, explore, articles, communities | Full | Native collection/detail screens |
| Account requests, filters, interests, scheduled posts, delegates, shop | Full | Native account collection/detail screens |
| Admin feature areas | Full | Exposed only for admin sessions, matching server authorization |
| Custom Tweetapus instances | Environment variables | Native HTTPS instance setting |
| Session protection | Mode `0600` session file | Android Keystore AES-GCM |

## Platform-specific substitutions

- The C phone app retains the GPGME/GnuPG encrypted direct P2P workspace.
  Android has server DMs, but direct GnuPG transport needs an Android keystore
  and background-network implementation; reusing desktop GPG sockets would be
  unsafe and unreliable under Android process lifecycle rules.
- The C phone app can use `libfido2` when built with `USE_FIDO2=1`. Android
  lists and manages server passkeys, while authentication must be completed by
  an Android Credential Manager implementation rather than libfido2.
- Android uses native text, attachment, poll, quote, scheduled-post, and Markdown
  article composers. In-app GIF/Unsplash search still needs a native result
  picker; Android's document picker already supports local GIFs and images. It
  must not be replaced with a WebView.

The final bullet is an explicit parity backlog, not a deliberate “lite” product
split. New server features should be added to both mobile targets and to this
matrix in the same change.
