import SwiftUI

struct ContactsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    let alphabet: [String] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "#"]
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                    .padding(.leading)
                    
                    TopThemeBar()
                }
                
                Text("Contacts")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search", text: $searchText)
                        Image(systemName: "mic.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                    
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.footnote)
                            .foregroundColor(.black)
                            .padding(10)
                            .overlay(
                                Circle().stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(mockContacts) { contact in
                            HStack(spacing: 16) {
                                AvatarView(size: 50, showUnreadDot: false)
                                
                                Text(contact.name)
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color.white)
                        }
                    }
                }
            }
            
            // Alphabet Scrubber
            VStack(spacing: 2) {
                Spacer()
                ForEach(alphabet, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding(.trailing, 8)
            .padding(.vertical)
        }
        .navigationBarHidden(true)
    }
}
