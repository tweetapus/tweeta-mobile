import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

enum APIError: LocalizedError {
  case invalidServer
  case invalidResponse
  case server(status: Int, message: String)
  case message(String)

  var errorDescription: String? {
    switch self {
    case .invalidServer:
      "The selected instance address is invalid."
    case .invalidResponse:
      "The server returned a response Tweeta couldn’t understand."
    case .server(_, let message), .message(let message):
      message
    }
  }

  var isAuthenticationFailure: Bool {
    switch self {
    case .server(let status, _): status == 401 || status == 403
    case .message(let message):
      ["authentication", "unauthorized", "invalid token"].contains {
        message.localizedCaseInsensitiveContains($0)
      }
    default: false
    }
  }
}

struct TweetapusAPI: Sendable {
  let instanceURL: URL
  let token: String?

  init(instanceAddress: String, token: String? = nil) throws {
    guard let instanceURL = URL(string: instanceAddress) else { throw APIError.invalidServer }
    self.instanceURL = instanceURL
    self.token = token
  }

  func timeline(_ timeline: Timeline) async throws -> [APIPost] {
    let path: String
    switch timeline {
    case .publicFeed: path = "/public-tweets"
    case .following: path = "/timeline/following"
    case .forYou: path = "/timeline"
    }
    let response: PostCollection = try await request(path, query: ["limit": "30"])
    return response.posts
  }

  func login(username: String, password: String) async throws -> LoginResponse {
    try await request(
      "/auth/basic-login", method: "POST",
      body: try encode(LoginRequest(username: username, password: password)))
  }

  func profile(username: String) async throws -> ProfileResponse {
    try await request("/profile/\(pathComponent(username))")
  }

  func profileReplies(username: String) async throws -> [APIPost] {
    let response: PostCollection = try await request("/profile/\(pathComponent(username))/replies")
    return response.posts
  }

  func notifications() async throws -> [APINotification] {
    let response: NotificationCollection = try await request(
      "/notifications", query: ["limit": "50"])
    return response.notifications
  }

  func markAllNotificationsRead() async throws {
    let _: SuccessResponse = try await request("/notifications/mark-all-read", method: "PATCH")
  }

  func searchPosts(_ query: String, sort: String) async throws -> [APIPost] {
    let response: PostCollection = try await request(
      "/search/posts", query: ["q": query], headers: ["X-Query-Params": "sort=\(sort)&limit=30"])
    return response.posts
  }

  func searchUsers(_ query: String) async throws -> [APIUser] {
    let response: UserCollection = try await request(
      "/search/users", query: ["q": query, "limit": "30"])
    return response.users
  }

  func createPost(content: String, replyTo: String? = nil, pollOptions: [String] = []) async throws {
    let poll = pollOptions.count >= 2 ? CreatePostRequest.Poll(options: pollOptions, duration: 1_440) : nil
    let payload = CreatePostRequest(
      content: content, source: "Tweeta iOS", replyTo: replyTo, poll: poll)
    let _: SuccessResponse = try await request(
      "/tweets", method: "POST", body: try encode(payload))
  }

  func toggleLike(postID: String) async throws {
    let _: SuccessResponse = try await request(
      "/tweets/\(pathComponent(postID))/like", method: "POST", body: emptyObject)
  }

  func toggleBoost(postID: String) async throws {
    let _: SuccessResponse = try await request(
      "/tweets/\(pathComponent(postID))/retweet", method: "POST", body: emptyObject)
  }

  func setBookmark(postID: String, bookmarked: Bool) async throws {
    let request = BookmarkRequest(postID: postID)
    let _: SuccessResponse = try await self.request(
      bookmarked ? "/bookmarks/add" : "/bookmarks/remove", method: "POST",
      body: try encode(request))
  }

  func resourceURL(_ value: String?) -> URL? {
    guard let value, !value.isEmpty else { return nil }
    if let url = URL(string: value), url.scheme != nil { return url }
    guard var components = URLComponents(url: instanceURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    components.path = value.hasPrefix("/") ? value : "/" + value
    components.query = nil
    components.fragment = nil
    return components.url
  }

  private var apiBaseURL: URL {
    var url = instanceURL
    if url.path.split(separator: "/").last?.lowercased() != "api" {
      url.appendPathComponent("api")
    }
    return url
  }

  private var emptyObject: Data { Data("{}".utf8) }

  private func request<Response: Decodable>(
    _ path: String,
    method: String = "GET",
    query: [String: String] = [:],
    headers: [String: String] = [:],
    body: Data? = nil
  ) async throws -> Response {
    var url = apiBaseURL
    for component in path.split(separator: "/") {
      url.appendPathComponent(String(component))
    }
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw APIError.invalidServer
    }
    if !query.isEmpty {
      components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    guard let requestURL = components.url else { throw APIError.invalidServer }

    var request = URLRequest(url: requestURL)
    request.httpMethod = method
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    request.setValue("Tweeta iOS; 1.0.0", forHTTPHeaderField: "X-Tweetapus-Client")
    if let token {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    for (name, value) in headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    request.httpBody = body

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      if error is CancellationError { throw error }
      throw APIError.message(error.localizedDescription)
    }
    guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }

    let decoder = JSONDecoder()
    if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data),
      let message = errorResponse.error, !message.isEmpty
    {
      if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
        throw APIError.server(status: httpResponse.statusCode, message: message)
      }
      throw APIError.message(message)
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.server(
        status: httpResponse.statusCode,
        message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
    }
    if Response.self == SuccessResponse.self, data.isEmpty {
      return SuccessResponse(success: true) as! Response
    }
    do {
      return try decoder.decode(Response.self, from: data)
    } catch {
      throw APIError.invalidResponse
    }
  }

  private func encode<Value: Encodable>(_ value: Value) throws -> Data {
    try JSONEncoder().encode(value)
  }

  private func pathComponent(_ value: String) -> String {
    value
  }
}

struct LoginResponse: Decodable, Sendable {
  let token: String
  let user: APIUser
}

struct ProfileResponse: Decodable, Sendable {
  let profile: APIUser
  let posts: [APIPost]
  let isOwnProfile: Bool

  private enum CodingKeys: String, CodingKey {
    case profile, posts
    case isOwnProfile
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    profile = try container.decode(APIUser.self, forKey: .profile)
    posts = try container.decodeIfPresent([APIPost].self, forKey: .posts) ?? []
    isOwnProfile = try container.decodeLossyBoolIfPresent(forKey: .isOwnProfile) ?? false
  }
}

struct APIUser: Decodable, Sendable, Identifiable {
  let id: String
  let username: String
  let name: String
  let avatar: String?
  let banner: String?
  let bio: String
  let location: String
  let website: String
  let createdAt: String?
  let verified: Bool
  let followerCount: Int
  let followingCount: Int
  let postCount: Int

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    username = container.lossyString("username") ?? "unknown"
    id = container.lossyString("id") ?? username
    name = container.lossyString("name") ?? username
    avatar = container.lossyString("avatar") ?? container.lossyString("avatar_url")
    banner = container.lossyString("banner") ?? container.lossyString("banner_url")
    bio = container.lossyString("bio") ?? ""
    location = container.lossyString("location") ?? ""
    website = container.lossyString("website") ?? container.lossyString("url") ?? ""
    createdAt = container.lossyString("created_at") ?? container.lossyString("joined_at")
    verified = container.lossyBool("verified") ?? false
    followerCount = container.lossyInt("follower_count") ?? container.lossyInt("followers") ?? 0
    followingCount =
      container.lossyInt("following_count") ?? container.lossyInt("following") ?? 0
    postCount = container.lossyInt("post_count") ?? container.lossyInt("posts") ?? 0
  }
}

struct APIPost: Decodable, Sendable {
  let id: String
  let content: String
  let createdAt: String?
  let author: APIUser
  let attachments: [APIAttachment]
  let replyCount: Int
  let likeCount: Int
  let boostCount: Int
  let liked: Bool
  let boosted: Bool
  let bookmarked: Bool

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    guard let id = container.lossyString("id") else {
      throw DecodingError.keyNotFound(
        AnyCodingKey("id"), .init(codingPath: decoder.codingPath, debugDescription: "Missing post id"))
    }
    self.id = id
    content = container.lossyString("content") ?? ""
    createdAt = container.lossyString("created_at")
    if let nested = try? container.decode(APIUser.self, forKey: AnyCodingKey("author")) {
      author = nested
    } else if let nested = try? container.decode(APIUser.self, forKey: AnyCodingKey("user")) {
      author = nested
    } else {
      author = try APIUser(from: decoder)
    }
    attachments =
      (try? container.decode([APIAttachment].self, forKey: AnyCodingKey("attachments"))) ?? []
    replyCount = container.lossyInt("reply_count") ?? container.lossyInt("replies") ?? 0
    likeCount = container.lossyInt("like_count") ?? container.lossyInt("likes") ?? 0
    boostCount = container.lossyInt("retweet_count") ?? container.lossyInt("retweets") ?? 0
    let interaction = try? container.decode(
      APIInteraction.self, forKey: AnyCodingKey("interaction"))
    liked =
      container.lossyBool("liked_by_user") ?? container.lossyBool("liked")
      ?? interaction?.liked ?? false
    boosted =
      container.lossyBool("retweeted_by_user") ?? container.lossyBool("retweeted")
      ?? interaction?.retweeted ?? false
    bookmarked =
      container.lossyBool("bookmarked_by_user") ?? container.lossyBool("bookmarked")
      ?? interaction?.bookmarked ?? false
  }
}

struct APIAttachment: Decodable, Sendable {
  let url: String
  let type: String

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    url = container.lossyString("file_url") ?? container.lossyString("url") ?? ""
    type = container.lossyString("file_type") ?? container.lossyString("type") ?? ""
  }
}

private struct APIInteraction: Decodable {
  let liked: Bool
  let retweeted: Bool
  let bookmarked: Bool

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    liked = container.lossyBool("liked") ?? false
    retweeted = container.lossyBool("retweeted") ?? false
    bookmarked = container.lossyBool("bookmarked") ?? false
  }
}

struct APINotification: Decodable, Sendable {
  let id: String
  let type: String
  let content: String
  let actorUsername: String
  let actorName: String
  let actorAvatar: String?
  let read: Bool
  let createdAt: String?

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    id = container.lossyString("id") ?? UUID().uuidString
    type = container.lossyString("type") ?? "notification"
    content = container.lossyString("content") ?? ""
    actorUsername = container.lossyString("actor_username") ?? ""
    actorName = container.lossyString("actor_name") ?? actorUsername
    actorAvatar = container.lossyString("actor_avatar")
    read = container.lossyBool("read") ?? false
    createdAt = container.lossyString("created_at")
  }
}

private struct PostCollection: Decodable {
  let posts: [APIPost]

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: AnyCodingKey.self)
    let keys = ["posts", "timeline", "tweets", "replies", "bookmarks", "highlights"]
    posts = keys.lazy.compactMap {
      try? container.decode([APIPost].self, forKey: AnyCodingKey($0))
    }.first ?? []
  }
}

private struct NotificationCollection: Decodable {
  let notifications: [APINotification]
}

private struct UserCollection: Decodable {
  let users: [APIUser]
}

private struct LoginRequest: Encodable {
  let username: String
  let password: String
}

private struct CreatePostRequest: Encodable {
  struct Poll: Encodable {
    let options: [String]
    let duration: Int
  }

  let content: String
  let source: String
  let replyTo: String?
  let poll: Poll?

  enum CodingKeys: String, CodingKey {
    case content, source, poll
    case replyTo = "reply_to"
  }
}

private struct BookmarkRequest: Encodable {
  let postID: String
  enum CodingKeys: String, CodingKey { case postID = "postId" }
}

private struct ErrorResponse: Decodable { let error: String? }
private struct SuccessResponse: Decodable {
  let success: Bool?
  init(success: Bool? = nil) { self.success = success }
}

private struct AnyCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int? = nil

  init(_ stringValue: String) { self.stringValue = stringValue }
  init?(stringValue: String) { self.stringValue = stringValue }
  init?(intValue: Int) { return nil }
}

private extension KeyedDecodingContainer where Key == AnyCodingKey {
  func lossyString(_ key: String) -> String? {
    let codingKey = AnyCodingKey(key)
    if let value = try? decodeIfPresent(String.self, forKey: codingKey) { return value }
    if let value = try? decodeIfPresent(Int.self, forKey: codingKey) { return String(value) }
    return nil
  }

  func lossyInt(_ key: String) -> Int? {
    let codingKey = AnyCodingKey(key)
    if let value = try? decodeIfPresent(Int.self, forKey: codingKey) { return value }
    if let value = try? decodeIfPresent(Double.self, forKey: codingKey) { return Int(value) }
    if let value = try? decodeIfPresent(String.self, forKey: codingKey) { return Int(value) }
    return nil
  }

  func lossyBool(_ key: String) -> Bool? {
    let codingKey = AnyCodingKey(key)
    if let value = try? decodeIfPresent(Bool.self, forKey: codingKey) { return value }
    if let value = try? decodeIfPresent(Int.self, forKey: codingKey) { return value != 0 }
    if let value = try? decodeIfPresent(String.self, forKey: codingKey) {
      return ["true", "1", "yes"].contains(value.lowercased())
    }
    return nil
  }
}

private extension KeyedDecodingContainer {
  func decodeLossyBoolIfPresent(forKey key: Key) throws -> Bool? {
    if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
    if let value = try? decodeIfPresent(Int.self, forKey: key) { return value != 0 }
    return nil
  }
}
