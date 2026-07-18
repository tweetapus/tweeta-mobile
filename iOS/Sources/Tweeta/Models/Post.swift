import Foundation

struct Post: Identifiable, Hashable {
  enum Media: String, Hashable {
    case ocean
    case aurora
    case city
  }

  let id: UUID
  let author: String
  let handle: String
  let avatar: String
  let verified: Bool
  let timestamp: String
  var body: String
  let media: Media?
  var replyCount: Int
  var boostCount: Int
  var likeCount: Int
  var isBoosted: Bool
  var isLiked: Bool
  var isBookmarked: Bool

  init(
    id: UUID = UUID(),
    author: String,
    handle: String,
    avatar: String,
    verified: Bool = false,
    timestamp: String,
    body: String,
    media: Media? = nil,
    replyCount: Int,
    boostCount: Int,
    likeCount: Int,
    isBoosted: Bool = false,
    isLiked: Bool = false,
    isBookmarked: Bool = false
  ) {
    self.id = id
    self.author = author
    self.handle = handle
    self.avatar = avatar
    self.verified = verified
    self.timestamp = timestamp
    self.body = body
    self.media = media
    self.replyCount = replyCount
    self.boostCount = boostCount
    self.likeCount = likeCount
    self.isBoosted = isBoosted
    self.isLiked = isLiked
    self.isBookmarked = isBookmarked
  }
}

struct TweetaNotification: Identifiable {
  enum Kind {
    case liked, boosted, followed, replied

    var symbol: String {
      switch self {
      case .liked: "heart.fill"
      case .boosted: "arrow.2.squarepath"
      case .followed: "person.fill.badge.plus"
      case .replied: "bubble.left.fill"
      }
    }

    var tintName: String {
      switch self {
      case .liked: "pink"
      case .boosted: "mint"
      case .followed: "purple"
      case .replied: "blue"
      }
    }
  }

  let id = UUID()
  let kind: Kind
  let avatar: String
  let title: String
  let detail: String
  let time: String
  var isUnread: Bool
}

enum AppTab: Hashable {
  case home, search, alerts, profile
}

enum Timeline: String, CaseIterable, Identifiable {
  case publicFeed = "Public"
  case following = "Following"
  case forYou = "For You"

  var id: Self { self }
}
