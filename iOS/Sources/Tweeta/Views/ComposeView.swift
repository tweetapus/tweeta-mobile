import SwiftUI

struct ComposeView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @FocusState private var isFocused: Bool
  @State private var text = ""
  @State private var isShowingPoll = false
  @State private var firstOption = ""
  @State private var secondOption = ""
  @State private var isPosting = false
  @State private var errorMessage: String?

  private let limit = 500
  private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var pollIsValid: Bool {
    !isShowingPoll
      || (!firstOption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !secondOption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }
  private var canPost: Bool {
    !trimmedText.isEmpty && text.count <= limit && pollIsValid && !isPosting
  }

  var body: some View {
    ZStack {
      AmbientBackground()

      VStack(spacing: 0) {
        composeHeader

        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
              AvatarView(
                initials: store.profile?.initials ?? "?", size: 46,
                imageURL: store.profile?.avatarURL)

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

            if isShowingPoll {
              pollEditor
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack {
              Label("Public post", systemImage: "globe.americas.fill")
                .font(.subheadline.bold())
                .foregroundStyle(TweetaColors.lavender)
              Spacer()
              Text("\(max(0, limit - text.count))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(text.count > limit ? .red : .secondary)
            }

            if let errorMessage {
              Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
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
        post()
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
        toolButton(symbol: "chart.bar.xaxis", label: "Add poll") {
          withAnimation(.snappy) { isShowingPoll.toggle() }
        }
        toolButton(symbol: "face.smiling", label: "Add emoji") { text += " ✨" }
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

  private func post() {
    guard canPost else { return }
    isPosting = true
    errorMessage = nil
    let options = isShowingPoll
      ? [firstOption, secondOption].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      : []
    Task {
      do {
        try await store.publish(trimmedText, pollOptions: options)
        dismiss()
      } catch {
        errorMessage = error.localizedDescription
        isPosting = false
      }
    }
  }
}
