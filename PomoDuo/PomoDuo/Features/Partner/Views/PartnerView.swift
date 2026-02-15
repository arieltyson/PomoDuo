//
//  PartnerView.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI

/// Root view for the Partner tab.
struct PartnerView: View {
    @State private var viewModel = PairingViewModel()
    @State private var isShowingCodeSheet = false

    var body: some View {
        Group {
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
        }
        .navigationTitle("Partner")
        .sheet(isPresented: $isShowingCodeSheet) {
            CodeEntrySheet(viewModel: viewModel)
        }
        .task {
            await viewModel.checkExistingPairing()
        }
    }
}
