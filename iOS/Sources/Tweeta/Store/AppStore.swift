import Foundation
import Observation
import SwiftUI

struct ServerInstance: Codable, Hashable, Identifiable {
  let id: UUID
  let address: String

  init(id: UUID = UUID(), address: String) {
    self.id = id
    self.address = address
  }

  var host: String {
    URL(string: address)?.host() ?? address
  }
}

enum ServerInstanceError: LocalizedError {
  case invalidAddress
  case duplicate
  case lastInstance

  var errorDescription: String? {
    switch self {
    case .invalidAddress:
      "Enter a valid HTTPS server address."
    case .duplicate:
      "That server is already in your instances."
    case .lastInstance:
      "Add another instance before removing this one."
    }
  }
}

@MainActor
@Observable
final class AppStore {
  static let defaultInstanceAddress = "https://tweeta.tiago.zip"

  var selectedTab: AppTab = .home
  var timeline: Timeline = .forYou
  var posts: [Post] = AppStore.previewPosts
  var notifications: [TweetaNotification] = AppStore.previewNotifications
  var isDarkMode = true
  private(set) var instances: [ServerInstance]
  private(set) var selectedInstanceID: UUID

  @ObservationIgnored private let userDefaults: UserDefaults

  private static let instancesKey = "serverInstances"
  private static let selectedInstanceKey = "selectedServerInstanceID"

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults

    let savedInstances = userDefaults.data(forKey: Self.instancesKey)
      .flatMap { try? JSONDecoder().decode([ServerInstance].self, from: $0) }
      .flatMap { $0.isEmpty ? nil : $0 }
    let loadedInstances = savedInstances ?? [ServerInstance(address: Self.defaultInstanceAddress)]
    instances = loadedInstances

    let savedSelection = userDefaults.string(forKey: Self.selectedInstanceKey)
      .flatMap(UUID.init(uuidString:))
    if let savedSelection,
      loadedInstances.contains(where: { $0.id == savedSelection })
    {
      selectedInstanceID = savedSelection
    } else {
      selectedInstanceID = loadedInstances[0].id
    }
  }

  var colorScheme: ColorScheme { isDarkMode ? .dark : .light }
  var unreadCount: Int { notifications.filter(\.isUnread).count }
  var selectedInstance: ServerInstance {
    instances.first(where: { $0.id == selectedInstanceID }) ?? instances[0]
  }

  @discardableResult
  func addInstance(_ address: String) throws -> ServerInstance {
    let normalizedAddress = try Self.normalizedInstanceAddress(address)
    guard !instances.contains(where: { $0.address == normalizedAddress }) else {
      throw ServerInstanceError.duplicate
    }

    let instance = ServerInstance(address: normalizedAddress)
    instances.append(instance)
    selectedInstanceID = instance.id
    saveInstanceSettings()
    return instance
  }

  func selectInstance(_ id: UUID) {
    guard instances.contains(where: { $0.id == id }) else { return }
    selectedInstanceID = id
    saveInstanceSettings()
  }

  func removeInstance(_ id: UUID) throws {
    guard instances.count > 1 else { throw ServerInstanceError.lastInstance }
    guard let index = instances.firstIndex(where: { $0.id == id }) else { return }

    let wasSelected = selectedInstanceID == id
    instances.remove(at: index)
    if wasSelected {
      selectedInstanceID = instances[min(index, instances.count - 1)].id
    }
    saveInstanceSettings()
  }

  private static func normalizedInstanceAddress(_ input: String) throws -> String {
    var address = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if !address.contains("://") {
      address = "https://" + address
    }

    guard var components = URLComponents(string: address),
      components.scheme?.lowercased() == "https",
      components.host?.isEmpty == false,
      components.user == nil,
      components.password == nil,
      components.query == nil,
      components.fragment == nil
    else {
      throw ServerInstanceError.invalidAddress
    }

    components.scheme = "https"
    components.host = components.host?.lowercased()
    while components.path.hasSuffix("/") {
      components.path.removeLast()
    }
    guard let normalizedAddress = components.url?.absoluteString else {
      throw ServerInstanceError.invalidAddress
    }
    return normalizedAddress
  }

  private func saveInstanceSettings() {
    if let data = try? JSONEncoder().encode(instances) {
      userDefaults.set(data, forKey: Self.instancesKey)
    }
    userDefaults.set(selectedInstanceID.uuidString, forKey: Self.selectedInstanceKey)
  }

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
