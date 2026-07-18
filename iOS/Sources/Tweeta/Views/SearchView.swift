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

  private var searchID: String { "\(scope.rawValue):\(query)" }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        scopePicker

        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          ContentUnavailableView(
            "Search Tweetapus", systemImage: "magnifyingglass",
            description: Text("Find public posts and people on \(store.selectedInstance.host)."))
          .frame(maxWidth: .infinity)
          .padding(.top, 70)
        } else if store.isSearching {
          ProgressView("Searching…")
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
        } else if let error = store.searchError {
          ContentUnavailableView(
            "Search unavailable", systemImage: "wifi.exclamationmark", description: Text(error))
          .frame(maxWidth: .infinity)
          .padding(.top, 55)
        } else if scope == .people {
          peopleResults
        } else if store.searchPosts.isEmpty {
          ContentUnavailableView.search(text: query)
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
        } else {
          Text("Results")
            .font(.headline)
            .padding(.horizontal, 2)
          ForEach(store.searchPosts) { post in
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
    .task(id: searchID) {
      do {
        try await Task.sleep(for: .milliseconds(350))
        await store.search(
          query, people: scope == .people, sort: scope == .top ? "top" : "latest")
      } catch {}
    }
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
              if scope == item { Capsule().fill(TweetaColors.lavender.opacity(0.2)) }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(scope == item ? .primary : .secondary)
      }
    }
    .padding(4)
    .tweetaGlass(in: Capsule(), interactive: true)
  }

  private var peopleResults: some View {
    VStack(alignment: .leading, spacing: 10) {
      if store.searchUsers.isEmpty {
        ContentUnavailableView.search(text: query)
          .frame(maxWidth: .infinity)
          .padding(.top, 55)
      } else {
        Text("People")
          .font(.headline)
          .padding(.horizontal, 2)
        ForEach(store.searchUsers) { person in
          PersonRow(person: person)
        }
      }
    }
  }
}

private struct PersonRow: View {
  let person: SearchUser

  var body: some View {
    HStack(spacing: 12) {
      AvatarView(initials: person.initials, size: 48, imageURL: person.avatarURL)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text(person.name).font(.subheadline.bold())
          if person.verified {
            Image(systemName: "checkmark.seal.fill")
              .font(.caption)
              .foregroundStyle(TweetaColors.lavender)
          }
        }
        Text("@\(person.username)").font(.caption).foregroundStyle(.secondary)
        if !person.bio.isEmpty {
          Text(person.bio).font(.caption).lineLimit(2)
        }
        Text("\(person.followerCount.formatted()) followers")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 6)
    }
    .padding(13)
    .tweetaGlass(in: RoundedRectangle(cornerRadius: 21, style: .continuous))
  }
}
