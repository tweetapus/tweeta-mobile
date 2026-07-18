import SwiftUI

struct HomeView: View {
  @Environment(AppStore.self) private var store
  @State private var isShowingSignIn = false

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 14) {
        timelinePicker

        if store.isLoadingTimeline && store.posts.isEmpty {
          ProgressView("Loading \(store.timeline.rawValue.lowercased()) timeline…")
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
        } else if let error = store.timelineError, store.posts.isEmpty {
          ContentUnavailableView(
            "Timeline unavailable", systemImage: "wifi.exclamationmark",
            description: Text(error)
          )
          .padding(.top, 45)
        } else if store.posts.isEmpty {
          ContentUnavailableView(
            "No posts yet", systemImage: "text.bubble",
            description: Text("Pull to refresh or try another timeline."))
          .padding(.top, 45)
        } else {
          ForEach(store.posts) { post in
            PostCard(post: post)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 6)
      .padding(.bottom, 18)
    }
    .scrollIndicators(.hidden)
    .refreshable {
      await store.loadTimeline()
    }
    .navigationTitle("Tweeta")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        BirdMark()
          .fill(TweetaColors.lavender)
          .frame(width: 29, height: 29)
          .accessibilityLabel("Tweeta")
      }

      ToolbarItem(placement: .principal) {
        Text("Tweeta")
          .font(.headline.weight(.bold))
      }

      ToolbarItem(placement: .topBarTrailing) {
        Button {
          store.isDarkMode.toggle()
        } label: {
          Image(systemName: store.isDarkMode ? "sun.max" : "moon")
            .font(.subheadline.weight(.semibold))
            .frame(width: 34, height: 34)
            .tweetaGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.isDarkMode ? "Use light appearance" : "Use dark appearance")
      }
    }
    .sheet(isPresented: $isShowingSignIn) {
      SignInView().environment(store)
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
  }

  private var timelinePicker: some View {
    GlassGroup {
      HStack(spacing: 4) {
        ForEach(Timeline.allCases) { timeline in
          Button {
            if timeline == .publicFeed || store.isSignedIn {
              Task { await store.loadTimeline(timeline) }
            } else {
              isShowingSignIn = true
            }
          } label: {
            Text(timeline.rawValue)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(store.timeline == timeline ? .primary : .secondary)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background {
                if store.timeline == timeline {
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
    .padding(.bottom, 2)
  }

}

struct PostCard: View {
  @Environment(AppStore.self) private var store
  let post: Post
  @State private var isShowingReply = false
  @State private var isShowingSignIn = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 11) {
        AvatarView(initials: post.avatar, size: 44, imageURL: post.avatarURL)

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 4) {
            Text(post.author)
              .font(.subheadline.bold())
              .lineLimit(1)
            if post.verified {
              Image(systemName: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(TweetaColors.lavender)
                .accessibilityLabel("Verified")
            }
          }
          Text("@\(post.handle) · \(post.timestamp)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 4)
      }

      Text(post.body)
        .font(.body)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)

      if let attachment = post.attachments.first {
        PostAttachmentView(attachment: attachment)
      }

      HStack(spacing: 0) {
        PostActionButton(
          symbol: "bubble.left", count: post.replyCount,
          tint: .secondary, isActive: false
        ) { authenticate { isShowingReply = true } }

        PostActionButton(
          symbol: "arrow.2.squarepath", count: post.boostCount,
          tint: .mint, isActive: post.isBoosted
        ) { authenticate { Task { await store.toggleBoost(post.id) } } }

        PostActionButton(
          symbol: post.isLiked ? "heart.fill" : "heart", count: post.likeCount,
          tint: .pink, isActive: post.isLiked
        ) { authenticate { Task { await store.toggleLike(post.id) } } }

        Button {
          authenticate { Task { await store.toggleBookmark(post.id) } }
        } label: {
          Image(systemName: post.isBookmarked ? "bookmark.fill" : "bookmark")
            .foregroundStyle(post.isBookmarked ? TweetaColors.lavender : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(post.isBookmarked ? "Remove bookmark" : "Bookmark")

        ShareLink(item: post.body) {
          Image(systemName: "square.and.arrow.up")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
        }
        .accessibilityLabel("Share post")
      }
      .font(.subheadline)
    }
    .padding(15)
    .tweetaGlass(in: RoundedRectangle(cornerRadius: 25, style: .continuous), interactive: true)
    .sheet(isPresented: $isShowingReply) {
      QuickReplyView(post: post)
        .environment(store)
        .presentationDetents([.height(330)])
        .presentationBackground(.ultraThinMaterial)
    }
    .sheet(isPresented: $isShowingSignIn) {
      SignInView().environment(store)
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }
  }

  private func authenticate(_ action: () -> Void) {
    if store.isSignedIn { action() } else { isShowingSignIn = true }
  }
}

private struct PostActionButton: View {
  let symbol: String
  let count: Int
  let tint: Color
  let isActive: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: symbol)
        Text(count.formatted(.number.notation(.compactName)))
          .font(.caption)
      }
      .foregroundStyle(isActive ? tint : .secondary)
      .frame(maxWidth: .infinity)
      .frame(height: 34)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct PostAttachmentView: View {
  let attachment: Post.Attachment

  var body: some View {
    Group {
      if attachment.isImage {
        AsyncImage(url: attachment.url) { phase in
          switch phase {
          case .empty:
            ZStack {
              Color.secondary.opacity(0.08)
              ProgressView()
            }
          case .success(let image):
            image.resizable().scaledToFill()
          case .failure:
            ContentUnavailableView("Image unavailable", systemImage: "photo")
          @unknown default:
            EmptyView()
          }
        }
      } else {
        Link(destination: attachment.url) {
          VStack(spacing: 10) {
            Image(systemName: "play.rectangle.fill").font(.largeTitle)
            Text("Open attachment").font(.subheadline.bold())
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(TweetaColors.violet.opacity(0.12))
        }
      }
    }
    .frame(height: 205)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14)))
  }
}

private struct QuickReplyView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let post: Post
  @State private var reply = ""
  @State private var isSending = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 10) {
          AvatarView(initials: post.avatar, size: 34, imageURL: post.avatarURL)
          Text("Replying to **@\(post.handle)**")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        TextField("Write a reply…", text: $reply, axis: .vertical)
          .lineLimit(4...7)
          .padding(14)
          .tweetaGlass(in: RoundedRectangle(cornerRadius: 18), interactive: true)
        if let errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
        }
        Spacer()
      }
      .padding()
      .navigationTitle("Reply")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Reply") { sendReply() }
            .fontWeight(.semibold)
            .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
      }
    }
  }

  private func sendReply() {
    isSending = true
    errorMessage = nil
    Task {
      do {
        try await store.publish(
          reply.trimmingCharacters(in: .whitespacesAndNewlines), replyTo: post.id)
        dismiss()
      } catch {
        errorMessage = error.localizedDescription
        isSending = false
      }
    }
  }
}
