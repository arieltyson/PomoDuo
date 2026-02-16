//
//  PartnerView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI

/// Root view for the Partner tab.
///
/// The pairing flow requires an authenticated identity so partner actions can
/// be attributed to a stable user ID. When a paired session is active, this
/// view switches to ``ActivePairedSessionView``.
struct PartnerView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(SessionManager.self) private var sessionManager

    @State private var pairingViewModel = PairingViewModel()
    @State private var sessionViewModel: PartnerSessionViewModel?
    @State private var isShowingCodeSheet = false

    var body: some View {
        Group {
            if authManager.isSignedIn {
                if let sessionViewModel {
                    SignedInPartnerContent(
                        pairingViewModel: pairingViewModel,
                        sessionViewModel: sessionViewModel,
                        isShowingCodeSheet: $isShowingCodeSheet
                    )
                } else {
                    ProgressView("Preparing Partner Session…")
                }
            } else {
                UnauthenticatedPartnerView(authManager: authManager)
            }
        }
        .navigationTitle("Partner")
        .sheet(isPresented: $isShowingCodeSheet) {
            CodeEntrySheet(viewModel: pairingViewModel)
        }
        .task {
            if sessionViewModel == nil {
                sessionViewModel = PartnerSessionViewModel(sessionManager: sessionManager)
            }
        }
        .task(id: authManager.isSignedIn) {
            if authManager.isSignedIn {
                await pairingViewModel.checkExistingPairing()
            } else {
                isShowingCodeSheet = false
                pairingViewModel.resetForSignedOut()
                sessionViewModel?.reset()
            }
        }
    }
}

private struct SignedInPartnerContent: View {
    let pairingViewModel: PairingViewModel
    let sessionViewModel: PartnerSessionViewModel
    @Binding var isShowingCodeSheet: Bool

    var body: some View {
        if sessionViewModel.hasActiveSession,
           let session = sessionViewModel.activeSession,
           case let .paired(partner) = pairingViewModel.pairingState {
            ActivePairedSessionView(
                session: session,
                partner: partner,
                viewModel: sessionViewModel
            )
        } else {
            PairingFlowContent(
                viewModel: pairingViewModel,
                sessionViewModel: sessionViewModel,
                isShowingCodeSheet: $isShowingCodeSheet
            )
        }
    }
}

private struct PairingFlowContent: View {
    let viewModel: PairingViewModel
    let sessionViewModel: PartnerSessionViewModel
    @Binding var isShowingCodeSheet: Bool

    var body: some View {
        switch viewModel.pairingState {
        case .unpaired:
            UnpairedView(
                onGenerateCode: {
                    Task {
                        await viewModel.generateCode()
                    }
                },
                onEnterCode: {
                    isShowingCodeSheet = true
                }
            )
        case let .waitingForPartner(code):
            WaitingForPartnerView(
                code: code,
                onCancel: {
                    viewModel.cancelWaiting()
                }
            )
        case .joining:
            JoiningView()
        case let .paired(partner):
            PairedPartnerView(
                partner: partner,
                sessionViewModel: sessionViewModel,
                onUnpair: {
                    Task {
                        await viewModel.unpair()
                    }
                }
            )
        case let .error(message):
            PairingErrorView(
                message: message,
                onRetry: {
                    viewModel.dismissError()
                }
            )
        }
    }
}

private struct UnauthenticatedPartnerView: View {
    let authManager: AuthManager

    var body: some View {
        ContentUnavailableView {
            Label("Sign In Required", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text("Sign in to pair with a study partner.")
        } actions: {
            Button("Sign In as Guest", systemImage: "person.crop.circle.badge.plus") {
                Task {
                    await authManager.signInAnonymously()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.lavender)
            .disabled(authManager.isLoading)
        }
    }
}
