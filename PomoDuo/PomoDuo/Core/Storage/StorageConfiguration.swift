//
//  StorageConfiguration.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import Foundation
import SwiftData

/// Defines the SwiftData schema and provides the shared model container.
enum StorageConfiguration {
    /// All SwiftData model types used by PomoDuo.
    static let modelTypes: [any PersistentModel.Type] = [
        TimerConfiguration.self,
        CompletedSession.self
    ]

    /// All SwiftData model types used by PomoDuo.
    static let schema = Schema(modelTypes)

    /// Creates the shared model container.
    /// Call this once at app launch if manual container injection is needed.
    static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "PomoDuo",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
