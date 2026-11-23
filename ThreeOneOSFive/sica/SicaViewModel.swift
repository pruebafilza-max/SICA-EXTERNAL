import Foundation
import UIKit

@MainActor
final class SicaViewModel: ObservableObject {
    struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Published var selected: Set<SicaFeature> = []
    @Published var game: SicaGame = .freeFire
    @Published var containerPath: String?
    @Published var applied: Set<SicaFeature> = []
    @Published var busy = false
    @Published var status: String?
    @Published var notice: Notice?

    var gameFound: Bool { containerPath != nil }

    func detect() {
        let target = game
        DispatchQueue.global(qos: .userInitiated).async {
            let path = SicaPatchEngine.resolveContainer(for: target)
            let applied = SicaPatchEngine.appliedFeatures(for: target)
            DispatchQueue.main.async {
                guard self.game == target else { return }
                self.containerPath = path
                self.applied = applied
                if self.selected.isEmpty { self.selected = applied }
            }
        }
    }

    func changeGame() {
        guard !busy else { return }
        game = game.next
        selected = []
        applied = []
        containerPath = nil
        detect()
    }

    func toggle(_ feature: SicaFeature) {
        guard !busy else { return }
        if selected.contains(feature) { selected.remove(feature) } else { selected.insert(feature) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func activate() {
        guard !busy else { return }
        guard !selected.isEmpty else {
            notice = Notice(title: "Sin opciones", message: "Marca al menos una opción para parchear.")
            return
        }
        let features = selected
        let target = game
        busy = true
        status = "Aplicando parches…"

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try SicaPatchEngine.apply(features, to: target) { message in
                    DispatchQueue.main.async { self.status = message }
                }
                DispatchQueue.main.async {
                    self.busy = false
                    self.status = nil
                    self.applied = SicaPatchEngine.appliedFeatures(for: target)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.notice = Notice(
                        title: "Parche aplicado",
                        message: "\(count) archivo(s) modificados. Cierra Free Fire por completo y vuelve a abrirlo."
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.busy = false
                    self.status = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    self.notice = Notice(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    func deactivate() {
        guard !busy else { return }
        let target = game
        busy = true
        status = "Restaurando originales…"

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let count = try SicaPatchEngine.restoreAll(in: target) { message in
                    DispatchQueue.main.async { self.status = message }
                }
                DispatchQueue.main.async {
                    self.busy = false
                    self.status = nil
                    self.applied = []
                    self.selected = []
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.notice = Notice(
                        title: "Originales restaurados",
                        message: "\(count) archivo(s) volvieron a su estado original."
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.busy = false
                    self.status = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    self.notice = Notice(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
}
