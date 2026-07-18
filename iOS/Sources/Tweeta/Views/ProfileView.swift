import SwiftUI

struct ProfileView: View {
  @Environment(AppStore.self) private var store
  @State private var selectedSection = ProfileSection.posts
  @State private var isShowingSettings = false
  @State private var isShowingSignIn = false

  private enum ProfileSection: String, CaseIterable, Identifiable {
    case posts = "Posts"
    case replies = "Replies"
    case media = "Media"
    var id: Self { self }
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 14) {
        if !store.isSignedIn {
          ContentUnavailableView {
            Label("Sign in to your profile", systemImage: "person.crop.circle")
          } description: {
            Text("Your profile is private to your account on \(store.selectedInstance.host).")
          } actions: {
            Button("Sign in") { isShowingSignIn = true }
              .buttonStyle(.borderedProminent)
          }
          .padding(.top, 80)
        } else if store.isLoadingProfile && store.profile == nil {
          ProgressView("Loading profile…")
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        } else if let error = store.profileError, store.profile == nil {
          ContentUnavailableView(
            "Profile unavailable", systemImage: "wifi.exclamationmark", description: Text(error))
          .padding(.top, 60)
        } else if store.profile != nil {
          profileHeader
          stats
          profilePicker
          selectedContent
        } else {
          ContentUnavailableView("Profile unavailable", systemImage: "person.crop.circle.badge.xmark")
            .padding(.top, 60)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 18)
    }
    .scrollIndicators(.hidden)
    .refreshable { await store.loadProfile() }
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
    .sheet(isPresented: $isShowingSignIn) {
      SignInView().environment(store)
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
    .task {
      if store.isSignedIn && store.profile == nil { await store.loadProfile() }
    }
  }

  @ViewBuilder
  private var selectedContent: some View {
    let selectedPosts: [Post] = {
      switch selectedSection {
      case .posts: store.profilePosts
      case .replies: store.profileReplies
      case .media: store.profilePosts.filter { !$0.attachments.isEmpty }
      }
    }()
    if selectedSection == .replies && store.isLoadingProfileReplies && selectedPosts.isEmpty {
      ProgressView("Loading replies…")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 55)
    } else if selectedPosts.isEmpty {
      ContentUnavailableView(
        selectedSection == .replies ? "No replies yet"
          : selectedSection == .media ? "No media yet" : "No posts yet",
        systemImage: selectedSection == .replies ? "bubble.left"
          : selectedSection == .media ? "photo.on.rectangle" : "text.bubble",
        description: Text("Activity from this account will appear here."))
      .padding(.vertical, 44)
    } else {
      ForEach(selectedPosts) { post in PostCard(post: post) }
    }
  }

  private var profileHeader: some View {
    let profile = store.profile!
    return VStack(spacing: 0) {
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

        if let bannerURL = profile.bannerURL {
          AsyncImage(url: bannerURL) { phase in
            if case .success(let image) = phase { image.resizable().scaledToFill() }
          }
          .frame(height: 132)
          .clipped()
        }

        AvatarView(initials: profile.initials, size: 82, imageURL: profile.avatarURL)
          .overlay(Circle().stroke(.background, lineWidth: 4))
          .offset(x: 16, y: 41)
      }

      VStack(alignment: .leading, spacing: 5) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
              Text(profile.name)
              if profile.verified {
                Image(systemName: "checkmark.seal.fill")
                  .foregroundStyle(TweetaColors.lavender)
              }
            }
              .font(.title2.bold())
            Text("@\(profile.username)")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Spacer()
        }

        if !profile.bio.isEmpty {
          Text(profile.bio)
            .font(.subheadline)
            .lineSpacing(2)
            .padding(.top, 5)
        }

        HStack(spacing: 12) {
          if !profile.location.isEmpty {
            Label(profile.location, systemImage: "mappin.and.ellipse")
          }
          if let joinedAt = profile.joinedAt {
            Label(
              "Joined \(joinedAt.formatted(.dateTime.month(.abbreviated).year()))",
              systemImage: "calendar")
          }
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
    let profile = store.profile!
    return HStack {
      stat(value: profile.followingCount.formatted(.number.notation(.compactName)), label: "Following")
      Divider().frame(height: 28)
      stat(value: profile.followerCount.formatted(.number.notation(.compactName)), label: "Followers")
      Divider().frame(height: 28)
      stat(value: profile.postCount.formatted(.number.notation(.compactName)), label: "Posts")
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
          if section == .replies && store.profileReplies.isEmpty {
            Task { await store.loadProfileReplies() }
          }
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
  @State private var isShowingSignIn = false

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
          if let session = store.session {
            Label {
              VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                Text("@\(session.username)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            } icon: {
              Image(systemName: "person.crop.circle.fill")
            }
            Button(role: .destructive) {
              store.signOut()
            } label: {
              Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
          } else {
            Button {
              isShowingSignIn = true
            } label: {
              Label("Sign in", systemImage: "person.crop.circle.badge.checkmark")
            }
          }
        }

        Section("Connection") {
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
      }
      .scrollContentBackground(.hidden)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
      .sheet(isPresented: $isShowingSignIn) {
        SignInView().environment(store)
          .presentationDetents([.medium, .large])
          .presentationBackground(.ultraThinMaterial)
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
        Text(
          "Tap an instance to switch. Accounts are stored separately for each HTTPS server.")
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
