import SwiftUI

struct ContentView: View {
    @StateObject private var model = SicaViewModel()
    @EnvironmentObject private var appState: AppState
    @AppStorage("sica.expiry") private var expiryInterval: Double = 0

    private var daysRemaining: Int {
        guard expiryInterval > 0 else { return 29 }
        let raw = (Date(timeIntervalSince1970: expiryInterval).timeIntervalSinceNow / 86_400).rounded(.up)
        return max(0, Int(raw))
    }

    var body: some View {
        ZStack {
            SicaTheme.background.ignoresSafeArea()
            backgroundGlow.ignoresSafeArea()
            SicaHomeView(
                model: model,
                accessReady: appState.exploitStatus.isSuccess,
                daysRemaining: daysRemaining
            )
        }
        .preferredColorScheme(.dark)
        .task { await bootstrap() }
        .alert(item: $model.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var backgroundGlow: some View {
        ZStack {
            RadialGradient(
                colors: [SicaTheme.accent.opacity(0.28), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            RadialGradient(
                colors: [SicaTheme.accent.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 340
            )
        }
        .blendMode(.screen)
    }

    private func bootstrap() async {
        if expiryInterval == 0 {
            expiryInterval = Date().addingTimeInterval(29 * 86_400).timeIntervalSince1970
        }
        for _ in 0..<12 {
            model.detect()
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if model.gameFound { return }
        }
    }
}

#Preview {
    ContentView().environmentObject(AppState())
}
