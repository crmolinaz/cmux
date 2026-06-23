import CmuxCommandPalette
import CmuxMascot
import Foundation

extension ContentView {
    static func commandPaletteMascotContributions() -> [CommandPaletteCommandContribution] {
        func constant(_ value: String) -> (CommandPaletteContextSnapshot) -> String {
            { _ in value }
        }

        let subtitle = constant(String(localized: "command.mascot.subtitle", defaultValue: "Mascot"))
        return [
            CommandPaletteCommandContribution(
                commandId: "palette.mascot",
                title: constant(String(localized: "command.mascot.title", defaultValue: "/mascot")),
                subtitle: subtitle,
                keywords: ["mascot", "rex", "trex", "dino", "dinosaur", "/mascot"]
            ),
            CommandPaletteCommandContribution(
                commandId: "palette.mascot.close",
                title: constant(String(localized: "command.mascotClose.title", defaultValue: "/mascot close")),
                subtitle: subtitle,
                keywords: ["mascot", "rex", "trex", "dino", "close", "hide", "/mascot close"]
            ),
        ]
    }

    func registerMascotCommandHandlers(_ registry: inout CommandPaletteHandlerRegistry) {
        registry.register(commandId: "palette.mascot") {
            AppDelegate.shared?.mascotController.show()
        }
        registry.register(commandId: "palette.mascot.close") {
            AppDelegate.shared?.mascotController.hide()
        }
    }
}
