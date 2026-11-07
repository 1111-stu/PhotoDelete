import SwiftUI

struct CompletionStatPill: View {
    let icon: String
    let value: Int
    let title: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text("\(value)")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundColor(tint)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
        )
    }
}

struct ReviewAlbumDragHint: View {
    let progress: CGFloat

    var body: some View {
        VStack {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.accent)

                Text(L10n.string("Swipe down to add"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.surface.opacity(0.96))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Theme.accent.opacity(0.82), lineWidth: 1.2)
                    )
            )
            .padding(.top, 16)
            .offset(y: -10 + progress * 10)

            Spacer()
        }
        .opacity(0.7 + progress * 0.3)
    }
}

struct PhotoSelectionLoadingCard: View {
    let title: String
    let message: String
    let progress: Double

    var body: some View {
        VStack(spacing: 16) {
            if progress > 0.01 {
                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Theme.accent))
                        .frame(maxWidth: 230)
                        .clipShape(Capsule(style: .continuous))

                    Text(L10n.percent(Int(progress * 100)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.tertiaryText)
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.accent))
                    .scaleEffect(1.05)
            }

            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.primaryText)

                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .photoDeleteCard()
    }
}

private struct PocaPressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}


enum PocaActionButtonStyle {
    case quiet
    case soft
    case solid
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var style: PocaActionButtonStyle = .soft
    var badgeText: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(buttonBackground)
                    .overlay(alignment: .topTrailing) {
                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Capsule(style: .continuous).fill(Theme.destructive))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Theme.surface, lineWidth: 2)
                                )
                                .offset(x: 5, y: -5)
                        }
                    }

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 68)
        }
        .buttonStyle(PocaPressScaleButtonStyle())
    }

    private var buttonSize: CGFloat {
        style == .quiet ? 42 : 46
    }

    private var iconColor: Color {
        style == .solid ? .white : color
    }

    private var labelColor: Color {
        style == .solid ? Theme.primaryText : Theme.secondaryText
    }

    private var buttonBackground: some View {
        Circle()
            .fill(backgroundFill)
            .overlay(
                Circle()
                    .stroke(strokeColor, lineWidth: 1)
            )
    }

    private var backgroundFill: Color {
        switch style {
        case .quiet:
            return Theme.elevatedSurface.opacity(0.72)
        case .soft:
            return color.opacity(0.13)
        case .solid:
            return color
        }
    }

    private var strokeColor: Color {
        switch style {
        case .quiet:
            return Theme.hairline
        case .soft:
            return color.opacity(0.18)
        case .solid:
            return color.opacity(0.0)
        }
    }
}

struct SessionMuteToggleButton: View {
    let isMuted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                isMuted ? L10n.string("Turn Sound On") : L10n.string("Mute"),
                systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
            )
            .labelStyle(.iconOnly)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(isMuted ? Theme.secondaryText : Theme.accent)
            .frame(width: 38, height: 38)
            .background(
                Circle()
                    .fill(Theme.surface)
                    .overlay(
                        Circle()
                            .stroke(
                                isMuted ? Theme.cardStroke : Theme.accent.opacity(0.28),
                                lineWidth: 1
                            )
                    )
            )
            .photoDeleteMinimumTapTarget()
        }
        .buttonStyle(PocaPressScaleButtonStyle())
        .accessibilityLabel(isMuted ? L10n.string("Turn Sound On") : L10n.string("Mute"))
        .accessibilityHint(L10n.string("Only affects the current review screen."))
    }
}

struct SidebarActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var isCompact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if !isCompact {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSm, style: .continuous)
                            .stroke(color.opacity(0.32), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

extension View {
    @ViewBuilder
    func photoDeleteSimultaneousTapGesture(enabled: Bool, action: @escaping () -> Void) -> some View {
        if enabled {
            self.simultaneousGesture(TapGesture().onEnded { action() })
        } else {
            self
        }
    }
}
