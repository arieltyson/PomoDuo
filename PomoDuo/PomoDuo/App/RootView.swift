//
//  RootView.swift
//  PomoDuo
//
//  Created by Ariel Tyson on 2/14/26.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("PomoDuo", systemImage: "timer")
            } description: {
                Text("Session dashboard is coming soon.")
            }
            .navigationTitle("PomoDuo")
        }
    }
}
