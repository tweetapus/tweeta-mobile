import SwiftUI

struct SearchView: View {
  @Environment(AppStore.self) private var store
  @State private var query = ""
  @State private var scope = SearchScope.top

  private enum SearchScope: String, CaseIterable, Identifiable {
    case top = "Top"
    case latest = "Latest"
    case people = "People"
    var id: Self { self }
  }

  private var matchingPosts: [Post] {
    guard !query.isEmpty else { return store.posts }
    return store.posts.filter {
      $0.body.localizedCaseInsensitiveContains(query)
        || $0.author.localizedCaseInsensitiveContains(query)
        || $0.handle.localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        scopePicker

        if query.isEmpty {
          trendingContent
        } else if scope == .people {
          peopleResults
        } else if matchingPosts.isEmpty {
          ContentUnavailableView.search(text: query)
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
        } else {
          Text("Results")
            .font(.headline)
            .padding(.horizontal, 2)
          ForEach(matchingPosts) { post in
            PostCard(post: post)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 18)
    }
    .scrollDismissesKeyboard(.interactively)
    .scrollIndicators(.hidden)
    .navigationTitle("Discover")
    .navigationBarTitleDisplayMode(.large)
    .toolbarBackground(.hidden, for: .navigationBar)
    .searchable(text: $query, prompt: "People, posts, and topics")
  }

  private var scopePicker: some View {
    HStack(spacing: 4) {
      ForEach(SearchScope.allCases) { item in
        Button {
          withAnimation(.snappy) { scope = item }
        } label: {
          Text(item.rawValue)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
              if scope == item {
                Capsule().fill(TweetaColors.lavender.opacity(0.2))
              }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(scope == item ? .primary : .secondary)
      }
    }
    .padding(4)
    .tweetaGlass(in: Capsule(), interactive: true)
  }

  private var trendingContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      SectionTitle("Happening now", eyebrow: "Explore")

      VStack(spacing: 10) {
        TrendCard(
          category: "Design · Trending", title: "Liquid Glass",
          count: "8,420 posts", symbol: "drop.fill",
          colors: [TweetaColors.lavender, .blue]
        )
        TrendCard(
          category: "Technology · Australia", title: "Indie apps",
          count: "3,106 posts", symbol: "hammer.fill",
          colors: [.orange, .pink]
        )
        TrendCard(
          category: "Photography", title: "Winter light",
          count: "1,944 posts", symbol: "camera.fill",
          colors: [.cyan, .indigo]
        )
      }

      SectionTitle("People worth knowing", eyebrow: "For you")

      VStack(spacing: 10) {
        PersonRow(
          name: "Maya Chen", handle: "mayamakes", initials: "MC",
          bio: "Objects, interfaces, tiny joys")
        PersonRow(
          name: "Noor", handle: "noor.codes", initials: "N", bio: "iOS, photos, and good coffee")
        PersonRow(
          name: "Theo Martin", handle: "theom", initials: "TM",
          bio: "Thinking about kinder networks")
      }
    }
  }

  private var peopleResults: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("People")
        .font(.headline)
        .padding(.horizontal, 2)
      ForEach(
        people.filter {
          query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
            || $0.handle.localizedCaseInsensitiveContains(query)
        }, id: \.handle
      ) { person in
        PersonRow(
          name: person.name, handle: person.handle, initials: person.initials, bio: person.bio)
      }
    }
  }

  private let people = [
    (name: "Maya Chen", handle: "mayamakes", initials: "MC", bio: "Objects, interfaces, tiny joys"),
    (name: "Noor", handle: "noor.codes", initials: "N", bio: "iOS, photos, and good coffee"),
    (name: "Theo Martin", handle: "theom", initials: "TM", bio: "Thinking about kinder networks"),
  ]
}

private struct TrendCard: View {
  let category: String
  let title: String
  let count: String
  let symbol: String
  let colors: [Color]

  var body: some View {
    Button {
    } label: {
      HStack(spacing: 13) {
        ZStack {
          RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(
              LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
          Image(systemName: symbol)
            .font(.title3.bold())
            .foregroundStyle(.white)
        }
        .frame(width: 52, height: 52)

        VStack(alignment: .leading, spacing: 3) {
          Text(category)
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(title)
            .font(.headline)
          Text(count)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.bold())
          .foregroundStyle(.tertiary)
      }
      .padding(12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .tweetaGlass(in: RoundedRectangle(cornerRadius: 21, style: .continuous), interactive: true)
  }
}

private struct PersonRow: View {
  let name: String
  let handle: String
  let initials: String
  let bio: String
  @State private var isFollowing = false

  var body: some View {
    HStack(spacing: 12) {
      AvatarView(initials: initials, size: 48)
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(.subheadline.bold())
        Text("@\(handle)").font(.caption).foregroundStyle(.secondary)
        Text(bio).font(.caption).lineLimit(1)
      }
      Spacer(minLength: 6)
      Button(isFollowing ? "Following" : "Follow") {
        withAnimation(.snappy) { isFollowing.toggle() }
      }
      .font(.caption.bold())
      .foregroundStyle(isFollowing ? Color.primary : Color.white)
      .padding(.horizontal, 13)
      .padding(.vertical, 9)
      .background(isFollowing ? Color.clear : TweetaColors.violet, in: Capsule())
      .tweetaGlass(in: Capsule(), interactive: true)
    }
    .padding(13)
    .tweetaGlass(in: RoundedRectangle(cornerRadius: 21, style: .continuous))
  }
}
