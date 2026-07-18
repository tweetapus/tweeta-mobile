import Foundation

struct Post: Identifiable, Hashable, Sendable {
  struct Attachment: Hashable, Sendable {
    let url: URL
    let type: String

    var isImage: Bool {
      type.lowercased().hasPrefix("image/")
        || ["jpg", "jpeg", "png", "gif", "webp", "avif"].contains(
          url.pathExtension.lowercased())
    }
  }

  let id: String
  let author: String
  let handle: String
  let avatar: String
  let avatarURL: URL?
  let verified: Bool
  let createdAt: Date?
  var body: String
  let attachments: [Attachment]
  var replyCount: Int
  var boostCount: Int
  var likeCount: Int
  var isBoosted: Bool
  var isLiked: Bool
  var isBookmarked: Bool

  var timestamp: String { createdAt.map(Self.relativeTime) ?? "" }

  init(apiPost: APIPost, api: TweetapusAPI) {
    id = apiPost.id
    author = apiPost.author.name
    handle = apiPost.author.username
    avatar = Self.initials(name: apiPost.author.name, username: apiPost.author.username)
    avatarURL = api.resourceURL(apiPost.author.avatar)
    verified = apiPost.author.verified
    createdAt = Self.parseDate(apiPost.createdAt)
    body = apiPost.content
    attachments = apiPost.attachments.compactMap { attachment in
      guard let url = api.resourceURL(attachment.url) else { return nil }
      return Attachment(url: url, type: attachment.type)
    }
    replyCount = apiPost.replyCount
    boostCount = apiPost.boostCount
    likeCount = apiPost.likeCount
    isBoosted = apiPost.boosted
    isLiked = apiPost.liked
    isBookmarked = apiPost.bookmarked
  }

  private static func initials(name: String, username: String) -> String {
    let words = name.split(separator: " ").prefix(2)
    let value = words.compactMap(\.first).map(String.init).joined()
    return value.isEmpty ? String(username.prefix(2)).uppercased() : value.uppercased()
  }

  static func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    if let date = ISO8601DateFormatter().date(from: value) { return date }
    let formats = ["yyyy-MM-dd HH:mm:ss.SSS", "yyyy-MM-dd HH:mm:ss"]
    for format in formats {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = format
      if let date = formatter.date(from: value) { return date }
    }
    return nil
  }

  static func relativeTime(_ date: Date) -> String {
    let seconds = max(0, Int(Date().timeIntervalSince(date)))
    if seconds < 60 { return "now" }
    if seconds < 3_600 { return "\(seconds / 60)m" }
    if seconds < 86_400 { return "\(seconds / 3_600)h" }
    if seconds < 604_800 { return "\(seconds / 86_400)d" }
    return date.formatted(.dateTime.month(.abbreviated).day())
  }
}

struct UserProfile: Sendable {
  let username: String
  let name: String
  let avatarURL: URL?
  let bannerURL: URL?
  let bio: String
  let location: String
  let website: String
  let joinedAt: Date?
  let verified: Bool
  let followerCount: Int
  let followingCount: Int
  let postCount: Int

  init(apiUser: APIUser, api: TweetapusAPI) {
    username = apiUser.username
    name = apiUser.name
    avatarURL = api.resourceURL(apiUser.avatar)
    bannerURL = api.resourceURL(apiUser.banner)
    bio = apiUser.bio
    location = apiUser.location
    website = apiUser.website
    joinedAt = Post.parseDate(apiUser.createdAt)
    verified = apiUser.verified
    followerCount = apiUser.followerCount
    followingCount = apiUser.followingCount
    postCount = apiUser.postCount
  }

  var initials: String {
    let value = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    return value.isEmpty ? String(username.prefix(2)).uppercased() : value.uppercased()
  }
}

struct SearchUser: Identifiable, Sendable {
  let id: String
  let username: String
  let name: String
  let avatarURL: URL?
  let bio: String
  let verified: Bool
  let followerCount: Int

  init(apiUser: APIUser, api: TweetapusAPI) {
    id = apiUser.id
    username = apiUser.username
    name = apiUser.name
    avatarURL = api.resourceURL(apiUser.avatar)
    bio = apiUser.bio
    verified = apiUser.verified
    followerCount = apiUser.followerCount
  }

  var initials: String {
    let value = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    return value.isEmpty ? String(username.prefix(2)).uppercased() : value.uppercased()
  }
}

struct TweetaNotification: Identifiable, Sendable {
  enum Kind: Sendable {
    case liked, boosted, followed, replied, mentioned, other

    var symbol: String {
      switch self {
      case .liked: "heart.fill"
      case .boosted: "arrow.2.squarepath"
      case .followed: "person.fill.badge.plus"
      case .replied: "bubble.left.fill"
      case .mentioned: "at"
      case .other: "bell.fill"
      }
    }
  }

  let id: String
  let kind: Kind
  let avatar: String
  let avatarURL: URL?
  let title: String
  let detail: String
  let createdAt: Date?
  var isUnread: Bool

  var time: String { createdAt.map(Post.relativeTime) ?? "" }

  init(apiNotification: APINotification, api: TweetapusAPI) {
    id = apiNotification.id
    switch apiNotification.type {
    case "like": kind = .liked
    case "retweet": kind = .boosted
    case "follow": kind = .followed
    case "reply", "quote": kind = .replied
    case "mention": kind = .mentioned
    default: kind = .other
    }
    let actor = apiNotification.actorName.isEmpty
      ? apiNotification.actorUsername : apiNotification.actorName
    let initials = actor.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    avatar = initials.isEmpty ? "?" : initials.uppercased()
    avatarURL = api.resourceURL(apiNotification.actorAvatar)
    title = Self.title(kind: kind, actor: actor)
    detail = apiNotification.content
    createdAt = Post.parseDate(apiNotification.createdAt)
    isUnread = !apiNotification.read
  }

  private static func title(kind: Kind, actor: String) -> String {
    switch kind {
    case .liked: "\(actor) liked your post"
    case .boosted: "\(actor) boosted your post"
    case .followed: "\(actor) followed you"
    case .replied: "\(actor) replied to you"
    case .mentioned: "\(actor) mentioned you"
    case .other: actor.isEmpty ? "New notification" : actor
    }
  }
}

enum AppTab: Hashable {
  case home, search, alerts, profile
}

enum Timeline: String, CaseIterable, Identifiable, Sendable {
  case publicFeed = "Public"
  case following = "Following"
  case forYou = "For You"

  var id: Self { self }
}
