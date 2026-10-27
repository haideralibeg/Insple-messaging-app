import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: ChatStore
    @State private var name = ""
    @State private var visibility = "Private"
    @State private var showName = true
    @State private var messageAudience = "Anyone"
    @State private var showingSignOut = false
    @State private var showingPreview = false
    @State private var loaded = false
    @State private var blockedIDs: Set<String> = []
    @State private var showingBlockedPeople = false
    @State private var allowedIDs: Set<String> = []
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isLoadingPhoto = false
    @State private var showingPhotoError = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var accent: Color { theme.isNostalgic ? RetroPalette.navy : Color(red: 0.66, green: 0.52, blue: 1) }

    var body: some View {
        let isNostalgic = theme.isNostalgic
        let currentBackgroundColor = theme.backgroundColor
        ZStack {
            currentBackgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Button { dismiss() } label: {
                            Label("Back", systemImage: "chevron.left")
                                .frame(minHeight: 44)
                        }
                        Spacer()
                        Text("My profile").font(.headline)
                        Spacer()
                        Image(systemName: "person.crop.circle").accessibilityHidden(true)
                    }

                    VStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            profileAvatar
                                .overlay {
                                    if isLoadingPhoto {
                                        RoundedRectangle(cornerRadius: isNostalgic ? 2 : 34)
                                            .fill(.black.opacity(0.4))
                                        ProgressView().tint(.white)
                                    }
                                }
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(isNostalgic ? .white : .black)
                                        .frame(width: 32, height: 32)
                                        .background(accent, in: Circle())
                                        .overlay(Circle().stroke(currentBackgroundColor, lineWidth: 3))
                                        .offset(x: 5, y: 5)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(profileImage == nil ? "Add profile photo" : "Change profile photo")
                        .accessibilityHint("Opens your photo library")
                        Text(profileImage == nil ? "Add profile photo" : "Change profile photo")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(accent)
                        if profileImage != nil {
                            Button("Remove photo", role: .destructive) {
                                selectedPhoto = nil
                                profileImage = nil
                            }
                            .font(.caption)
                        }
                        Text(trimmedName.isEmpty ? "Your profile" : trimmedName)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    section("Personal details", symbol: "person.text.rectangle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display name").font(.subheadline.weight(.medium))
                            TextField("Your name", text: $name)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .padding(12)
                                .background(currentBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
                            if trimmedName.isEmpty {
                                Text("Enter a display name to preview your profile.")
                                    .font(.caption).foregroundStyle(accent)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email").font(.subheadline.weight(.medium))
                            HStack(spacing: 10) {
                                Text(auth.accountEmail ?? "Email unavailable")
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .accessibilityHidden(true)
                            }
                                .foregroundStyle(theme.secondaryTextColor.opacity(0.5))
                                .padding(12)
                                .background(currentBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Email, read only")
                                .accessibilityValue(auth.accountEmail ?? "Email unavailable")
                        }
                    }

                    section("Privacy", symbol: "lock.shield") {
                        Picker("Profile visibility", selection: $visibility) {
                            Text("Open").tag("Open")
                            Text("Private").tag("Private")
                        }
                        .pickerStyle(.segmented)
                        Text(visibility == "Private" ? "Choose which details you would share." : "Your display name is visible to other users.")
                            .font(.footnote).foregroundStyle(theme.secondaryTextColor.opacity(0.65))
                        if visibility == "Private" {
                            Toggle("Share display name", isOn: $showName)
                        }
                        Divider()
                        Picker("Who can message me", selection: $messageAudience) {
                            Text("Anyone").tag("Anyone")
                            Text("Selected people").tag("Selected people")
                        }
                        if messageAudience == "Selected people" {
                            if store.contacts.isEmpty {
                                Text("No people to choose from yet.")
                                    .font(.footnote)
                            }
                            ForEach(store.contacts) { contact in
                                Toggle(contact.displayName, isOn: Binding(
                                    get: { allowedIDs.contains(contact.id) },
                                    set: { selected in
                                        if selected { allowedIDs.insert(contact.id) }
                                        else { allowedIDs.remove(contact.id) }
                                    }
                                ))
                                .accessibilityLabel("Allow messages from \(contact.displayName)")
                            }
                        }
                        Divider()
                        Button { showingBlockedPeople = true } label: {
                            HStack {
                                Label("Blocked Accounts", systemImage: "person.slash")
                                Spacer()
                                Text("\(blockedIDs.count)")
                                Image(systemName: "chevron.right")
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }

                    section("Appearance", symbol: "paintpalette") {
                        Text("Choose your Talkr mode")
                            .font(.subheadline)
                        ForEach(["genz", "nostalgic"], id: \.self) { mode in
                            Button { theme.set(mode) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: mode == "genz" ? "sparkles" : "desktopcomputer")
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(mode == "genz" ? "Gen Z" : "Nostalgic").fontWeight(.semibold)
                                        Text(mode == "genz" ? "Dark canvas. Fresh energy." : "Classic messenger. Familiar feeling.")
                                            .font(.caption).foregroundStyle(theme.secondaryTextColor.opacity(0.65))
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: theme.activeMode == mode ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(accent)
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(theme.activeMode == mode ? .isSelected : [])
                        }
                    }

                    Button { showingPreview = true } label: {
                        Text("Preview profile")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(isNostalgic ? .white : .black)
                            .background(accent, in: RoundedRectangle(cornerRadius: isNostalgic ? 2 : 16))
                    }
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.5 : 1)

                    Button(role: .destructive) { showingSignOut = true } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(theme.secondaryTextColor)
        .font(.system(.body, design: isNostalgic ? .monospaced : .default))
        .tint(accent)
        .preferredColorScheme(isNostalgic ? .light : .dark)
        .navigationBarHidden(true)
        .task(id: selectedPhoto) {
            guard let selectedPhoto else {
                isLoadingPhoto = false
                return
            }
            isLoadingPhoto = true
            defer { isLoadingPhoto = false }
            do {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    if !Task.isCancelled { showingPhotoError = true }
                    return
                }
                guard !Task.isCancelled else { return }
                profileImage = image
            } catch {
                if !Task.isCancelled { showingPhotoError = true }
            }
        }
        .alert("Couldn’t load photo", isPresented: $showingPhotoError) {
            Button("OK", role: .cancel) { selectedPhoto = nil }
        } message: {
            Text("Please try again or choose a different image.")
        }
        .onAppear {
            guard !loaded else { return }
            name = auth.currentUser?.displayName ?? ""
            loaded = true
        }
        .confirmationDialog("Sign out of Talkr?", isPresented: $showingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { auth.logout() }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingBlockedPeople) {
            NavigationStack {
                List {
                    Section("People") {
                        if store.contacts.isEmpty {
                            Text("No people to show.")
                        }
                        ForEach(store.contacts) { contact in
                            Toggle(contact.displayName, isOn: Binding(
                                get: { blockedIDs.contains(contact.id) },
                                set: { selected in
                                    if selected { blockedIDs.insert(contact.id) }
                                    else { blockedIDs.remove(contact.id) }
                                }
                            ))
                            .accessibilityLabel("Block \(contact.displayName)")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(theme.backgroundColor)
                .navigationTitle("Blocked people")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingBlockedPeople = false }
                    }
                }
            }
            .tint(accent)
            .preferredColorScheme(isNostalgic ? .light : .dark)
        }
        .sheet(isPresented: $showingPreview) {
            NavigationStack {
                VStack(spacing: 20) {
                    profileAvatar
                    if visibility == "Open" || showName {
                        Text(trimmedName).font(.title.bold())
                    } else {
                        Text("Name hidden").font(.title2)
                    }
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.backgroundColor)
                .foregroundStyle(theme.secondaryTextColor)
                .navigationTitle("Profile preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingPreview = false }
                    }
                }
            }
            .preferredColorScheme(isNostalgic ? .light : .dark)
        }
    }

    private var profileAvatar: some View {
        ZStack {
            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
            } else {
                accent
                Text(String(trimmedName.prefix(1)).uppercased())
                    .font(.system(size: 38, weight: .bold, design: theme.isNostalgic ? .monospaced : .rounded))
                    .foregroundStyle(theme.isNostalgic ? .white : .black)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: theme.isNostalgic ? 2 : 34))
        .accessibilityLabel(profileImage == nil ? "Profile initials" : "Profile photo")
    }

    private func section<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol)
                .font(.headline).foregroundStyle(accent)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.subtleColor, in: RoundedRectangle(cornerRadius: theme.isNostalgic ? 2 : 20))
        .overlay {
            if theme.isNostalgic {
                Rectangle().stroke(RetroPalette.ink.opacity(0.4), lineWidth: 1)
            }
        }
    }
}

#if DEBUG
#Preview("Profile — Gen Z") {
    PreviewHost { _ in ProfileView() }
}

#Preview("Profile — Nostalgic") {
    PreviewHost(mode: "nostalgic") { _ in ProfileView() }
}
#endif

