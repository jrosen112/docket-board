//
//  ProfileSetupView.swift
//  Docket
//
//  First-launch onboarding: create the participant's UserProfile.
//

import SwiftUI

struct ProfileSetupView: View {
    @Environment(BoardStore.self) private var store

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSaving = false

    private var canSave: Bool { !firstName.trimmed.isEmpty && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your profile") {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                }

                Section {
                    Button {
                        Task {
                            isSaving = true
                            _ = await store.createProfile(
                                firstName: firstName.trimmed,
                                lastName: lastName.trimmed
                            )
                            isSaving = false
                        }
                    } label: {
                        HStack {
                            Text("Get started")
                            if isSaving {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!canSave)
                }

                if let error = store.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Welcome to Docket")
        }
    }
}
