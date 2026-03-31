import SwiftUI

struct OnboardingView: View {
    @Binding var isLoggedIn: Bool
    @State private var phoneNumber: String = ""
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("Talkr")
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 60)
            
            VStack(spacing: 8) {
                Text("Create an account")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Enter your phone number to sign up for this app")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
            
            TextField("i.e. 555-555-5555", text: $phoneNumber)
                .keyboardType(.numberPad)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            
            Button(action: {
                isLoggedIn = true
            }) {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 30)
            
            HStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
                Text("or")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 40)
            
            Button(action: {
                isLoggedIn = true
            }) {
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
}
