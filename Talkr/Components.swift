import SwiftUI

// 1. The missing TopThemeBar!
struct TopThemeBar: View {
    var body: some View {
        HStack {
            Text("Talkr")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            // Mock theme toggles
            HStack(spacing: 8) {
                Text("Mode 1")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                
                Text("Mode 2")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .foregroundColor(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

// 2. The AvatarView we just updated
struct AvatarView: View {
    var size: CGFloat = 50
    var showUnreadDot: Bool = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(Color.black)
                .frame(width: size, height: size)
            
            if showUnreadDot {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: -2, y: 2)
            }
        }
    }
}
