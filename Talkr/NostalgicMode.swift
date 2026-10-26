import SwiftUI
import AVFoundation

// Shared desktop-messenger colors, independent of the device's dark appearance.
enum RetroPalette {
    static let desktop = Color(red: 0.78, green: 0.84, blue: 0.83)
    static let panel = Color(red: 0.87, green: 0.86, blue: 0.82)
    static let navy = Color(red: 0.08, green: 0.18, blue: 0.42)
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.15)
}

struct RetroPanel: ViewModifier {
    var inset = false
    func body(content: Content) -> some View {
        content
            .overlay(Rectangle().stroke(RetroPalette.ink.opacity(0.6), lineWidth: 1))
            .overlay(alignment: .top) { Rectangle().fill(inset ? .gray : .white).frame(height: 2) }
            .overlay(alignment: .leading) { Rectangle().fill(inset ? .gray : .white).frame(width: 2) }
            .overlay(alignment: .bottom) { Rectangle().fill(inset ? .white : .gray).frame(height: 2) }
            .overlay(alignment: .trailing) { Rectangle().fill(inset ? .white : .gray).frame(width: 2) }
    }
}

struct RetroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .foregroundColor(RetroPalette.ink)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RetroPalette.panel)
            .modifier(RetroPanel(inset: configuration.isPressed))
    }
}

struct NostalgicConversation: View {
    @EnvironmentObject private var auth: AuthService
    @Binding var messageText: String
    let chat: Chat
    let send: () -> Void
    @AppStorage("nostalgicSoundsEnabled") private var soundsEnabled = true

    init(chat: Chat, messageText: Binding<String>, send: @escaping () -> Void) {
        self.chat = chat
        self._messageText = messageText
        self.send = send
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "message.fill")
                Text("\(chat.partner.name) — Instant Message")
                    .fontWeight(.bold).lineLimit(2)
                Spacer(minLength: 0)
            }
            .font(.system(.subheadline, design: .monospaced))
            .foregroundColor(.white)
            .padding(12)
            .background(RetroPalette.navy)

            HStack {
                Text("Conversation")
                Spacer()
                Button {
                    soundsEnabled.toggle()
                } label: {
                    Label(soundsEnabled ? "Sound on" : "Sound off", systemImage: soundsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .accessibilityLabel("Messenger sounds")
                .accessibilityValue(soundsEnabled ? "On" : "Off")
            }
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(RetroPalette.ink)
            .padding(10)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Text("Conversation with \(chat.partner.name)")
                            .fontWeight(.bold)
                        Text("A little old school. Still in real time.")
                            .foregroundColor(.secondary)
                        Divider()
                        if chat.messages.isEmpty {
                            Text("Say hello to start your conversation. :)")
                                .foregroundColor(.secondary)
                        }
                        ForEach(chat.messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(message.isIncoming ? chat.partner.name : (auth.currentUser?.name ?? "You"))
                                        .fontWeight(.bold)
                                        .foregroundColor(message.isIncoming ? RetroPalette.navy : Color(red: 0.6, green: 0.15, blue: 0.12))
                                    Text(message.timestamp, format: .dateTime.hour().minute())
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                Text(message.content)
                                    .foregroundColor(RetroPalette.ink)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(message.id)
                        }
                    }
                    .font(.system(.subheadline, design: .monospaced))
                    .padding(14)
                }
                .background(Color.white)
                .modifier(RetroPanel(inset: true))
                .onAppear { scrollToLatest(proxy) }
                .onChange(of: chat.messages.count) { _ in scrollToLatest(proxy) }
            }
            .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Emoticons:").font(.system(.caption, design: .monospaced))
                    ForEach([":)", ";)", ":D", "<3"], id: \.self) { face in
                        Button(face) {
                            messageText += (messageText.isEmpty || messageText.hasSuffix(" ") ? "" : " ") + face
                        }
                        .buttonStyle(RetroButtonStyle())
                        .accessibilityLabel("Insert \(face)")
                    }
                }
                TextField("Type a message…", text: $messageText, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .background(Color.white)
                    .modifier(RetroPanel(inset: true))
                HStack {
                    Text("Enter a message, then Send.")
                        .font(.system(.caption2, design: .monospaced))
                    Spacer()
                    Button("Send", action: send)
                        .buttonStyle(RetroButtonStyle())
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .foregroundColor(RetroPalette.ink)
            .padding(10)
        }
        .background(RetroPalette.panel)
        .modifier(RetroPanel())
        .padding(10)
        .preferredColorScheme(.light)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
    }
}

// Original two-note chimes generated in memory; ambient audio respects Silent Mode.
final class NostalgicSounds {
    static let shared = NostalgicSounds()
    enum Event { case sent, received }
    private var player: AVAudioPlayer?

    func play(_ event: Event) {
        guard UserDefaults.standard.object(forKey: "nostalgicSoundsEnabled") as? Bool ?? true else { return }
        let frequencies: [Double] = event == .sent ? [660, 880] : [880, 660]
        let rate = 22050
        let noteSamples = rate / 10
        var pcm = Data()
        for frequency in frequencies {
            for sample in 0..<noteSamples {
                let envelope = sin(Double.pi * Double(sample) / Double(noteSamples))
                var value = Int16(sin(2 * Double.pi * frequency * Double(sample) / Double(rate)) * envelope * 5500).littleEndian
                withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
            }
        }
        var wav = Data("RIFF".utf8)
        func append(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { wav.append(contentsOf: $0) }
        }
        append(UInt32(36 + pcm.count))
        wav.append(Data("WAVEfmt ".utf8))
        append(16)
        wav.append(contentsOf: [1, 0, 1, 0]) // PCM, mono
        append(UInt32(rate))
        append(UInt32(rate * 2))
        wav.append(contentsOf: [2, 0, 16, 0]) // block alignment, bit depth
        wav.append(Data("data".utf8))
        append(UInt32(pcm.count))
        wav.append(pcm)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            player = try AVAudioPlayer(data: wav)
            player?.play()
        } catch {
            // Audio is optional; messaging continues if the audio session is unavailable.
        }
    }
}

#if DEBUG
#Preview("Nostalgic Conversation") {
    PreviewHost(mode: "nostalgic") { _ in
        ChatView(chat: PreviewData.chats[0])
    }
}

#endif
