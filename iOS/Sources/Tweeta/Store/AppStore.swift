import Observation
import SwiftUI

@MainActor
@Observable
final class AppStore {
  var selectedTab: AppTab = .home
  var timeline: Timeline = .forYou
  var posts: [Post] = AppStore.previewPosts
  var notifications: [TweetaNotification] = AppStore.previewNotifications
  var isDarkMode = true

  var colorScheme: ColorScheme { isDarkMode ? .dark : .light }
  var unreadCount: Int { notifications.filter(\.isUnread).count }

  func toggleLike(_ id: UUID) {
    guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
    posts[index].isLiked.toggle()
    posts[index].likeCount += posts[index].isLiked ? 1 : -1
  }

  func toggleBoost(_ id: UUID) {
    guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
    posts[index].isBoosted.toggle()
    posts[index].boostCount += posts[index].isBoosted ? 1 : -1
  }

  func toggleBookmark(_ id: UUID) {
    guard let index = posts.firstIndex(where: { $0.id == id }) else { return }
    posts[index].isBookmarked.toggle()
  }

  func publish(_ text: String) {
    let post = Post(
      author: "Lily", handle: "lily", avatar: "L", verified: false,
      timestamp: "now", body: text, replyCount: 0, boostCount: 0, likeCount: 0
    )
    posts.insert(post, at: 0)
    selectedTab = .home
  }

  func markNotificationsRead() {
    for index in notifications.indices {
      notifications[index].isUnread = false
    }
  }

  private static let previewPosts: [Post] = [
    Post(
      author: "Maya Chen", handle: "mayamakes", avatar: "MC", verified: true,
      timestamp: "12m",
      body:
        "There is something magical about building small things with care. Today’s experiment: a weather orb that changes colour with the sky.",
      media: .aurora, replyCount: 18, boostCount: 42, likeCount: 286, isLiked: true
    ),
    Post(
      author: "Theo Martin", handle: "theom", avatar: "TM",
      timestamp: "34m",
      body:
        "Hot take: the best social apps feel less like a stage and more like the kitchen at a good house party.",
      replyCount: 31, boostCount: 19, likeCount: 174
    ),
    Post(
      author: "Noor", handle: "noor.codes", avatar: "N", verified: true,
      timestamp: "1h",
      body: "Melbourne after the rain. No filter, just that impossible winter light.",
      media: .city, replyCount: 9, boostCount: 28, likeCount: 411, isBookmarked: true
    ),
    Post(
      author: "Ocean Archive", handle: "oceanarchive", avatar: "OA",
      timestamp: "2h",
      body: "A quiet reminder that blue is not one colour. It is an entire language.",
      media: .ocean, replyCount: 12, boostCount: 67, likeCount: 520
    ),
  ]

  private static let previewNotifications: [TweetaNotification] = [
    TweetaNotification(
      kind: .liked, avatar: "MC", title: "Maya liked your post",
      detail: "The tiny details really do make it sing.", time: "8m", isUnread: true),
    TweetaNotification(
      kind: .followed, avatar: "T", title: "Theo followed you", detail: "@theom", time: "26m",
      isUnread: true),
    TweetaNotification(
      kind: .replied, avatar: "N", title: "Noor replied",
      detail: "Absolutely. This is the kind of internet I want more of.", time: "1h", isUnread: true
    ),
    TweetaNotification(
      kind: .boosted, avatar: "OA", title: "Ocean Archive boosted your post",
      detail: "Your weekend photo journal", time: "4h", isUnread: false),
    TweetaNotification(
      kind: .liked, avatar: "EK", title: "Eli and 12 others liked your post",
      detail: "Making a native client, one glassy surface at a time.", time: "Yesterday",
      isUnread: false),
  ]
}
