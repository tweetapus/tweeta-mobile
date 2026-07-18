import SwiftUI

struct ProfileView: View {
  @Environment(AppStore.self) private var store
  @State private var selectedSection = ProfileSection.posts
  @State private var isShowingSettings = false

  private enum ProfileSection: String, CaseIterable, Identifiable {
    case posts = "Posts"
    case replies = "Replies"
    case media = "Media"
    var id: Self { self }
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 14) {
        profileHeader
        stats
        profilePicker

        if selectedSection == .posts {
          ForEach(store.posts.prefix(2)) { post in
            PostCard(post: post)
          }
        } else {
          ContentUnavailableView(
            selectedSection == .replies ? "No replies yet" : "No media yet",
            systemImage: selectedSection == .replies ? "bubble.left" : "photo.on.rectangle",
            description: Text("What you share will appear here.")
          )
          .padding(.vertical, 44)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 18)
    }
    .scrollIndicators(.hidden)
    .navigationTitle("Profile")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          isShowingSettings = true
        } label: {
          Image(systemName: "gearshape")
            .font(.subheadline.weight(.semibold))
            .frame(width: 34, height: 34)
            .tweetaGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
      }
    }
    .sheet(isPresented: $isShowingSettings) {
      SettingsView()
        .environment(store)
        .presentationBackground(.ultraThinMaterial)
    }
  }

  private var profileHeader: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .bottomLeading) {
        LinearGradient(
          colors: [TweetaColors.violet.opacity(0.9), .indigo, .cyan.opacity(0.72)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .frame(height: 132)
        .overlay {
          Circle()
            .stroke(.white.opacity(0.18), lineWidth: 26)
            .frame(width: 180, height: 180)
            .offset(x: 130, y: -40)
        }

        AvatarView(initials: "L", size: 82)
          .overlay(Circle().stroke(.background, lineWidth: 4))
          .offset(x: 16, y: 41)
      }

      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Lily")
              .font(.title2.bold())
            Text("@lily")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("Edit profile") {}
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .tweetaGlass(in: Capsule(), interactive: true)
        }

        Text("Building thoughtful software and collecting small wonders along the way.")
          .font(.subheadline)
          .lineSpacing(2)
          .padding(.top, 5)

        HStack(spacing: 12) {
          Label("Melbourne", systemImage: "mappin.and.ellipse")
          Label("Joined 2026", systemImage: "calendar")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 3)
      }
      .padding(.horizontal, 16)
      .padding(.top, 50)
      .padding(.bottom, 16)
    }
    .clipShape(RoundedRectangle(cornerRadius: 27, style: .continuous))
    .tweetaGlass(in: RoundedRectangle(cornerRadius: 27, style: .continuous))
  }

  private var stats: some View {
    HStack {
      stat(value: "248", label: "Following")
      Divider().frame(height: 28)
      stat(value: "1.8K", label: "Followers")
      Divider().frame(height: 28)
      stat(value: "612", label: "Posts")
    }
    .padding(.vertical, 13)
    .tweetaGlass(in: RoundedRectangle(cornerRadius: 21, style: .continuous))
  }

  private func stat(value: String, label: String) -> some View {
    VStack(spacing: 2) {
      Text(value).font(.headline)
      Text(label).font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private var profilePicker: some View {
    HStack(spacing: 4) {
      ForEach(ProfileSection.allCases) { section in
        Button {
          withAnimation(.snappy) { selectedSection = section }
        } label: {
          Text(section.rawValue)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selectedSection == section ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
              if selectedSection == section {
                Capsule().fill(TweetaColors.lavender.opacity(0.2))
              }
            }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
    .tweetaGlass(in: Capsule(), interactive: true)
  }
}

private struct SettingsView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    @Bindable var store = store

    NavigationStack {
      List {
        Section("Appearance") {
          Toggle(isOn: $store.isDarkMode) {
            Label("Dark appearance", systemImage: "moon.stars")
          }
          Label("Liquid Glass", systemImage: "drop")
            .badge("On")
        }

        Section("Account") {
          Label("Privacy and safety", systemImage: "hand.raised")
          Label("Notifications", systemImage: "bell")
          Label("Bookmarks", systemImage: "bookmark")
          Label("Server instance", systemImage: "network")
        }

        Section {
          Label("About Tweeta", systemImage: "info.circle")
          Label("Help", systemImage: "questionmark.circle")
        }
      }
      .scrollContentBackground(.hidden)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}
