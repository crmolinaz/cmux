public import SwiftUI

/// The embedded mascot strip: a fixed-height band with a little pixel landscape
/// — sky and grass, a volcano on the right, trees and a pond on the left — and
/// the T-Rex standing in front. Mounted by the app above its project tabs.
/// Render it only while ``MascotController/isVisible`` is true (the host gates
/// on that). Tapping the strip winks the mascot.
public struct MascotStripView: View {
    private let controller: MascotController

    /// The strip's height, in points.
    public static let height: CGFloat = 72

    public init(controller: MascotController) {
        self.controller = controller
    }

    /// Height of the grass band at the bottom of the strip.
    private static let grassHeight: CGFloat = 24
    /// Baseline for background scenery: bases rest on the grass horizon (a few
    /// points into the grass) so the volcano and trees read as further away,
    /// behind the foreground mascot.
    private static let backgroundInset: CGFloat = grassHeight - 4

    public var body: some View {
        ZStack(alignment: .bottom) {
            skyAndGrass

            sceneImage("scene-volcano", height: 40)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 6)
                .padding(.bottom, Self.backgroundInset)

            sceneImage("scene-trees", height: 26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 6)
                .padding(.bottom, Self.backgroundInset)

            sceneImage("scene-pond", height: 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 18)
                .padding(.bottom, 3)

            mascot
                .frame(height: 56)
                .padding(.bottom, 2)

            if controller.isAsleep {
                ZzzView()
                    .offset(x: 6, y: -8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .clipped()
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
        .contentShape(Rectangle())
        .onTapGesture { controller.poke() }
        .accessibilityElement()
        .accessibilityLabel(Text(
            String(
                localized: "mascot.accessibilityLabel",
                defaultValue: "T-Rex mascot",
                bundle: .module
            )
        ))
    }

    private var skyAndGrass: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    Color(red: 0.64, green: 0.85, blue: 0.93),
                    Color(red: 0.86, green: 0.94, blue: 0.97),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Color(red: 0.37, green: 0.68, blue: 0.27)
                .frame(height: Self.grassHeight)
                .overlay(alignment: .top) {
                    Color(red: 0.29, green: 0.56, blue: 0.19).frame(height: 2)
                }
        }
    }

    private var mascot: some View {
        currentFrame
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }

    private func sceneImage(_ name: String, height: CGFloat) -> some View {
        Group {
            if let image = MascotSprite.image(named: name) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(height: height)
    }

    private var currentFrame: Image {
        if let nsImage = MascotSprite.image(named: controller.animator.currentFrameName) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.square.dashed")
    }
}

/// Three "z"s that drift up and fade, staggered, to signal the napping mascot.
private struct ZzzView: View {
    @State private var rising = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            z(size: 9, dx: 0, delay: 0)
            z(size: 12, dx: 8, delay: 0.6)
            z(size: 15, dx: 18, delay: 1.2)
        }
        .frame(width: 34, height: 30, alignment: .bottomLeading)
        .onAppear { rising = true }
    }

    private func z(size: CGFloat, dx: CGFloat, delay: Double) -> some View {
        Text("z")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 0.5, y: 0.5)
            .offset(x: dx, y: rising ? -16 : 0)
            .opacity(rising ? 0 : 1)
            .animation(
                .easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(delay),
                value: rising
            )
    }
}
