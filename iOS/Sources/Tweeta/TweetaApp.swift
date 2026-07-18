import SwiftUI

@main
struct TweetaApp: App {
  @State private var store = AppStore()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(store)
        .preferredColorScheme(store.colorScheme)
    }
  }
}
