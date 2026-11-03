import SwiftUI

enum CallKind: String, Identifiable {
    case voice, video
    var id: String { rawValue }
}

/// Presentation only. A calling service can supply a connection date once answered.
struct CallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    let partner: User
    var connectedAt: Date? = nil
    @State private var isMuted = false
    @State private var isSpeakerOn = false
    @State private var isVideoOn: Bool
    @State private var isVideoCall: Bool
    @State private var isFrontCamera = true

    init(partner: User, kind: CallKind = .voice, connectedAt: Date? = nil) {
        self.partner = partner
        self.connectedAt = connectedAt
        _isVideoOn = State(initialValue: kind == .video)
        _isVideoCall = State(initialValue: kind == .video)
    }

    private var callTitle: String { isVideoCall ? "Video call" : "Voice call" }
    private var ink: Color { theme.isNostalgic ? RetroPalette.ink : theme.secondaryTextColor }

    var body: some View {
        VStack(spacing: 0) {
            TopThemeBar()
            header
                .padding(.top, 12)
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 28) {
                        if isVideoCall {
                            videoStage(height: max(240, min(480, geometry.size.height * 0.57)))
                                .padding(.top, 16)
                            callStatus
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 24)
                            caller
                            Spacer(minLength: 32)
                        }
                        controls
                        endCall
                            .padding(.bottom, 28)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 560)
                    .frame(minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .foregroundStyle(ink)
        .fontDesign(theme.isNostalgic ? .monospaced : .default)
        .background(theme.backgroundColor.ignoresSafeArea())
        .preferredColorScheme(theme.isNostalgic ? .light : .dark)
        .animation(.easeInOut(duration: 0.25), value: theme.activeMode)
        .interactiveDismissDisabled()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("End call and return to conversation")
            AvatarView(size: 38)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(partner.name).font(.headline)
                Text(callTitle).font(.caption).opacity(0.65)
            }
            Spacer(minLength: 0)
            Image(systemName: isVideoCall ? "video.fill" : "phone.fill")
                .accessibilityHidden(true)
        }
        .padding(.leading, 4)
        .padding(.trailing, 20)
        .padding(.vertical, 8)
        .foregroundStyle(theme.isNostalgic ? Color.white : ink)
        .background(theme.isNostalgic ? RetroPalette.navy : theme.subtleColor.opacity(0.45))
    }

    private var caller: some View {
        VStack(spacing: 20) {
            ZStack {
                if theme.isNostalgic {
                    Rectangle().fill(RetroPalette.panel)
                        .modifier(RetroPanel())
                } else {
                    Circle().fill(theme.primaryColor.opacity(0.1))
                    Circle().stroke(theme.primaryColor.opacity(0.2), lineWidth: 1)
                        .padding(10)
                    Circle().fill(theme.primaryColor).padding(22)
                }
                Image(systemName: theme.isNostalgic ? "person.crop.square" : "person")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(theme.isNostalgic ? RetroPalette.navy : theme.primaryTextColor)
            }
            .frame(width: 156, height: 156)
            .accessibilityHidden(true)

            Text(partner.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            callStatus
        }
    }

    private var callStatus: some View {
        HStack(spacing: 6) {
            Text(callTitle)
            Text("·")
            if let connectedAt {
                Text(connectedAt, style: .timer).monospacedDigit()
            } else {
                Text("Calling…")
            }
        }
        .font(.subheadline)
        .foregroundStyle(ink.opacity(0.65))
        .fixedSize(horizontal: false, vertical: true)
    }

    private func videoStage(height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.rectangle")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(theme.isNostalgic ? RetroPalette.navy : theme.outgoingBubbleColor)
                    .accessibilityHidden(true)
                Text(partner.name).font(.headline)
                    .multilineTextAlignment(.center)
                Text(connectedAt == nil ? "Waiting for video…" : "Video preview")
                    .font(.caption).foregroundStyle(ink.opacity(0.6))
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 10) {
                Image(systemName: isVideoOn ? "person" : "video.slash")
                    .font(.system(size: 26, weight: .light))
                Text(isVideoOn ? "You" : "Camera off")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                if isVideoOn {
                    Text(isFrontCamera ? "Front" : "Back")
                        .font(.caption2).opacity(0.6)
                }
            }
            .padding(8)
            .frame(width: 80, height: 112)
            .background(theme.isNostalgic ? Color.white : theme.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: theme.isNostalgic ? 0 : 12))
            .overlay {
                if theme.isNostalgic { Rectangle().modifier(RetroPanel()).foregroundStyle(.clear) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isVideoOn ? "Your video preview, \(isFrontCamera ? "front" : "back") camera" : "Your camera is off")
            .padding(12)
        }
        .frame(height: height)
        .background(theme.isNostalgic ? RetroPalette.panel : theme.subtleColor.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: theme.isNostalgic ? 0 : 20))
        .overlay {
            if theme.isNostalgic { Rectangle().modifier(RetroPanel(inset: true)).foregroundStyle(.clear) }
        }
    }

    private var controls: some View {
        HStack(alignment: .top, spacing: isVideoCall ? 12 : 16) {
            control("Mute", symbol: isMuted ? "mic.slash.fill" : "mic.fill", active: isMuted) {
                isMuted.toggle()
            }
            if isVideoCall {
                control("Camera", symbol: isVideoOn ? "video.fill" : "video.slash.fill", active: isVideoOn) {
                    isVideoOn.toggle()
                }
                control("Flip", symbol: "camera.rotate", active: false) {
                    isFrontCamera.toggle()
                }
                .disabled(!isVideoOn)
                .opacity(isVideoOn ? 1 : 0.4)
                .accessibilityValue(isFrontCamera ? "Front camera" : "Back camera")
            }
            control("Speaker", symbol: isSpeakerOn ? "speaker.wave.2.fill" : "speaker.fill", active: isSpeakerOn) {
                isSpeakerOn.toggle()
            }
            if !isVideoCall {
                control("Video", symbol: "video.slash.fill", active: false) {
                    isVideoCall = true
                    isVideoOn = true
                }
            }
        }
    }

    private func control(_ title: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 23, weight: .medium))
                    .frame(width: isVideoCall ? 56 : 64, height: isVideoCall ? 56 : 64)
                    .foregroundStyle(active ? (theme.isNostalgic ? .white : theme.primaryTextColor) : ink)
                    .background {
                        if theme.isNostalgic {
                            Rectangle().fill(active ? RetroPalette.navy : RetroPalette.panel)
                                .modifier(RetroPanel(inset: active))
                        } else {
                            Circle().fill(active ? theme.primaryColor : theme.subtleColor)
                        }
                    }
                Text(title).font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(active ? "On" : "Off")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var endCall: some View {
        Button(role: .destructive) { dismiss() } label: {
            VStack(spacing: 12) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 64)
                    .background {
                        if theme.isNostalgic {
                            Rectangle().fill(Color(red: 0.65, green: 0.16, blue: 0.16))
                                .modifier(RetroPanel())
                        } else {
                            Capsule().fill(Color(red: 0.9, green: 0.22, blue: 0.32))
                        }
                    }
                Text("End call").font(.caption).foregroundStyle(ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("End call")
    }
}

#if DEBUG
#Preview("Call — Gen Z") {
    PreviewHost { _ in CallView(partner: PreviewData.contacts[0]) }
}

#Preview("Call — Nostalgic") {
    PreviewHost(mode: "nostalgic") { _ in
        CallView(partner: PreviewData.contacts[0], connectedAt: Date.now.addingTimeInterval(-204))
    }
}

#Preview("Call — Video") {
    PreviewHost { _ in CallView(partner: PreviewData.contacts[1], kind: .video) }
}

#Preview("Video — Nostalgic") {
    PreviewHost(mode: "nostalgic") { _ in
        CallView(partner: PreviewData.contacts[0], kind: .video, connectedAt: Date.now.addingTimeInterval(-204))
    }
}

#Preview("Video — Large Text") {
    PreviewHost { _ in CallView(partner: PreviewData.contacts[1], kind: .video) }
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
