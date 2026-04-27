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
    @EnvironmentObject var store: ChatStore // Added access to our live data!
    
    @State private var searchText = ""
    let alphabet: [String] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "#"]
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
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
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search", text: $searchText)
                        Image(systemName: "mic.fill").foregroundColor(.gray)
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
                            .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal)
                
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // WE NOW LOOP OVER REAL USERS!
                        ForEach(store.contacts) { contact in
                            
                            // WHEN YOU TAP A CONTACT, WE OPEN A LIVE CHAT ROOM WITH THEM
                            NavigationLink(destination: ChatView(chat: store.getOrCreateChat(with: contact))) {
                                HStack(spacing: 16) {
                                    AvatarView(size: 50, showUnreadDot: false)
                                    
                                    Text(contact.name) // This will show their email/phone!
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .background(Color.white)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
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
        .onAppear {
            store.fetchContacts() // Fetch real users when screen opens
        }
    }
}
