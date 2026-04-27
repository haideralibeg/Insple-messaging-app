/*
 =========================================
 FILE: ContactsView.swift
 
 SUMMARY:
 Displays a directory of all available registered users. Allows the logged-in
 user to search, select a contact, and initiate a 1-on-1 chat room.
 
 CHANGES IN THIS SESSION:
 - Removed static `mockContacts` array and replaced it with live `store.contacts`.
 - Added an `onAppear` trigger to fetch real registered users from Firestore.
 - Updated the NavigationLink to generate or open a live 1-on-1 chat room using `store.getOrCreateChat(with:)`.
 =========================================
 */

import SwiftUI

struct ContactsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: ChatStore
    @EnvironmentObject var theme: ThemeManager
    @State private var searchText = ""

    let alphabet = ["A","B","C","D","E","F","G","H","I","J","K","L","M",
                    "N","O","P","Q","R","S","T","U","V","W","X","Y","Z","#"]

    var filteredContacts: [User] {
        searchText.isEmpty ? store.contacts : store.contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 16) {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(theme.secondaryTextColor)
                        }
                        .padding(.leading)
                        TopThemeBar()
                    }

                    Text("Contacts")
                        .font(.largeTitle).fontWeight(.bold)
                        .foregroundColor(theme.secondaryTextColor)
                        .padding(.horizontal)

                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                            TextField("Search", text: $searchText)
                                .foregroundColor(theme.secondaryTextColor)
                            Image(systemName: "mic.fill")
                                .foregroundColor(theme.secondaryTextColor.opacity(0.5))
                        }
                        .padding(.vertical, 10).padding(.horizontal, 12)
                        .background(theme.subtleColor)
                        .clipShape(Capsule())

                        Button(action: {}) {
                            Image(systemName: "plus")
                                .font(.footnote)
                                .foregroundColor(theme.secondaryTextColor)
                                .padding(10)
                                .overlay(Circle().stroke(theme.secondaryTextColor.opacity(0.3), lineWidth: 1))
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredContacts) { contact in
                                NavigationLink(destination: ChatView(chat: store.getOrCreateChat(with: contact))) {
                                    HStack(spacing: 16) {
                                        AvatarView(size: 50, showUnreadDot: false)
                                        Text(contact.name)
                                            .font(.headline)
                                            .foregroundColor(theme.secondaryTextColor)
                                        Spacer()
                                    }
                                    .padding(.vertical, 12).padding(.horizontal)
                                    .background(theme.backgroundColor)
                                    .overlay(Divider().background(theme.subtleColor), alignment: .bottom)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }

                // Alphabet index
                VStack(spacing: 2) {
                    Spacer()
                    ForEach(alphabet, id: \.self) { letter in
                        Text(letter)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.secondaryTextColor.opacity(0.4))
                    }
                    Spacer()
                }
                .padding(.trailing, 8).padding(.vertical)
            }
        }
        .navigationBarHidden(true)
        .animation(.easeInOut(duration: 0.3), value: theme.activeMode)
        .onAppear { store.fetchContacts() }
    }
}
