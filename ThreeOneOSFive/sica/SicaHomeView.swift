import SwiftUI
import UIKit

struct SicaHomeView: View {
    @ObservedObject var model: SicaViewModel
    let accessReady: Bool
    let daysRemaining: Int

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                banner
                gameCard
                sectionHeader
                featureList
                footerStatus
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
    }

    private var banner: some View {
        ZStack {
            Group {
                if UIImage(named: "SicaBanner") != nil {
                    Image("SicaBanner").resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.20, green: 0.02, blue: 0.03), .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()

            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: 200)
        .overlay(alignment: .topLeading) { remainingPill.padding(14) }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SICA")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(5)
                    .foregroundStyle(SicaTheme.accent)
                Text("EXTERNAL")
                    .font(.system(size: 34, weight: .black))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                    .shadow(color: SicaTheme.accent.opacity(0.7), radius: 14)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(SicaTheme.accent.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: SicaTheme.accent.opacity(0.35), radius: 24, y: 8)
    }

    private var remainingPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(SicaTheme.accent)
                .frame(width: 6, height: 6)
                .shadow(color: SicaTheme.accent, radius: 4)
            Text("\(daysRemaining) DÍAS RESTANTES")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.65)))
        .overlay(Capsule().strokeBorder(SicaTheme.accent.opacity(0.7), lineWidth: 1))
    }

    private var gameCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("CURRENT GAME:")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(SicaTheme.dim)
                Text(model.game.title)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.gameFound ? SicaTheme.success : SicaTheme.accent)
                        .frame(width: 5, height: 5)
                    Text(model.gameFound ? "FOUND" : "NOT FOUND")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(model.gameFound ? SicaTheme.success : SicaTheme.accent)
                }
                Button { model.changeGame() } label: {
                    Text("Change Game")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(SicaTheme.accent.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .disabled(model.busy)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(SicaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(SicaTheme.surfaceStroke)
        )
    }

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(SicaTheme.accent)
                .frame(width: 3, height: 12)
            Text("BRUTAL FEATURES")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(SicaTheme.accent)
            Spacer()
            Text("\(model.selected.count)/\(SicaFeature.allCases.count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SicaTheme.dim)
        }
        .padding(.top, 2)
    }

    private var featureList: some View {
        VStack(spacing: 10) {
            ForEach(SicaFeature.allCases) { feature in
                featureRow(feature)
            }
        }
        .animation(.easeOut(duration: 0.15), value: model.selected)
    }

    private func featureRow(_ feature: SicaFeature) -> some View {
        let isOn = model.selected.contains(feature)
        return Button { model.toggle(feature) } label: {
            HStack {
                Text(feature.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                if model.applied.contains(feature) {
                    Text("ON")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(SicaTheme.success)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(SicaTheme.success.opacity(0.15)))
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? SicaTheme.accent.opacity(0.18) : Color.clear)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isOn ? SicaTheme.accent : Color.white.opacity(0.22),
                            lineWidth: 1.8
                        )
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(SicaTheme.accent)
                    }
                }
                .frame(width: 26, height: 26)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SicaTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isOn ? SicaTheme.accent.opacity(0.45) : SicaTheme.surfaceStroke)
            )
        }
        .buttonStyle(.plain)
        .disabled(model.busy)
    }

    @ViewBuilder
    private var footerStatus: some View {
        if let status = model.status {
            Text(status)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SicaTheme.dim)
                .lineLimit(1)
                .truncationMode(.middle)
        } else if !accessReady {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini).tint(SicaTheme.accent)
                Text("Esperando acceso al dispositivo…")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SicaTheme.dim)
            }
        } else if !model.gameFound {
            Text("Abre Free Fire al menos una vez para que su contenedor exista.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SicaTheme.dim)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            actionButton("ACTIVAR", color: SicaTheme.accent, busy: model.busy) {
                model.activate()
            }
            actionButton("DESACTIVAR", color: SicaTheme.success, busy: model.busy) {
                model.deactivate()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.92), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func actionButton(
        _ title: String,
        color: Color,
        busy: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(color))
                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                .shadow(color: color.opacity(0.55), radius: 16, y: 4)
                .opacity(busy ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }
}
