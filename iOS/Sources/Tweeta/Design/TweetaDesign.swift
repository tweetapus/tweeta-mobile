import SwiftUI

enum TweetaColors {
  static let lavender = Color(red: 0.62, green: 0.53, blue: 1.0)
  static let violet = Color(red: 0.46, green: 0.32, blue: 0.95)
  static let ink = Color(red: 0.055, green: 0.055, blue: 0.095)
}

struct AmbientBackground: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      (colorScheme == .dark ? TweetaColors.ink : Color(red: 0.95, green: 0.95, blue: 0.99))
        .ignoresSafeArea()

      Circle()
        .fill(TweetaColors.violet.opacity(colorScheme == .dark ? 0.22 : 0.14))
        .frame(width: 330, height: 330)
        .blur(radius: 80)
        .offset(x: 160, y: -320)

      Circle()
        .fill(Color.cyan.opacity(colorScheme == .dark ? 0.12 : 0.1))
        .frame(width: 300, height: 300)
        .blur(radius: 90)
        .offset(x: -190, y: 280)
    }
    .allowsHitTesting(false)
  }
}

struct BirdMark: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    var path = Path()
    path.move(to: CGPoint(x: 0.08 * w, y: 0.66 * h))
    path.addCurve(
      to: CGPoint(x: 0.32 * w, y: 0.59 * h),
      control1: CGPoint(x: 0.18 * w, y: 0.68 * h),
      control2: CGPoint(x: 0.26 * w, y: 0.64 * h)
    )
    path.addCurve(
      to: CGPoint(x: 0.18 * w, y: 0.18 * h),
      control1: CGPoint(x: 0.12 * w, y: 0.45 * h),
      control2: CGPoint(x: 0.14 * w, y: 0.28 * h)
    )
    path.addCurve(
      to: CGPoint(x: 0.53 * w, y: 0.32 * h),
      control1: CGPoint(x: 0.28 * w, y: 0.3 * h),
      control2: CGPoint(x: 0.4 * w, y: 0.36 * h)
    )
    path.addCurve(
      to: CGPoint(x: 0.68 * w, y: 0.17 * h),
      control1: CGPoint(x: 0.56 * w, y: 0.2 * h),
      control2: CGPoint(x: 0.61 * w, y: 0.16 * h)
    )
    path.addCurve(
      to: CGPoint(x: 0.79 * w, y: 0.2 * h),
      control1: CGPoint(x: 0.72 * w, y: 0.16 * h),
      control2: CGPoint(x: 0.76 * w, y: 0.18 * h)
    )
    path.addLine(to: CGPoint(x: 0.96 * w, y: 0.08 * h))
    path.addCurve(
      to: CGPoint(x: 0.82 * w, y: 0.34 * h),
      control1: CGPoint(x: 0.93 * w, y: 0.19 * h),
      control2: CGPoint(x: 0.88 * w, y: 0.28 * h)
    )
    path.addCurve(
      to: CGPoint(x: 0.08 * w, y: 0.66 * h),
      control1: CGPoint(x: 0.84 * w, y: 0.69 * h),
      control2: CGPoint(x: 0.42 * w, y: 0.86 * h)
    )
    path.closeSubpath()
    return path
  }
}

extension View {
  @ViewBuilder
  func tweetaGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
    if #available(iOS 26.0, *) {
      if interactive {
        glassEffect(.regular.interactive(), in: shape)
      } else {
        glassEffect(.regular, in: shape)
      }
    } else {
      background(.ultraThinMaterial, in: shape)
        .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 0.7))
    }
  }
}

struct GlassGroup<Content: View>: View {
  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  @ViewBuilder
  var body: some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer(spacing: 14) {
        content
      }
    } else {
      content
    }
  }
}

struct AvatarView: View {
  let initials: String
  var size: CGFloat = 44
  var imageURL: URL? = nil

  private var colors: [Color] {
    let index = initials.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 4
    return [
      [TweetaColors.lavender, .indigo],
      [.cyan, .blue],
      [.pink, .purple],
      [.orange, .pink],
    ][index]
  }

  var body: some View {
    ZStack {
      Circle().fill(
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
      Text(initials)
        .font(.system(size: size * 0.31, weight: .bold, design: .rounded))
        .foregroundStyle(.white)

      if let imageURL {
        AsyncImage(url: imageURL) { phase in
          if case .success(let image) = phase {
            image.resizable().scaledToFill()
          }
        }
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
    .accessibilityHidden(true)
  }
}

struct SectionTitle: View {
  let eyebrow: String?
  let title: String

  init(_ title: String, eyebrow: String? = nil) {
    self.title = title
    self.eyebrow = eyebrow
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      if let eyebrow {
        Text(eyebrow.uppercased())
          .font(.caption2.weight(.bold))
          .tracking(1.4)
          .foregroundStyle(TweetaColors.lavender)
      }
      Text(title)
        .font(.title2.bold())
    }
  }
}
