//
//  ProfileSetupView.swift
//  Docket
//
//  First-launch onboarding: restore an existing iCloud identity or create the
//  participant's first UserProfile.
//

import SwiftUI
import UIKit

struct ProfileSetupView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.docketSurfacePalette) private var palette

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSaving = false
    @State private var isRestoring = false
    @State private var cloudMessage: String?
    @State private var cloudMessageIsError = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case firstName
        case lastName
    }

    private var isBusy: Bool { isSaving || isRestoring }
    private var canSave: Bool { !firstName.trimmed.isEmpty && !isBusy }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(DocketTheme.boardBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DocketTheme.ProfileSetup.sectionSpacing) {
                    hero
                    iCloudSection
                    newProfileCard
                }
                .frame(maxWidth: DocketTheme.ProfileSetup.maxContentWidth)
                .padding(.horizontal, DocketTheme.ProfileSetup.horizontalPadding)
                .padding(.top, DocketTheme.ProfileSetup.topPadding)
                .padding(.bottom, DocketTheme.ProfileSetup.bottomPadding)
                .frame(maxWidth: .infinity)
            }
        }
        .tint(DocketTheme.brass)
    }

    private var hero: some View {
        VStack(spacing: DocketTheme.ProfileSetup.heroSpacing) {
            Image(systemName: "pin.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DocketTheme.brass)
                .rotationEffect(.degrees(-12))

            Text("Docket")
                .font(DocketTheme.ProfileSetup.titleFont)
                .foregroundStyle(DocketTheme.ProfileSetup.titleColor)

            Text("Bring your boards along, or start pinning something new.")
                .font(DocketTheme.ProfileSetup.bodyFont)
                .foregroundStyle(DocketTheme.ProfileSetup.bodyColor)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var iCloudSection: some View {
        VStack(spacing: 12) {
            Button(action: restoreFromICloud) {
                HStack(spacing: 10) {
                    if isRestoring {
                        ProgressView()
                    } else {
                        Image(systemName: "icloud.fill")
                    }
                    Text(isRestoring ? "Looking for your boards…" : "Continue with iCloud")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .docketPrimaryActionStyle()
            .disabled(isBusy)

            Text("Already use Docket on another device? We’ll restore the profiles and boards tied to this iCloud account.")
                .font(.caption)
                .foregroundStyle(DocketTheme.ProfileSetup.bodyColor)
                .multilineTextAlignment(.center)

            if let cloudMessage {
                Label(
                    cloudMessage,
                    systemImage: cloudMessageIsError
                        ? "exclamationmark.triangle.fill"
                        : "info.circle.fill"
                )
                .font(DocketTheme.ProfileSetup.messageFont)
                .foregroundStyle(
                    cloudMessageIsError
                        ? DocketTheme.ProfileSetup.errorColor
                        : DocketTheme.ProfileSetup.messageColor
                )
                .multilineTextAlignment(.center)
            }
        }
    }

    private var newProfileCard: some View {
        VStack(alignment: .leading, spacing: DocketTheme.ProfileSetup.paperSpacing) {
            VStack(alignment: .leading, spacing: 5) {
                Text("New to Docket?")
                    .font(DocketTheme.ProfileSetup.headingFont)
                    .foregroundStyle(DocketTheme.ProfileSetup.paperTitleColor)
                Text("Make a profile for the name shown beside anything you pin.")
                    .font(DocketTheme.ProfileSetup.bodyFont)
                    .foregroundStyle(DocketTheme.ProfileSetup.paperBodyColor)
            }

            profileField(
                title: "FIRST NAME",
                placeholder: "First name",
                text: $firstName,
                contentType: .givenName,
                field: .firstName,
                submitLabel: .next
            )

            profileField(
                title: "LAST NAME",
                placeholder: "Last name (optional)",
                text: $lastName,
                contentType: .familyName,
                field: .lastName,
                submitLabel: .done
            )

            Button(action: createProfile) {
                HStack(spacing: 9) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    Text(isSaving ? "Creating profile…" : "Create profile")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DocketTheme.ink)
            .disabled(!canSave)

            if let error = store.errorMessage, cloudMessage == nil, !isRestoring {
                Text(error)
                    .font(DocketTheme.ProfileSetup.messageFont)
                    .foregroundStyle(Color.red.opacity(0.82))
            }
        }
        .padding(DocketTheme.ProfileSetup.paperPadding)
        .background(
            palette.raisedPaper,
            in: RoundedRectangle(
                cornerRadius: DocketTheme.ProfileSetup.paperCornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(DocketTheme.brass)
                .frame(
                    width: DocketTheme.ProfileSetup.pinSize,
                    height: DocketTheme.ProfileSetup.pinSize
                )
                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                .offset(y: DocketTheme.ProfileSetup.pinOffsetY)
        }
        .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
    }

    private func profileField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType,
        field: Field,
        submitLabel: SubmitLabel
    ) -> some View {
        VStack(alignment: .leading, spacing: DocketTheme.ProfileSetup.fieldSpacing) {
            Text(title)
                .font(DocketTheme.ProfileSetup.labelFont)
                .tracking(1.1)
                .foregroundStyle(DocketTheme.ProfileSetup.paperBodyColor)

            TextField(placeholder, text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(.words)
                .submitLabel(submitLabel)
                .focused($focusedField, equals: field)
                .onSubmit {
                    if field == .firstName {
                        focusedField = .lastName
                    } else {
                        createProfile()
                    }
                }
                .padding(DocketTheme.ProfileSetup.fieldPadding)
                .background(
                    DocketTheme.ProfileSetup.fieldBackground,
                    in: RoundedRectangle(
                        cornerRadius: DocketTheme.ProfileSetup.fieldCornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DocketTheme.ProfileSetup.fieldCornerRadius,
                        style: .continuous
                    )
                    .stroke(DocketTheme.ProfileSetup.fieldBorder, lineWidth: 1)
                }
        }
    }

    private func restoreFromICloud() {
        guard !isBusy else { return }
        focusedField = nil
        cloudMessage = nil
        cloudMessageIsError = false
        isRestoring = true
        Task {
            let result = await store.restoreFromICloud()
            switch result {
            case .restored:
                break // ContentView advances to the restored board.
            case .notFound:
                cloudMessage = "No existing Docket profile was found for this iCloud account. Create one below to get started."
            case .failed(let message):
                cloudMessage = message
                cloudMessageIsError = true
            }
            isRestoring = false
        }
    }

    private func createProfile() {
        guard canSave else { return }
        cloudMessage = nil
        focusedField = nil
        isSaving = true
        Task {
            _ = await store.createProfile(
                firstName: firstName.trimmed,
                lastName: lastName.trimmed
            )
            isSaving = false
        }
    }
}
