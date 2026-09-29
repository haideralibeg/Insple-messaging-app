import SwiftUI

// MARK: - TopThemeBar
struct TopThemeBar: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        if theme.isNostalgic {
            HStack {
                Label("Talkr Messenger", systemImage: "desktopcomputer")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                Spacer()
                Button("Gen Z") { theme.set("genz") }
                    .buttonStyle(RetroButtonStyle())
                    .accessibilityLabel("Switch to Gen Z mode")
            }
            .foregroundColor(RetroPalette.ink)
            .padding(10)
            .background(RetroPalette.panel)
            .modifier(RetroPanel())
            .padding(.horizontal, 10).padding(.top, 8)
        } else {
            HStack {
                Text("Talkr")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(theme.secondaryTextColor)

                Spacer()

                HStack(spacing: 8) {
                    // Gen Z pill
                    Button(action: { theme.set("genz") }) {
                        Text("Gen Z")
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(theme.activeMode == "genz" ? theme.primaryColor : Color.clear)
                            .foregroundColor(theme.activeMode == "genz" ? theme.primaryTextColor : theme.secondaryTextColor)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    theme.activeMode == "genz" ? Color.clear : theme.secondaryTextColor.opacity(0.4),
                                    lineWidth: 1.5
                                )
                            )
                    }

                    // Nostalgic pill
                    Button(action: { theme.set("nostalgic") }) {
                        Text("Nostalgic")
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(theme.activeMode == "nostalgic" ? theme.primaryColor : Color.clear)
                            .foregroundColor(theme.activeMode == "nostalgic" ? theme.primaryTextColor : theme.secondaryTextColor)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    theme.activeMode == "nostalgic" ? Color.clear : theme.secondaryTextColor.opacity(0.4),
                                    lineWidth: 1.5
                                )
                            )
                    }

                    // More options
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                            .padding(8)
                            .overlay(Circle().stroke(theme.secondaryTextColor.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .animation(.easeInOut(duration: 0.25), value: theme.activeMode)
        }
    }
}

// MARK: - AvatarView
struct AvatarView: View {
    @EnvironmentObject var theme: ThemeManager
    var size: CGFloat = 50
    var showUnreadDot: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if theme.isNostalgic {
                Image(systemName: "person.crop.square.fill")
                    .resizable().scaledToFit()
                    .foregroundColor(RetroPalette.navy)
                    .padding(6)
                    .frame(width: size, height: size)
                    .background(RetroPalette.panel)
                    .modifier(RetroPanel())
            } else {
            Circle()
                .fill(theme.primaryColor)
                .frame(width: size, height: size)
            }

            if showUnreadDot {
                Circle()
                    .fill(theme.unreadDotColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(theme.backgroundColor, lineWidth: 2))
                    .offset(x: -2, y: 2)
            }
        }
    }
}

struct ReadReceiptView: View {
    @EnvironmentObject var theme: ThemeManager
    var isRead: Bool

    var body: some View {
        Group {
            if theme.activeMode == "genz" {
                Text(isRead ? "seen" : "sent")
                    .font(.caption2)
                    .fontWeight(isRead ? .bold : .regular)
                    .foregroundColor(isRead ? theme.readReceiptSeenColor : theme.secondaryTextColor.opacity(0.4))
            } else {
                HStack(spacing: 3) {
                    Image(systemName: isRead ? "checkmark.circle.fill" : "checkmark.circle")
                    Text(isRead ? "Read" : "Delivered")
                }
                .font(.caption2)
                .foregroundColor(isRead ? theme.readReceiptSeenColor : theme.secondaryTextColor.opacity(0.4))
            }
        }
    }
}

