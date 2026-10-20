import SwiftUI

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

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var accent: Color { theme.isNostalgic ? RetroPalette.navy : Color(red: 0.66, green: 0.52, blue: 1) }

    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
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
                        Text(String(trimmedName.prefix(1)).uppercased())
                            .font(.system(size: 38, weight: .bold, design: theme.isNostalgic ? .monospaced : .rounded))
                            .foregroundStyle(theme.isNostalgic ? .white : .black)
                            .frame(width: 96, height: 96)
                            .background(accent, in: RoundedRectangle(cornerRadius: theme.isNostalgic ? 2 : 34))
                            .accessibilityLabel("Profile initials")
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
                                .background(theme.backgroundColor, in: RoundedRectangle(cornerRadius: 8))
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
                                .background(theme.backgroundColor, in: RoundedRectangle(cornerRadius: 8))
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
                            .foregroundStyle(theme.isNostalgic ? .white : .black)
                            .background(accent, in: RoundedRectangle(cornerRadius: theme.isNostalgic ? 2 : 16))
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
        .font(.system(.body, design: theme.isNostalgic ? .monospaced : .default))
        .tint(accent)
        .preferredColorScheme(theme.isNostalgic ? .light : .dark)
        .navigationBarHidden(true)
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
            .preferredColorScheme(theme.isNostalgic ? .light : .dark)
        }
        .sheet(isPresented: $showingPreview) {
            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 76)).foregroundStyle(accent)
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
            .preferredColorScheme(theme.isNostalgic ? .light : .dark)
        }
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
