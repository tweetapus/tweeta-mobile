import SwiftUI

struct HomeView: View {
  @Environment(AppStore.self) private var store

  private var visiblePosts: [Post] {
    switch store.timeline {
    case .publicFeed: store.posts
    case .following: Array(store.posts.prefix(2))
    case .forYou: store.posts
    }
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 14) {
        timelinePicker

        if store.timeline == .forYou {
          conversationStarter
        }

        ForEach(visiblePosts) { post in
          PostCard(post: post)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 6)
      .padding(.bottom, 18)
    }
    .scrollIndicators(.hidden)
    .refreshable {
      try? await Task.sleep(for: .milliseconds(650))
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
  }

  private var timelinePicker: some View {
    GlassGroup {
      HStack(spacing: 4) {
        ForEach(Timeline.allCases) { timeline in
          Button {
            withAnimation(.snappy) { store.timeline = timeline }
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

  private var conversationStarter: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(TweetaColors.lavender.opacity(0.15))
          .frame(width: 42, height: 42)
        Image(systemName: "sparkles")
          .foregroundStyle(TweetaColors.lavender)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text("A gentler timeline")
          .font(.subheadline.bold())
        Text("Thoughtful posts picked for you")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.bold())
        .foregroundStyle(.tertiary)
    }
    .padding(14)
    .tweetaGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}

struct PostCard: View {
  @Environment(AppStore.self) private var store
  let post: Post
  @State private var isShowingReply = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 11) {
        AvatarView(initials: post.avatar, size: 44)

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

        Menu {
          Button("Not interested", systemImage: "hand.thumbsdown") {}
          Button("Mute @\(post.handle)", systemImage: "speaker.slash") {}
          Button("Report", systemImage: "exclamationmark.bubble", role: .destructive) {}
        } label: {
          Image(systemName: "ellipsis")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
        }
        .accessibilityLabel("More actions for \(post.author)")
      }

      Text(post.body)
        .font(.body)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)

      if let media = post.media {
        PostMediaView(kind: media)
      }

      HStack(spacing: 0) {
        PostActionButton(
          symbol: "bubble.left", count: post.replyCount,
          tint: .secondary, isActive: false
        ) { isShowingReply = true }

        PostActionButton(
          symbol: "arrow.2.squarepath", count: post.boostCount,
          tint: .mint, isActive: post.isBoosted
        ) { withAnimation(.bouncy) { store.toggleBoost(post.id) } }

        PostActionButton(
          symbol: post.isLiked ? "heart.fill" : "heart", count: post.likeCount,
          tint: .pink, isActive: post.isLiked
        ) { withAnimation(.bouncy) { store.toggleLike(post.id) } }

        Button {
          withAnimation(.snappy) { store.toggleBookmark(post.id) }
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
        .presentationDetents([.height(330)])
        .presentationBackground(.ultraThinMaterial)
    }
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

private struct PostMediaView: View {
  let kind: Post.Media

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      switch kind {
      case .aurora:
        LinearGradient(
          colors: [.indigo, .purple, .cyan.opacity(0.8), .black],
          startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
          Circle().fill(.white.opacity(0.2)).frame(width: 130).blur(radius: 30).offset(
            x: 20, y: -40)
        }
      case .city:
        LinearGradient(
          colors: [.indigo.opacity(0.75), .pink.opacity(0.6), .orange.opacity(0.7)],
          startPoint: .top, endPoint: .bottom
        )
        .overlay(alignment: .bottom) {
          HStack(alignment: .bottom, spacing: 6) {
            ForEach([0.42, 0.7, 0.54, 0.88, 0.5, 0.64], id: \.self) { scale in
              RoundedRectangle(cornerRadius: 3)
                .fill(.black.opacity(0.56))
                .frame(height: 130 * scale)
            }
          }
          .padding(.horizontal, 20)
        }
      case .ocean:
        LinearGradient(
          colors: [.cyan.opacity(0.7), .blue, .indigo], startPoint: .top, endPoint: .bottom
        )
        .overlay {
          ForEach(0..<4) { index in
            Capsule()
              .stroke(.white.opacity(0.22), lineWidth: 2)
              .frame(width: 270, height: 36)
              .offset(y: CGFloat(index * 30 - 45))
          }
        }
      }

      Label(mediaLabel, systemImage: "camera.fill")
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(10)
    }
    .frame(height: 205)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.14)))
    .accessibilityLabel(mediaLabel)
  }

  private var mediaLabel: String {
    switch kind {
    case .aurora: "Aurora lights"
    case .city: "Melbourne skyline"
    case .ocean: "Ocean waves"
    }
  }
}

private struct QuickReplyView: View {
  @Environment(\.dismiss) private var dismiss
  let post: Post
  @State private var reply = ""

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 10) {
          AvatarView(initials: post.avatar, size: 34)
          Text("Replying to **@\(post.handle)**")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        TextField("Write a reply…", text: $reply, axis: .vertical)
          .lineLimit(4...7)
          .padding(14)
          .tweetaGlass(in: RoundedRectangle(cornerRadius: 18), interactive: true)
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
          Button("Reply") { dismiss() }
            .fontWeight(.semibold)
            .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
