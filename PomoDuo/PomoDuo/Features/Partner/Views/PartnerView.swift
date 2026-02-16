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
/// be attributed to a stable user ID.
struct PartnerView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = PairingViewModel()
    @State private var isShowingCodeSheet = false

    var body: some View {
        Group {
            if authManager.isSignedIn {
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
            } else {
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
        .navigationTitle("Partner")
        .sheet(isPresented: $isShowingCodeSheet) {
            CodeEntrySheet(viewModel: viewModel)
        }
        .task(id: authManager.isSignedIn) {
            if authManager.isSignedIn {
                await viewModel.checkExistingPairing()
            } else {
                isShowingCodeSheet = false
                viewModel.resetForSignedOut()
            }
        }
    }
}
