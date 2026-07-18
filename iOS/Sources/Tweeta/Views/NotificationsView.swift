import SwiftUI

struct NotificationsView: View {
  @Environment(AppStore.self) private var store
  @State private var filter = NotificationFilter.all
  @State private var isShowingSignIn = false

  private enum NotificationFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case mentions = "Mentions"
    var id: Self { self }
  }

  private var visibleNotifications: [TweetaNotification] {
    if filter == .all { return store.notifications }
    return store.notifications.filter { $0.kind == .replied || $0.kind == .mentioned }
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        if !store.isSignedIn {
          ContentUnavailableView {
            Label("Sign in for notifications", systemImage: "bell")
          } description: {
            Text("Notifications are private to your account.")
          } actions: {
            Button("Sign in") { isShowingSignIn = true }
              .buttonStyle(.borderedProminent)
          }
          .padding(.top, 70)
        } else {
          filterPicker

          if store.isLoadingNotifications && store.notifications.isEmpty {
            ProgressView("Loading notifications…")
              .frame(maxWidth: .infinity)
              .padding(.top, 60)
          } else if let error = store.notificationError, store.notifications.isEmpty {
            ContentUnavailableView(
              "Notifications unavailable", systemImage: "wifi.exclamationmark",
              description: Text(error))
            .padding(.top, 50)
          } else if visibleNotifications.isEmpty {
            ContentUnavailableView(
              "No notifications", systemImage: "bell.slash",
              description: Text("New activity will appear here."))
            .padding(.top, 50)
          } else {
            ForEach(visibleNotifications) { notification in
              NotificationRow(notification: notification)
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 18)
    }
    .scrollIndicators(.hidden)
    .refreshable { await store.loadNotifications() }
    .navigationTitle("Notifications")
    .navigationBarTitleDisplayMode(.large)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if store.unreadCount > 0 {
          Button("Mark read") {
            Task { await store.markNotificationsRead() }
          }
          .font(.subheadline.weight(.semibold))
        }
      }
    }
    .sheet(isPresented: $isShowingSignIn) {
      SignInView().environment(store)
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
    .task {
      if store.isSignedIn && store.notifications.isEmpty {
        await store.loadNotifications()
      }
    }
  }

  private var filterPicker: some View {
    HStack(spacing: 4) {
      ForEach(NotificationFilter.allCases) { item in
        Button {
          withAnimation(.snappy) { filter = item }
        } label: {
          Text(item.rawValue)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
              if filter == item { Capsule().fill(TweetaColors.lavender.opacity(0.2)) }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(filter == item ? .primary : .secondary)
      }
    }
    .padding(4)
    .tweetaGlass(in: Capsule(), interactive: true)
  }
}

private struct NotificationRow: View {
  let notification: TweetaNotification

  private var tint: Color {
    switch notification.kind {
    case .liked: .pink
    case .boosted: .mint
    case .followed: TweetaColors.lavender
    case .replied: .blue
    case .mentioned: .orange
    case .other: .secondary
    }
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack(alignment: .bottomTrailing) {
        AvatarView(
          initials: notification.avatar, size: 46, imageURL: notification.avatarURL)
        Circle()
          .fill(tint)
          .frame(width: 23, height: 23)
          .overlay {
            Image(systemName: notification.kind.symbol)
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(.white)
          }
          .overlay(Circle().stroke(.background, lineWidth: 2))
          .offset(x: 3, y: 3)
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline) {
          Text(notification.title)
            .font(.subheadline.weight(notification.isUnread ? .bold : .semibold))
          Spacer()
          Text(notification.time)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        if !notification.detail.isEmpty {
          Text(notification.detail)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      if notification.isUnread {
        Circle()
          .fill(TweetaColors.lavender)
          .frame(width: 8, height: 8)
          .padding(.top, 6)
          .accessibilityLabel("Unread")
      }
    }
    .padding(14)
    .tweetaGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true)
  }
}
