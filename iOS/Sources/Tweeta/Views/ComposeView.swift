import SwiftUI

struct ComposeView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @FocusState private var isFocused: Bool
  @State private var text = ""
  @State private var audience = Audience.everyone
  @State private var isShowingPoll = false
  @State private var firstOption = ""
  @State private var secondOption = ""
  @State private var hasMedia = false

  private enum Audience: String, CaseIterable, Identifiable {
    case everyone = "Everyone"
    case followers = "Followers"
    case mentioned = "Mentioned people"

    var id: Self { self }
    var symbol: String {
      switch self {
      case .everyone: "globe.americas.fill"
      case .followers: "person.2.fill"
      case .mentioned: "at"
      }
    }
  }

  private let limit = 500
  private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var canPost: Bool { !trimmedText.isEmpty && text.count <= limit }

  var body: some View {
    ZStack {
      AmbientBackground()

      VStack(spacing: 0) {
        composeHeader

        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
              AvatarView(initials: "L", size: 46)

              ZStack(alignment: .topLeading) {
                if text.isEmpty {
                  Text("What’s happening?")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 9)
                    .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                  .font(.title3)
                  .frame(minHeight: 180)
                  .scrollContentBackground(.hidden)
                  .focused($isFocused)
                  .onChange(of: text) { _, newValue in
                    if newValue.count > limit + 20 {
                      text = String(newValue.prefix(limit + 20))
                    }
                  }
              }
            }

            if hasMedia {
              mediaPreview
                .transition(.scale.combined(with: .opacity))
            }

            if isShowingPoll {
              pollEditor
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack {
              Menu {
                ForEach(Audience.allCases) { item in
                  Button {
                    audience = item
                  } label: {
                    Label(item.rawValue, systemImage: item.symbol)
                  }
                }
              } label: {
                Label(audience.rawValue, systemImage: audience.symbol)
                  .font(.subheadline.bold())
                  .foregroundStyle(TweetaColors.lavender)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 8)
                  .tweetaGlass(in: Capsule(), interactive: true)
              }
              Spacer()
              Text("\(max(0, limit - text.count))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(text.count > limit ? .red : .secondary)
            }
          }
          .padding(18)
        }

        composeTools
      }
    }
    .task {
      try? await Task.sleep(for: .milliseconds(350))
      isFocused = true
    }
  }

  private var composeHeader: some View {
    HStack {
      Button("Cancel") { dismiss() }
        .foregroundStyle(.secondary)
      Spacer()
      Text("New post")
        .font(.headline)
      Spacer()
      Button("Post") {
        store.publish(trimmedText)
        dismiss()
      }
      .font(.subheadline.bold())
      .foregroundStyle(.white)
      .padding(.horizontal, 17)
      .padding(.vertical, 10)
      .background(
        LinearGradient(
          colors: [TweetaColors.lavender, TweetaColors.violet], startPoint: .topLeading,
          endPoint: .bottomTrailing),
        in: Capsule()
      )
      .tweetaGlass(in: Capsule(), interactive: true)
      .disabled(!canPost)
      .opacity(canPost ? 1 : 0.45)
    }
    .padding(.horizontal, 18)
    .padding(.top, 18)
    .padding(.bottom, 12)
  }

  private var composeTools: some View {
    GlassGroup {
      HStack(spacing: 5) {
        toolButton(symbol: "photo", label: "Add photo") {
          withAnimation(.snappy) { hasMedia.toggle() }
        }
        toolButton(symbol: "camera", label: "Open camera") {
          withAnimation(.snappy) { hasMedia = true }
        }
        toolButton(symbol: "chart.bar.xaxis", label: "Add poll") {
          withAnimation(.snappy) { isShowingPoll.toggle() }
        }
        toolButton(symbol: "face.smiling", label: "Add emoji") { text += " ✨" }
        toolButton(symbol: "calendar.badge.clock", label: "Schedule") {}
      }
      .padding(7)
      .tweetaGlass(in: Capsule(), interactive: true)
    }
    .padding(.horizontal, 18)
    .padding(.bottom, 12)
  }

  private func toolButton(symbol: String, label: String, action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(TweetaColors.lavender)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  private var mediaPreview: some View {
    ZStack(alignment: .topTrailing) {
      LinearGradient(
        colors: [.indigo, TweetaColors.violet, .cyan], startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .frame(height: 180)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay {
        BirdMark()
          .fill(.white.opacity(0.28))
          .frame(width: 105, height: 105)
      }

      Button {
        withAnimation(.snappy) { hasMedia = false }
      } label: {
        Image(systemName: "xmark")
          .font(.caption.bold())
          .foregroundStyle(.white)
          .frame(width: 30, height: 30)
          .background(.black.opacity(0.42), in: Circle())
      }
      .padding(10)
      .accessibilityLabel("Remove photo")
    }
  }

  private var pollEditor: some View {
    VStack(spacing: 10) {
      HStack {
        Text("Poll").font(.subheadline.bold())
        Spacer()
        Button("Remove") {
          withAnimation(.snappy) { isShowingPoll = false }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      TextField("First option", text: $firstOption)
        .textFieldStyle(.plain)
        .padding(12)
        .tweetaGlass(in: RoundedRectangle(cornerRadius: 13), interactive: true)
      TextField("Second option", text: $secondOption)
        .textFieldStyle(.plain)
        .padding(12)
        .tweetaGlass(in: RoundedRectangle(cornerRadius: 13), interactive: true)
    }
    .padding(14)
    .tweetaGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }
}
