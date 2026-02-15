//
//  RootView.swift
//  PomoDuo
//
//  Created by Ariel Tyson on 2/14/26.
//

import SwiftUI

/// Root app shell using a bottom tab bar.
///
/// On iOS 26, the native Tab API renders with the system's Liquid Glass look.
struct RootView: View {
    @State private var selectedTab = AppTab.timer

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.timer.title, systemImage: AppTab.timer.systemImage, value: .timer) {
                NavigationStack {
                    TimerView()
                }
            }

            Tab(AppTab.partner.title, systemImage: AppTab.partner.systemImage, value: .partner) {
                NavigationStack {
                    PartnerView()
                }
            }

            Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(AppColors.lavender)
    }
}
