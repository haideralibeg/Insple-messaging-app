import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class PhoneAuthentication {
    var phoneNumber = ""
    var displayName = ""
    var code = ""
    private(set) var verificationID: String?
    private(set) var isLoading = false
    private(set) var resendAvailableAt = Date.distantPast
    var errorMessage: String?
    var completed = false
    private var linkingUserID: String?

    static func normalizedNumber(_ input: String) -> String? {
        let number = input.filter { !" ()-.".contains($0) }
        guard number.range(of: #"^\+[1-9][0-9]{6,14}$"#, options: .regularExpression) != nil else { return nil }
        return number
    }

    func sendCode(linking: Bool) async {
        guard !isLoading, Date() >= resendAvailableAt else { return }
        guard let number = Self.normalizedNumber(phoneNumber) else {
            errorMessage = "Enter your phone number with its country code, such as +1 312 555 0123."
            return
        }
        if linking && Auth.auth().currentUser == nil {
            errorMessage = "Sign in to your existing account first."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let userID = linking ? Auth.auth().currentUser?.uid : nil
            let identifier = try await PhoneAuthProvider.provider().verifyPhoneNumber(number, uiDelegate: nil)
            verificationID = identifier
            linkingUserID = userID
            code = ""
            resendAvailableAt = Date().addingTimeInterval(60)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verify(linking: Bool) async {
        guard !isLoading, let verificationID, code.count == 6 else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        if !linking { AuthService.shared.isCompletingPhoneSignIn = true }
        do {
            let credential = PhoneAuthProvider.provider().credential(
                withVerificationID: verificationID, verificationCode: code
            )
            let user: FirebaseAuth.User
            if linking {
                guard let existing = Auth.auth().currentUser, existing.uid == linkingUserID else {
                    errorMessage = "Your session changed. Sign in again before adding a number."
                    return
                }
                user = try await existing.link(with: credential).user
            } else {
                user = try await Auth.auth().signIn(with: credential).user
            }
            // Never use a phone number as the database identity or publish it to the user directory.
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !linking, user.displayName == nil, !name.isEmpty {
                let request = user.createProfileChangeRequest()
                request.displayName = name
                try await request.commitChanges()
                try await Firestore.firestore().collection("users").document(user.uid)
                    .setData(["id": user.uid, "name": name], merge: true)
                AuthService.shared.currentUser?.name = name
            }
            completed = true
        } catch {
            errorMessage = error.localizedDescription
        }
        if !linking {
            AuthService.shared.isCompletingPhoneSignIn = false
            await AuthService.shared.refreshSession()
        }
    }

    func fillLocalCode() async {
        #if DEBUG
        guard LocalDevelopment.usesEmulators, !isLoading, let verificationID else { return }
        guard let url = URL(string: "http://127.0.0.1:9099/emulator/v1/projects/demo-talkr/verificationCodes") else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            struct Entry: Decodable {
                let sessionInfo: String
                let code: String
            }
            struct Response: Decodable {
                let verificationCodes: [Entry]
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let result = try JSONDecoder().decode(Response.self, from: data)
            guard let entry = result.verificationCodes.first(where: { $0.sessionInfo == verificationID }) else {
                errorMessage = "This test code is no longer available. Request a new code."
                return
            }
            code = entry.code
        } catch {
            errorMessage = "Cannot reach the local test service. Check that the emulators are running on your Mac."
        }
        #endif
    }

    func changeNumber() {
        verificationID = nil
        code = ""
        errorMessage = nil
    }
}

struct PhoneAuthenticationView: View {
    var linking = false
    @Environment(\.dismiss) private var dismiss
    @State private var model = PhoneAuthentication()
    @State private var showEmailLogin = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Talkr")
                    .font(.system(size: 36, weight: .bold))
                Text(linking ? "Add a phone number" : "Stay connected your way")
                    .foregroundStyle(.secondary)
                if LocalDevelopment.usesEmulators {
                    Text("Local testing · No SMS is sent")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if model.verificationID == nil {
                    if LocalDevelopment.usesEmulators && !linking {
                        HStack {
                            Button("Test account 1") {
                                model.phoneNumber = "+15555550101"
                                model.displayName = "Alice Test"
                            }
                            Button("Test account 2") {
                                model.phoneNumber = "+15555550102"
                                model.displayName = "Bob Test"
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isLoading)
                    }
                    if !linking {
                        TextField("Display name (for new accounts)", text: $model.displayName)
                            .textContentType(.name)
                            .phoneEntryStyle()
                    }
                    TextField("Phone number (+country code)", text: $model.phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .phoneEntryStyle()
                    Text(LocalDevelopment.usesEmulators ? "Choose a test account, request a code, then tap Fill test code on the next screen." : "We'll send a verification code by SMS. Standard message rates may apply. Your number is sent to Google for authentication and abuse prevention.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(ceil(model.resendAvailableAt.timeIntervalSince(context.date))))
                        Button(remaining > 0 ? "Send code in \(remaining)s" : "Send verification code") {
                            Task { await model.sendCode(linking: linking) }
                        }
                        .buttonStyle(PhonePrimaryButtonStyle())
                        .disabled(model.isLoading || model.phoneNumber.isEmpty || remaining > 0)
                    }
                } else {
                    Text("Verify your phone number").font(.headline)
                    Text("Enter the 6-digit code sent to \(model.phoneNumber)")
                        .font(.subheadline)
                    TextField("6-digit code", text: $model.code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .phoneEntryStyle()
                        .onChange(of: model.code) { _, value in
                            model.code = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                        }
                    if LocalDevelopment.usesEmulators {
                        Button("Fill test code") {
                            Task { await model.fillLocalCode() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isLoading)
                    }
                    Button("Verify and continue") {
                        Task { await model.verify(linking: linking) }
                    }
                    .buttonStyle(PhonePrimaryButtonStyle())
                    .disabled(model.isLoading || model.code.count != 6)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(ceil(model.resendAvailableAt.timeIntervalSince(context.date))))
                        Button(remaining > 0 ? "Resend code in \(remaining)s" : "Resend code") {
                            Task { await model.sendCode(linking: linking) }
                        }
                        .disabled(model.isLoading || remaining > 0)
                    }
                    Button("Change phone number") { model.changeNumber() }
                        .disabled(model.isLoading)
                }
                if model.isLoading { ProgressView() }
                if let error = model.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if !linking {
                    Button("Sign in to an existing email account") { showEmailLogin = true }
                    Text("Already have an account? Sign in with email first, then add your number from your profile menu to keep your conversations.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Cancel") { dismiss() }.disabled(model.isLoading)
                }
            }
            .padding(30)
            .padding(.top, 60)
            .multilineTextAlignment(.center)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showEmailLogin) { LoginView() }
        .onChange(of: model.completed) { _, completed in
            if completed { dismiss() }
        }
    }
}

private struct PhonePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}

private extension View {
    func phoneEntryStyle() -> some View {
        padding()
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4)))
    }
}
