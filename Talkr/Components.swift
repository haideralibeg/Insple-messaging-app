import SwiftUI

struct TopThemeBar: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Text("Theme")
                    .fontWeight(.bold)

                Button(action: { theme.set("genz") }) {
                    Text(theme.label1)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.activeMode == "genz" ? .white : .black)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.activeMode == "genz" ? Color.black : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.black, lineWidth: theme.activeMode == "genz" ? 0 : 1)
                        )
                }

                Button(action: { theme.set("nostalgic") }) {
                    Text(theme.label2)
                        .font(.subheadline)
                        .foregroundColor(theme.activeMode == "nostalgic" ? .white : .black)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.activeMode == "nostalgic" ? Color.black : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.black, lineWidth: theme.activeMode == "nostalgic" ? 0 : 1)
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
                    .offset(x: -16)
            }
        }
        .padding(.leading, showUnreadDot ? 16 : 0)
    }
}
