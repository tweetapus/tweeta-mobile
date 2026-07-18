import SwiftUI

struct RootView: View {
  @Environment(AppStore.self) private var store
  @State private var isComposing = false
  @State private var isShowingSignIn = false

  var body: some View {
    ZStack {
      AmbientBackground()

      Group {
        switch store.selectedTab {
        case .home:
          NavigationStack { HomeView() }
        case .search:
          NavigationStack { SearchView() }
        case .alerts:
          NavigationStack { NotificationsView() }
        case .profile:
          NavigationStack { ProfileView() }
        }
      }
      .transition(.opacity.combined(with: .scale(scale: 0.99)))
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      GlassTabBar(isComposing: $isComposing, isShowingSignIn: $isShowingSignIn)
        .padding(.horizontal, 18)
        .padding(.bottom, 7)
    }
    .sheet(isPresented: $isComposing) {
      ComposeView()
        .environment(store)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
    }
    .sheet(isPresented: $isShowingSignIn) {
      SignInView()
        .environment(store)
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
    .alert("Tweeta", isPresented: presentedErrorIsVisible) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(store.presentedError ?? "Something went wrong.")
    }
    .task { await store.bootstrap() }
  }

  private var presentedErrorIsVisible: Binding<Bool> {
    Binding(
      get: { store.presentedError != nil },
      set: { if !$0 { store.presentedError = nil } }
    )
  }
}

private struct GlassTabBar: View {
  @Environment(AppStore.self) private var store
  @Binding var isComposing: Bool
  @Binding var isShowingSignIn: Bool
  @Namespace private var selectionNamespace

  private let tabs: [(AppTab, String, String)] = [
    (.home, "house", "Home"),
    (.search, "magnifyingglass", "Search"),
    (.alerts, "bell", "Notifications"),
    (.profile, "person", "Profile"),
  ]

  var body: some View {
    GlassGroup {
      HStack(spacing: 3) {
        tabButton(tabs[0])
        tabButton(tabs[1])

        Button {
          if store.isSignedIn {
            isComposing = true
          } else {
            isShowingSignIn = true
          }
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(
              LinearGradient(
                colors: [TweetaColors.lavender, TweetaColors.violet],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              in: Circle()
            )
            .shadow(color: TweetaColors.violet.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .tweetaGlass(in: Circle(), interactive: true)
        .accessibilityLabel("Create post")

        tabButton(tabs[2])
        tabButton(tabs[3])
      }
      .padding(6)
      .tweetaGlass(in: Capsule(), interactive: true)
    }
  }

  private func tabButton(_ item: (AppTab, String, String)) -> some View {
    let isSelected = store.selectedTab == item.0
    let selectedSymbol = item.0 == .search ? item.1 : item.1 + ".fill"
    return Button {
      withAnimation(.snappy(duration: 0.28)) {
        store.selectedTab = item.0
      }
    } label: {
      ZStack {
        if isSelected {
          Capsule()
            .fill(TweetaColors.lavender.opacity(0.18))
            .matchedGeometryEffect(id: "selectedTab", in: selectionNamespace)
        }

        Image(systemName: isSelected ? selectedSymbol : item.1)
          .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
          .foregroundStyle(isSelected ? TweetaColors.lavender : .secondary)
          .symbolEffect(.bounce, value: isSelected)
          .overlay(alignment: .topTrailing) {
            if item.0 == .alerts && store.unreadCount > 0 {
              Circle()
                .fill(.pink)
                .frame(width: 7, height: 7)
                .overlay(Circle().stroke(.background, lineWidth: 1.5))
                .offset(x: 4, y: -3)
            }
          }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(item.2)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
