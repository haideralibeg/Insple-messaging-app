import SwiftUI

// MARK: - Router
struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        switch auth.screen {
        case .login:          LoginView()
        case .signUpPhone:    SignUpPhoneView()
        case .signUpOTP:      SignUpOTPView()
        case .signUpPassword: SignUpPasswordView()
        }
    }
}

// MARK: - LOGIN SCREEN (Default)
struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @State private var phoneNumber  = ""
    @State private var password     = ""
    @State private var showPassword = false

    private var digitsOnly: String { phoneNumber.filter { $0.isNumber } }
    private var isReady: Bool { digitsOnly.count == 10 && !password.isEmpty }

    var body: some View {
        VStack {
            Spacer()

            Text("Talkr")
                .font(.system(size: 36, weight: .bold))
                .padding(.bottom, 8)
            Text("Stay connected your way")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 50)

            VStack(spacing: 14) {
                // Phone field
                HStack(spacing: 8) {
                    Text("🇺🇸 +1")
                        .foregroundColor(.primary)
                        .padding(.leading, 16)
                    TextField("Phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .onChange(of: phoneNumber) { _, val in
                            let d = val.filter { $0.isNumber }
                            if d.count <= 10 { phoneNumber = d }
                        }
                }
                .padding(.vertical, 14)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1))

                // Password field
                HStack {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1))
            }
            .padding(.horizontal, 30)

            if let err = auth.errorMessage {
                Text(err)
                    .font(.caption).foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30).padding(.top, 6)
            }

            // Login button
            Button(action: {
                Task { await auth.login(phoneNumber: digitsOnly, password: password) }
            }) {
                if auth.isLoading {
                    ProgressView().tint(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.black).clipShape(Capsule())
                } else {
                    Text("Log In")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(isReady ? Color.black : Color.gray)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 30).padding(.top, 20)
            .disabled(!isReady || auth.isLoading)

            // Divider
            HStack {
                Rectangle().fill(Color(.systemGray5)).frame(height: 1)
                Text("or").font(.subheadline).foregroundColor(.secondary).padding(.horizontal, 10)
                Rectangle().fill(Color(.systemGray5)).frame(height: 1)
            }
            .padding(.vertical, 20).padding(.horizontal, 40)

            // Create account button
            Button(action: { auth.goToSignUp() }) {
                Text("Create new account")
                    .font(.headline).foregroundColor(.black)
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.clear)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

// MARK: - SIGN UP: Phone Entry
struct SignUpPhoneView: View {
    @EnvironmentObject var auth: AuthService
    @State private var phoneNumber = ""
    @State private var displayName = ""

    private var digitsOnly: String { phoneNumber.filter { $0.isNumber } }
    private var isReady: Bool { digitsOnly.count == 10 && !displayName.isEmpty }

    var body: some View {
        VStack {
            // Back button
            HStack {
                Button(action: { auth.goBackToLogin() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back to Login")
                    }
                    .font(.subheadline).foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 30).padding(.top, 20)

            Spacer()

            Text("Talkr")
                .font(.system(size: 36, weight: .bold))
                .padding(.bottom, 8)
            Text("Create your account")
                .font(.subheadline).foregroundColor(.secondary)
                .padding(.bottom, 40)

            VStack(spacing: 14) {
                TextField("Display name", text: $displayName)
                    .textContentType(.name)
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1))

                HStack(spacing: 8) {
                    Text("🇺🇸 +1")
                        .foregroundColor(.primary)
                        .padding(.leading, 16)
                    TextField("Phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .onChange(of: phoneNumber) { _, val in
                            let d = val.filter { $0.isNumber }
                            if d.count <= 10 { phoneNumber = d }
                        }
                }
                .padding(.vertical, 14)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1))
            }
            .padding(.horizontal, 30)

            if let err = auth.errorMessage {
                Text(err).font(.caption).foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30).padding(.top, 6)
            }

            Button(action: {
                Task { await auth.signUpSendOTP(phoneNumber: digitsOnly, displayName: displayName) }
            }) {
                if auth.isLoading {
                    ProgressView().tint(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.black).clipShape(Capsule())
                } else {
                    Text("Send Verification Code")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(isReady ? Color.black : Color.gray)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 30).padding(.top, 20)
            .disabled(!isReady || auth.isLoading)

            Spacer()
        }
    }
}

// MARK: - SIGN UP: OTP Verification
struct SignUpOTPView: View {
    @EnvironmentObject var auth: AuthService
    @State private var otpCode = ""

    var body: some View {
        VStack {
            HStack {
                Button(action: { auth.screen = .signUpPhone }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline).foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 30).padding(.top, 20)

            Spacer()

            Text("Talkr")
                .font(.system(size: 36, weight: .bold))
                .padding(.bottom, 8)

            VStack(spacing: 6) {
                Text("Verify your number")
                    .font(.headline).fontWeight(.bold)
                Text("Enter the 6-digit code we sent you")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            .padding(.bottom, 32)

            // OTP display boxes
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(i < otpCode.count ? Color.black : Color(.systemGray4), lineWidth: 2)
                            .frame(width: 48, height: 56)
                        if i < otpCode.count {
                            let idx = otpCode.index(otpCode.startIndex, offsetBy: i)
                            Text(String(otpCode[idx])).font(.title2).fontWeight(.bold)
                        }
                    }
                }
            }
            .padding(.bottom, 16)

            TextField("Enter 6-digit code", text: $otpCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title3)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1))
                .padding(.horizontal, 30)
                .onChange(of: otpCode) { _, val in
                    otpCode = String(val.filter { $0.isNumber }.prefix(6))
                }

            if let err = auth.errorMessage {
                Text(err).font(.caption).foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30).padding(.top, 8)
            }

            Button(action: { auth.signUpVerifyOTP(code: otpCode) }) {
                Text("Verify")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(otpCode.count == 6 ? Color.black : Color.gray)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 30).padding(.top, 20)
            .disabled(otpCode.count < 6)

            Spacer()
        }
    }
}

// MARK: - SIGN UP: Create Password
struct SignUpPasswordView: View {
    @EnvironmentObject var auth: AuthService
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var showPassword    = false

    private var requirements: [PasswordRequirement] { passwordRequirements(for: password) }
    private var passwordsMatch: Bool { password == confirmPassword && !confirmPassword.isEmpty }
    private var isReady: Bool { isPasswordStrong(password) && passwordsMatch }

    var body: some View {
        VStack {
            HStack {
                Button(action: { auth.goBackToOTP() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.subheadline).foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 30).padding(.top, 20)

            Spacer()

            Text("Talkr")
                .font(.system(size: 36, weight: .bold))
                .padding(.bottom, 8)

            VStack(spacing: 6) {
                Text("Create a password")
                    .font(.headline).fontWeight(.bold)
                Text("You'll use this to log in next time")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            .padding(.bottom, 24)

            VStack(spacing: 14) {
                // Password
                HStack {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        password.isEmpty ? Color(.systemGray4)
                            : isPasswordStrong(password) ? Color.green : Color.orange,
                        lineWidth: 1.5
                    ))

                // Requirements checklist
                if !password.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(requirements, id: \.label) { req in
                            HStack(spacing: 8) {
                                Image(systemName: req.isMet ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(req.isMet ? .green : Color(.systemGray3))
                                    .font(.caption)
                                Text(req.label)
                                    .font(.caption)
                                    .foregroundColor(req.isMet ? .primary : Color(.systemGray))
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                }

                // Confirm password
                HStack {
                    if showPassword {
                        TextField("Confirm password", text: $confirmPassword)
                    } else {
                        SecureField("Confirm password", text: $confirmPassword)
                    }
                    if !confirmPassword.isEmpty {
                        Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(passwordsMatch ? .green : .red)
                    }
                }
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        confirmPassword.isEmpty ? Color(.systemGray4)
                            : passwordsMatch ? Color.green : Color.red,
                        lineWidth: 1.5
                    ))
            }
            .padding(.horizontal, 30)
            .animation(.easeInOut(duration: 0.2), value: password.isEmpty)

            if let err = auth.errorMessage {
                Text(err).font(.caption).foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30).padding(.top, 6)
            }

            Button(action: {
                Task { await auth.signUpCreateAccount(password: password, confirmPassword: confirmPassword) }
            }) {
                if auth.isLoading {
                    ProgressView().tint(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.black).clipShape(Capsule())
                } else {
                    Text("Create Account")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(isReady ? Color.black : Color.gray)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 30).padding(.top, 20)
            .disabled(!isReady || auth.isLoading)

            Spacer()
        }
    }
}

// MARK: - Password Strength Helpers
struct PasswordRequirement {
    let label: String
    let isMet: Bool
}

func passwordRequirements(for password: String) -> [PasswordRequirement] {
    [
        PasswordRequirement(label: "At least 8 characters",        isMet: password.count >= 8),
        PasswordRequirement(label: "One uppercase letter (A-Z)",   isMet: password.range(of: "[A-Z]", options: .regularExpression) != nil),
        PasswordRequirement(label: "One lowercase letter (a-z)",   isMet: password.range(of: "[a-z]", options: .regularExpression) != nil),
        PasswordRequirement(label: "One number (0-9)",             isMet: password.range(of: "[0-9]", options: .regularExpression) != nil),
        PasswordRequirement(label: "One special character (!@#$)", isMet: password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil),
    ]
}

func isPasswordStrong(_ password: String) -> Bool {
    passwordRequirements(for: password).allSatisfy { $0.isMet }
}
