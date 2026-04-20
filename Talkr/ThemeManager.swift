import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var activeMode: String = "genz"  // "genz" | "nostalgic"

    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Mirror AuthService.currentUser.activeMode into ThemeManager
        AuthService.shared.$currentUser
            .compactMap { $0?.activeMode }
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                self?.activeMode = mode
            }
            .store(in: &cancellables)
    }

    func toggle() {
        let next = activeMode == "genz" ? "nostalgic" : "genz"
        activeMode = next
        AuthService.shared.updateMode(next)
    }

    func set(_ mode: String) {
        activeMode = mode
        AuthService.shared.updateMode(mode)
    }

    // MARK: - Theme Colors
    var outgoingBubbleColor: Color {
        activeMode == "genz" ? Color(red: 0.4, green: 0.2, blue: 0.9) : Color(red: 0.9, green: 0.45, blue: 0.0)
    }

    var incomingBubbleColor: Color {
        Color(.systemGray5)
    }

    var accentColor: Color {
        activeMode == "genz" ? Color.cyan : Color.yellow
    }

    var label1: String { "Gen Z" }
    var label2: String { "Nostalgic" }
}



