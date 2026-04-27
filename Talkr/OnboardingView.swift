/*
 =========================================
 FILE: OnboardingView.swift
 
 SUMMARY:
 The initial authentication screen displayed to logged-out users. Handles login
 logic and interfaces with Firebase Auth.
 
 CHANGES IN THIS SESSION:
 - Temporarily swapped the mock phone number UI flow for a functional Firebase Email/Password login UI.
 - Added state variables to handle errors and securely capture credentials.
 - Added `loginWithFirebase()` to authenticate and automatically route users to the Inbox.
 =========================================
 */

import SwiftUI
import FirebaseAuth // Added for sign in

struct OnboardingView: View {
    @Binding var isLoggedIn: Bool
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("Talkr")
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 60)
            
            VStack(spacing: 8) {
                Text("Welcome Back")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Log in to start texting")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.bottom, 10)
            }
            
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
                .padding(.horizontal, 30)
                .padding(.bottom, 10)
            
            SecureField("Password", text: $password)
                .padding()
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            
            Button(action: loginWithFirebase) {
                Text("Log In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
    
    private func loginWithFirebase() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else {
                // Success! The AuthService listener in Models.swift will automatically catch this 
                // and push you into the InboxView!
            }
        }
    }
}
