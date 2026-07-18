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
          NavigationLink {
            InstanceSettingsView()
          } label: {
            Label {
              HStack {
                Text("Server instance")
                Spacer()
                Text(store.selectedInstance.host)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            } icon: {
              Image(systemName: "network")
            }
          }
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

private struct InstanceSettingsView: View {
  @Environment(AppStore.self) private var store
  @State private var isAddingInstance = false
  @State private var removalError: String?

  var body: some View {
    List {
      Section {
        ForEach(store.instances) { instance in
          Button {
            withAnimation(.snappy) {
              store.selectInstance(instance.id)
            }
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "server.rack")
                .foregroundStyle(
                  instance.id == store.selectedInstanceID ? TweetaColors.lavender : .secondary)
                .frame(width: 24)

              VStack(alignment: .leading, spacing: 3) {
                Text(instance.host)
                  .foregroundStyle(.primary)
                Text(instance.address)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }

              Spacer()

              if instance.id == store.selectedInstanceID {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(TweetaColors.lavender)
                  .accessibilityLabel("Selected")
              }
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
        .onDelete(perform: removeInstances)
        .deleteDisabled(store.instances.count == 1)
      } header: {
        Text("Instances")
      } footer: {
        Text("Tap an instance to switch. Only HTTPS servers can be added.")
      }
    }
    .scrollContentBackground(.hidden)
    .navigationTitle("Server instances")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        EditButton()
        Button {
          isAddingInstance = true
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel("Add instance")
      }
    }
    .sheet(isPresented: $isAddingInstance) {
      AddInstanceView()
        .environment(store)
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
    }
    .alert("Couldn’t remove instance", isPresented: removalAlertIsPresented) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(removalError ?? "Please try again.")
    }
  }

  private var removalAlertIsPresented: Binding<Bool> {
    Binding(
      get: { removalError != nil },
      set: { if !$0 { removalError = nil } }
    )
  }

  private func removeInstances(at offsets: IndexSet) {
    for offset in offsets.sorted(by: >) {
      do {
        try store.removeInstance(store.instances[offset].id)
      } catch {
        removalError = error.localizedDescription
      }
    }
  }
}

private struct AddInstanceView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var address = ""
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("example.org", text: $address)
            .textContentType(.URL)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit(addInstance)
        } header: {
          Text("Server address")
        } footer: {
          Text("HTTPS is added automatically when no scheme is provided.")
        }

        if let errorMessage {
          Section {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.red)
          }
        }
      }
      .scrollContentBackground(.hidden)
      .navigationTitle("Add instance")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Add", action: addInstance)
            .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }

  private func addInstance() {
    do {
      try store.addInstance(address)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
