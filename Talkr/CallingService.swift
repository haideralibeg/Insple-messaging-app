import SwiftUI
import Observation
internal import Combine // Bridges Stream's device-token publisher to an async sequence.
import FirebaseAuth
import FirebaseFunctions
import StreamVideo
import StreamVideoSwiftUI

/// Firebase identifies the user; only the server signs Stream access tokens.
@MainActor
@Observable
final class CallingService {
    private(set) var viewModel: CallViewModel?
    private(set) var isConnecting = false
    var errorMessage: String?
    private var client: StreamVideo?
    private var connectedUserID: String?
    private var generation = UUID()
    private var tokenObservation: Task<Void, Never>?
    private var registeredVoIPToken = ""
    @ObservationIgnored @Injected(\.callKitAdapter) private var callKitAdapter
    @ObservationIgnored @Injected(\.callKitPushNotificationAdapter) private var pushAdapter

    func connect(userID: String?, name: String) async {
        let session = UUID()
        generation = session
        await disconnect()
        guard generation == session, !Task.isCancelled, let userID else { return }
        isConnecting = true
        defer { if generation == session { isConnecting = false } }
        do {
            let credentials = try await Self.credentials(for: userID)
            guard !Task.isCancelled, generation == session,
                  Auth.auth().currentUser?.uid == userID else { return }
            let video = StreamVideo(
                apiKey: credentials.apiKey,
                user: CallingUser(id: userID, name: name),
                token: UserToken(rawValue: credentials.token),
                tokenProvider: { completion in
                    Task { @MainActor in
                        do {
                            let refreshed = try await Self.credentials(for: userID)
                            completion(.success(UserToken(rawValue: refreshed.token)))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            )
            client = video
            connectedUserID = userID
            // Start incoming calls with the camera off until the recipient explicitly enables it.
            viewModel = CallViewModel(callSettings: CallSettings(audioOn: true, videoOn: false))
            callKitAdapter.callSettings = CallSettings(audioOn: true, videoOn: false)
            callKitAdapter.streamVideo = video
            callKitAdapter.registerForIncomingCalls()
            tokenObservation = Task { [weak self] in
                guard let self else { return }
                for await token in self.pushAdapter.$deviceToken.values {
                    guard !Task.isCancelled, self.generation == session else { return }
                    do {
                        if !self.registeredVoIPToken.isEmpty, self.registeredVoIPToken != token {
                            try await video.deleteDevice(id: self.registeredVoIPToken)
                        }
                        if !token.isEmpty {
                            try await video.setVoipDevice(id: token)
                        }
                        self.registeredVoIPToken = token
                    } catch {
                        self.errorMessage = "Incoming call notifications could not be enabled. Please try again."
                    }
                }
            }
            try await video.connect()
        } catch {
            guard generation == session else { return }
            await disconnect()
            // Keep messaging available when the optional calling backend is not configured yet.
            // The call buttons offer retry without interrupting messaging at sign-in.
        }
    }

    func startCall(to partner: User, video: Bool) {
        guard let viewModel, let userID = connectedUserID, client != nil else {
            errorMessage = "Calling isn't connected yet. Please try again."
            return
        }
        guard viewModel.callingState == .idle else { return }
        if viewModel.callSettings.videoOn != video { viewModel.toggleCameraEnabled() }
        viewModel.startCall(
            callType: "default",
            callId: UUID().uuidString,
            members: [Member(userId: userID), Member(user: CallingUser(id: partner.id, name: partner.name))],
            ring: true,
            video: video
        )
    }

    private func disconnect() async {
        isConnecting = false
        tokenObservation?.cancel()
        tokenObservation = nil
        viewModel?.hangUp()
        viewModel = nil
        // Stream's CallKit service reads its global client when initialized.
        // Do not touch it before a client has actually been configured.
        if client != nil { callKitAdapter.streamVideo = nil }
        let oldClient = client
        let oldToken = registeredVoIPToken
        client = nil
        connectedUserID = nil
        registeredVoIPToken = ""
        if let oldClient {
            if !oldToken.isEmpty { try? await oldClient.deleteDevice(id: oldToken) }
            await oldClient.disconnect()
        }
    }

    private static func credentials(for userID: String) async throws -> (apiKey: String, token: String) {
        guard Auth.auth().currentUser?.uid == userID else { throw CancellationError() }
        let result = try await Functions.functions().httpsCallable("callingToken").call()
        guard let data = result.data as? [String: Any],
              let apiKey = data["apiKey"] as? String, !apiKey.isEmpty,
              let token = data["token"] as? String, !token.isEmpty,
              Auth.auth().currentUser?.uid == userID else {
            throw URLError(.userAuthenticationRequired)
        }
        return (apiKey, token)
    }
}

struct TalkrCallOverlay: View {
    @ObservedObject var viewModel: CallViewModel

    var body: some View {
        CallContainer(viewFactory: DefaultViewFactory.shared, viewModel: viewModel)
    }
}

struct CallButtons: View {
    let partner: User
    @Environment(CallingService.self) private var calling
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        HStack(spacing: 20) {
            Button { calling.startCall(to: partner, video: false) } label: {
                Image(systemName: "phone")
            }
            .accessibilityLabel("Voice call \(partner.name)")
            Button { calling.startCall(to: partner, video: true) } label: {
                Image(systemName: "video")
            }
            .accessibilityLabel("Video call \(partner.name)")
        }
        .font(.title3)
        .foregroundStyle(theme.secondaryTextColor)
        .disabled(calling.isConnecting)
    }
}
