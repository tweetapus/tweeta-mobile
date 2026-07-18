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

  var host: String { URL(string: address)?.host() ?? address }
}

enum ServerInstanceError: LocalizedError {
  case invalidAddress
  case duplicate
  case lastInstance

  var errorDescription: String? {
    switch self {
    case .invalidAddress: "Enter a valid HTTPS server address."
    case .duplicate: "That server is already in your instances."
    case .lastInstance: "Add another instance before removing this one."
    }
  }
}

@MainActor
@Observable
final class AppStore {
  static let defaultInstanceAddress = "https://tweeta.tiago.zip"

  var selectedTab: AppTab = .home
  var timeline: Timeline = .publicFeed
  var posts: [Post] = []
  var notifications: [TweetaNotification] = []
  var searchPosts: [Post] = []
  var searchUsers: [SearchUser] = []
  var profile: UserProfile?
  var profilePosts: [Post] = []
  var profileReplies: [Post] = []
  var isDarkMode = true
  var isLoadingTimeline = false
  var isLoadingNotifications = false
  var isLoadingProfile = false
  var isLoadingProfileReplies = false
  var isSearching = false
  var timelineError: String?
  var notificationError: String?
  var profileError: String?
  var searchError: String?
  var presentedError: String?
  private(set) var instances: [ServerInstance]
  private(set) var selectedInstanceID: UUID
  private(set) var session: UserSession?

  @ObservationIgnored private let userDefaults: UserDefaults
  @ObservationIgnored private let sessionVault = SessionVault()
  @ObservationIgnored private var timelineRequestID = UUID()

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
    if let savedSelection, loadedInstances.contains(where: { $0.id == savedSelection }) {
      selectedInstanceID = savedSelection
    } else {
      selectedInstanceID = loadedInstances[0].id
    }
    if let data = try? JSONEncoder().encode(loadedInstances) {
      userDefaults.set(data, forKey: Self.instancesKey)
    }
    userDefaults.set(selectedInstanceID.uuidString, forKey: Self.selectedInstanceKey)
    session = SessionVault().load(instanceID: selectedInstanceID)
  }

  var colorScheme: ColorScheme { isDarkMode ? .dark : .light }
  var unreadCount: Int { notifications.filter(\.isUnread).count }
  var isSignedIn: Bool { session != nil }
  var selectedInstance: ServerInstance {
    instances.first(where: { $0.id == selectedInstanceID }) ?? instances[0]
  }

  func bootstrap() async {
    await loadTimeline(isSignedIn ? .forYou : .publicFeed)
    if isSignedIn {
      await loadProfile()
      await loadNotifications()
    } else {
      profile = nil
      notifications = []
    }
  }

  func loadTimeline(_ requestedTimeline: Timeline? = nil) async {
    let requestedTimeline = requestedTimeline ?? timeline
    guard requestedTimeline == .publicFeed || isSignedIn else {
      presentedError = "Sign in to use the \(requestedTimeline.rawValue) timeline."
      return
    }
    timeline = requestedTimeline
    let instanceID = selectedInstanceID
    let requestID = UUID()
    timelineRequestID = requestID
    isLoadingTimeline = true
    timelineError = nil
    do {
      let api = try currentAPI()
      let response = try await api.timeline(requestedTimeline)
      guard instanceID == selectedInstanceID, requestID == timelineRequestID else { return }
      posts = response.map { Post(apiPost: $0, api: api) }
    } catch is CancellationError {
      if instanceID == selectedInstanceID, requestID == timelineRequestID {
        isLoadingTimeline = false
      }
      return
    } catch {
      guard instanceID == selectedInstanceID, requestID == timelineRequestID else { return }
      timelineError = error.localizedDescription
      handleAuthenticationFailure(error)
    }
    if instanceID == selectedInstanceID, requestID == timelineRequestID {
      isLoadingTimeline = false
    }
  }

  func signIn(username: String, password: String) async throws {
    let instanceID = selectedInstanceID
    let api = try TweetapusAPI(instanceAddress: selectedInstance.address)
    let response = try await api.login(username: username, password: password)
    guard instanceID == selectedInstanceID else { return }
    let newSession = UserSession(
      token: response.token, username: response.user.username, name: response.user.name,
      avatar: response.user.avatar)
    try sessionVault.save(newSession, instanceID: instanceID)
    session = newSession
    await loadTimeline(.following)
    await loadProfile()
    await loadNotifications()
  }

  func signOut() {
    sessionVault.delete(instanceID: selectedInstanceID)
    session = nil
    profile = nil
    profilePosts = []
    profileReplies = []
    notifications = []
    timeline = .publicFeed
    Task { await loadTimeline(.publicFeed) }
  }

  func loadProfile() async {
    guard let username = session?.username else {
      profile = nil
      profilePosts = []
      return
    }
    let instanceID = selectedInstanceID
    isLoadingProfile = true
    profileError = nil
    do {
      let api = try currentAPI()
      let response = try await api.profile(username: username)
      guard instanceID == selectedInstanceID else { return }
      profile = UserProfile(apiUser: response.profile, api: api)
      profilePosts = response.posts.map { Post(apiPost: $0, api: api) }
    } catch is CancellationError {
      if instanceID == selectedInstanceID { isLoadingProfile = false }
      return
    } catch {
      guard instanceID == selectedInstanceID else { return }
      profileError = error.localizedDescription
      handleAuthenticationFailure(error)
    }
    if instanceID == selectedInstanceID { isLoadingProfile = false }
  }

  func loadProfileReplies() async {
    guard let username = session?.username else { return }
    let instanceID = selectedInstanceID
    isLoadingProfileReplies = true
    do {
      let api = try currentAPI()
      let response = try await api.profileReplies(username: username)
      guard instanceID == selectedInstanceID else { return }
      profileReplies = response.map { Post(apiPost: $0, api: api) }
    } catch is CancellationError {
      if instanceID == selectedInstanceID { isLoadingProfileReplies = false }
      return
    } catch {
      guard instanceID == selectedInstanceID else { return }
      profileError = error.localizedDescription
      handleAuthenticationFailure(error)
    }
    if instanceID == selectedInstanceID { isLoadingProfileReplies = false }
  }

  func loadNotifications() async {
    guard isSignedIn else {
      notifications = []
      return
    }
    let instanceID = selectedInstanceID
    isLoadingNotifications = true
    notificationError = nil
    do {
      let api = try currentAPI()
      let response = try await api.notifications()
      guard instanceID == selectedInstanceID else { return }
      notifications = response.map { TweetaNotification(apiNotification: $0, api: api) }
    } catch is CancellationError {
      if instanceID == selectedInstanceID { isLoadingNotifications = false }
      return
    } catch {
      guard instanceID == selectedInstanceID else { return }
      notificationError = error.localizedDescription
      handleAuthenticationFailure(error)
    }
    if instanceID == selectedInstanceID { isLoadingNotifications = false }
  }

  func markNotificationsRead() async {
    guard isSignedIn else { return }
    do {
      try await currentAPI().markAllNotificationsRead()
      for index in notifications.indices { notifications[index].isUnread = false }
    } catch {
      present(error)
    }
  }

  func search(_ query: String, people: Bool, sort: String = "latest") async {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      searchPosts = []
      searchUsers = []
      searchError = nil
      isSearching = false
      return
    }
    let instanceID = selectedInstanceID
    isSearching = true
    searchError = nil
    do {
      let api = try currentAPI()
      if people {
        let response = try await api.searchUsers(query)
        guard instanceID == selectedInstanceID else { return }
        searchUsers = response.map { SearchUser(apiUser: $0, api: api) }
      } else {
        let response = try await api.searchPosts(query, sort: sort)
        guard instanceID == selectedInstanceID else { return }
        searchPosts = response.map {
          Post(apiPost: $0, api: api)
        }
      }
    } catch is CancellationError {
      if instanceID == selectedInstanceID { isSearching = false }
      return
    } catch {
      guard instanceID == selectedInstanceID else { return }
      searchError = error.localizedDescription
      handleAuthenticationFailure(error)
    }
    if instanceID == selectedInstanceID { isSearching = false }
  }

  func publish(_ text: String, replyTo: String? = nil, pollOptions: [String] = []) async throws {
    guard isSignedIn else { throw APIError.message("Sign in before posting.") }
    try await currentAPI().createPost(content: text, replyTo: replyTo, pollOptions: pollOptions)
    await loadTimeline()
    if replyTo == nil { await loadProfile() }
  }

  func toggleLike(_ id: String) async {
    guard requireSignIn() else { return }
    let wasLiked = post(withID: id)?.isLiked ?? false
    mutatePost(id) {
      $0.isLiked.toggle()
      $0.likeCount += $0.isLiked ? 1 : -1
    }
    do {
      try await currentAPI().toggleLike(postID: id)
    } catch {
      mutatePost(id) {
        $0.isLiked = wasLiked
        $0.likeCount += wasLiked ? 1 : -1
      }
      present(error)
    }
  }

  func toggleBoost(_ id: String) async {
    guard requireSignIn() else { return }
    let wasBoosted = post(withID: id)?.isBoosted ?? false
    mutatePost(id) {
      $0.isBoosted.toggle()
      $0.boostCount += $0.isBoosted ? 1 : -1
    }
    do {
      try await currentAPI().toggleBoost(postID: id)
    } catch {
      mutatePost(id) {
        $0.isBoosted = wasBoosted
        $0.boostCount += wasBoosted ? 1 : -1
      }
      present(error)
    }
  }

  func toggleBookmark(_ id: String) async {
    guard requireSignIn() else { return }
    let wasBookmarked = post(withID: id)?.isBookmarked ?? false
    mutatePost(id) { $0.isBookmarked.toggle() }
    do {
      try await currentAPI().setBookmark(postID: id, bookmarked: !wasBookmarked)
    } catch {
      mutatePost(id) { $0.isBookmarked = wasBookmarked }
      present(error)
    }
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
    session = nil
    saveInstanceSettings()
    resetServerContent()
    Task { await bootstrap() }
    return instance
  }

  func selectInstance(_ id: UUID) {
    guard id != selectedInstanceID, instances.contains(where: { $0.id == id }) else { return }
    selectedInstanceID = id
    session = sessionVault.load(instanceID: id)
    saveInstanceSettings()
    resetServerContent()
    Task { await bootstrap() }
  }

  func removeInstance(_ id: UUID) throws {
    guard instances.count > 1 else { throw ServerInstanceError.lastInstance }
    guard let index = instances.firstIndex(where: { $0.id == id }) else { return }
    let wasSelected = selectedInstanceID == id
    sessionVault.delete(instanceID: id)
    instances.remove(at: index)
    if wasSelected {
      selectedInstanceID = instances[min(index, instances.count - 1)].id
      session = sessionVault.load(instanceID: selectedInstanceID)
      resetServerContent()
      Task { await bootstrap() }
    }
    saveInstanceSettings()
  }

  private func currentAPI() throws -> TweetapusAPI {
    try TweetapusAPI(instanceAddress: selectedInstance.address, token: session?.token)
  }

  private func requireSignIn() -> Bool {
    guard isSignedIn else {
      presentedError = "Sign in to interact with posts."
      return false
    }
    return true
  }

  private func post(withID id: String) -> Post? {
    (posts + searchPosts + profilePosts + profileReplies).first(where: { $0.id == id })
  }

  private func mutatePost(_ id: String, mutation: (inout Post) -> Void) {
    mutatePost(in: &posts, id: id, mutation: mutation)
    mutatePost(in: &searchPosts, id: id, mutation: mutation)
    mutatePost(in: &profilePosts, id: id, mutation: mutation)
    mutatePost(in: &profileReplies, id: id, mutation: mutation)
  }

  private func mutatePost(
    in collection: inout [Post], id: String, mutation: (inout Post) -> Void
  ) {
    guard let index = collection.firstIndex(where: { $0.id == id }) else { return }
    mutation(&collection[index])
  }

  private func present(_ error: Error) {
    presentedError = error.localizedDescription
    handleAuthenticationFailure(error)
  }

  private func handleAuthenticationFailure(_ error: Error) {
    guard let apiError = error as? APIError, apiError.isAuthenticationFailure else { return }
    sessionVault.delete(instanceID: selectedInstanceID)
    session = nil
    profile = nil
    profilePosts = []
    profileReplies = []
    notifications = []
    if timeline != .publicFeed {
      timeline = .publicFeed
      posts = []
      Task { await loadTimeline(.publicFeed) }
    }
  }

  private func resetServerContent() {
    timelineRequestID = UUID()
    posts = []
    notifications = []
    searchPosts = []
    searchUsers = []
    profile = nil
    profilePosts = []
    profileReplies = []
    isLoadingTimeline = false
    isLoadingNotifications = false
    isLoadingProfile = false
    isLoadingProfileReplies = false
    isSearching = false
    timelineError = nil
    notificationError = nil
    profileError = nil
    searchError = nil
  }

  private static func normalizedInstanceAddress(_ input: String) throws -> String {
    var address = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if !address.contains("://") { address = "https://" + address }
    guard var components = URLComponents(string: address),
      components.scheme?.lowercased() == "https",
      components.host?.isEmpty == false,
      components.user == nil,
      components.password == nil,
      components.query == nil,
      components.fragment == nil
    else { throw ServerInstanceError.invalidAddress }
    components.scheme = "https"
    components.host = components.host?.lowercased()
    while components.path.hasSuffix("/") { components.path.removeLast() }
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
}
