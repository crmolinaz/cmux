public import SwiftUI

/// The embedded mascot strip: a fixed-height horizontal band that hosts the
/// animated T-Rex. Mounted by the app above its project tabs. Render it only
/// while ``MascotController/isVisible`` is true (the host gates on that).
public struct MascotStripView: View {
    private let controller: MascotController

    /// The strip's height, in points.
    public static let height: CGFloat = 60

    public init(controller: MascotController) {
        self.controller = controller
    }

    public var body: some View {
        ZStack {
            currentFrame
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(.quaternary.opacity(0.5))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
        .accessibilityElement()
        .accessibilityLabel(Text(
            String(
                localized: "mascot.accessibilityLabel",
                defaultValue: "T-Rex mascot",
                bundle: .module
            )
        ))
    }

    private var currentFrame: Image {
        if let nsImage = MascotSprite.image(named: controller.animator.currentFrameName) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "questionmark.square.dashed")
    }
}
