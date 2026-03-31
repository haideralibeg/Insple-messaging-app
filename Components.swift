import SwiftUI

struct TopThemeBar: View {
    var label1: String = "Mode 1"
    var label2: String = "Mode 2"
    @State private var isLabel1Selected: Bool = true
    
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Text("Theme")
                    .fontWeight(.bold)
                
                Button(action: { isLabel1Selected = true }) {
                    Text(label1)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(isLabel1Selected ? .white : .black)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isLabel1Selected ? Color.black : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.black, lineWidth: isLabel1Selected ? 0 : 1)
                        )
                }
                
                Button(action: { isLabel1Selected = false }) {
                    Text(label2)
                        .font(.subheadline)
                        .foregroundColor(!isLabel1Selected ? .white : .black)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(!isLabel1Selected ? Color.black : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.black, lineWidth: !isLabel1Selected ? 0 : 1)
                        )
                }
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.black)
                        .padding(8)
                        .overlay(
                            Circle().stroke(Color.black, lineWidth: 1)
                        )
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

struct AvatarView: View {
    var size: CGFloat = 50
    var showUnreadDot: Bool = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            Circle()
                .fill(Color.black)
                .frame(width: size, height: size)
            
            if showUnreadDot {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: -16) // Stick out to the left margin
            }
        }
        .padding(.leading, showUnreadDot ? 16 : 0)
    }
}
