import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: TalkrUser?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var isLoading = false

    enum AuthScreen {
        case login           // default screen
        case signUpPhone     // new user enters phone + name
        case signUpOTP       // new user verifies OTP
        case signUpPassword  // new user creates password
    }
    @Published var screen: AuthScreen = .login

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?

    // Held across sign-up steps
    private var pendingPhone = ""
    private var pendingName  = ""
    private var pendingEmail: String { "\(pendingPhone)@talkr.app" }

    private init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, fbUser in
            guard let self else { return }
            if let fbUser {
                self.isAuthenticated = true
                self.listenToProfile(uid: fbUser.uid)
            } else {
                self.isAuthenticated = false
                self.currentUser = nil
                self.userListener?.remove()
            }
        }
    }

    // MARK: - LOGIN (returning user)
    func login(phoneNumber: String, password: String) async {
        isLoading = true
        errorMessage = nil

        let digits = phoneNumber.filter { $0.isNumber }
        guard digits.count == 10 else {
            errorMessage = "Please enter a valid 10-digit phone number."
            isLoading = false
            return
        }

        let email = "\(digits)@talkr.app"
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            // isAuthenticated flips via auth state listener → ContentView shows InboxView
        } catch {
            errorMessage = "Incorrect phone number or password. Please try again."
        }
        isLoading = false
    }

    // MARK: - SIGN UP Step 1: Validate phone + check not already registered
    func signUpSendOTP(phoneNumber: String, displayName: String) async {
        isLoading = true
        errorMessage = nil

        let digits = phoneNumber.filter { $0.isNumber }
        guard digits.count == 10 else {
            errorMessage = "Please enter a valid 10-digit phone number."
            isLoading = false
            return
        }

        pendingPhone = digits
        pendingName  = displayName.isEmpty ? "User" : displayName

        // Check if account already exists
        let methods = (try? await Auth.auth().fetchSignInMethods(forEmail: pendingEmail)) ?? []
        if !methods.isEmpty {
            errorMessage = "An account with this number already exists. Please log in."
            isLoading = false
            return
        }

        // New user — proceed to OTP
        screen = .signUpOTP
        isLoading = false
    }

    // MARK: - SIGN UP Step 2: Verify OTP
    func signUpVerifyOTP(code: String) {
        let expected = String(pendingPhone.suffix(6))
        if code == expected {
            errorMessage = nil
            screen = .signUpPassword
        } else {
            errorMessage = "Incorrect code. Hint: last 6 digits of your phone number."
        }
    }

    // MARK: - SIGN UP Step 3: Create password + register
    func signUpCreateAccount(password: String, confirmPassword: String) async {
        guard validatePassword(password, confirm: confirmPassword) else { return }

        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(
                withEmail: pendingEmail,
                password: password
            )
            let uid = result.user.uid
            let userData: [String: Any] = [
                "phoneNumber": pendingPhone,
                "displayName": pendingName,
                "activeMode":  "genz",
                "createdAt":   Timestamp(date: Date())
            ]
            try await db.collection("users").document(uid).setData(userData)
        } catch let err as NSError {
            let code = AuthErrorCode(rawValue: err.code)
            switch code {
            case .emailAlreadyInUse:
                errorMessage = "This phone number is already registered. Please log in instead."
            case .weakPassword:
                errorMessage = "Password is too weak. Please try a stronger one."
            case .networkError:
                errorMessage = "Network error. Check your connection and try again."
            default:
                errorMessage = "Error: \(err.localizedDescription)"
            }
        }
        isLoading = false
    }

    // MARK: - LOGOUT
    func logout() {
        try? Auth.auth().signOut()
        screen       = .login
        pendingPhone = ""
        pendingName  = ""
        errorMessage = nil
    }

    // MARK: - Navigation helpers
    func goToSignUp() {
        errorMessage = nil
        screen = .signUpPhone
    }

    func goBackToLogin() {
        errorMessage = nil
        screen = .login
        pendingPhone = ""
        pendingName  = ""
    }

    func goBackToOTP() {
        errorMessage = nil
        screen = .signUpOTP
    }

    // MARK: - Password Validation
    @discardableResult
    func validatePassword(_ password: String, confirm: String) -> Bool {
        guard password == confirm else {
            errorMessage = "Passwords do not match."; return false
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."; return false
        }
        guard password.range(of: "[A-Z]", options: .regularExpression) != nil else {
            errorMessage = "Add at least one uppercase letter."; return false
        }
        guard password.range(of: "[a-z]", options: .regularExpression) != nil else {
            errorMessage = "Add at least one lowercase letter."; return false
        }
        guard password.range(of: "[0-9]", options: .regularExpression) != nil else {
            errorMessage = "Add at least one number."; return false
        }
        guard password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil else {
            errorMessage = "Add at least one special character (!@#$...)."; return false
        }
        return true
    }

    // MARK: - Theme
    func updateMode(_ mode: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).updateData(["activeMode": mode])
    }

    // MARK: - Live profile listener
    private func listenToProfile(uid: String) {
        userListener?.remove()
        userListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                self?.currentUser = try? snap?.data(as: TalkrUser.self)
            }
    }

    var currentUID: String? { Auth.auth().currentUser?.uid }

    deinit {
        if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) }
        userListener?.remove()
    }
}
