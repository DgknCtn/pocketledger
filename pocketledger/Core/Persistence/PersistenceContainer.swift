import SwiftData

/// Builds the `ModelContainer` for PocketLedger's SwiftData cache.
///
/// SwiftData here is a **cache**, not the app's primary database — Supabase
/// is. This container exists to back `PersistenceActor`; feature code never
/// creates a `ModelContainer` or touches `ModelContext` directly (no
/// `@Query` in feature views — see the Architecture specification).
enum PersistenceContainer {
    static let schema = Schema([
        WalletProfileRecord.self,
        AccountRecord.self,
        TransactionRecord.self,
        CacheMetadataRecord.self,
    ])

    /// The disk-backed store used by the running app.
    static func makeProduction() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return makeContainer(configuration: configuration)
    }

    /// An in-memory store for unit tests and SwiftUI previews — never
    /// touches disk, and each call returns an independent, empty store.
    static func makeInMemory() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return makeContainer(configuration: configuration)
    }

    private static func makeContainer(configuration: ModelConfiguration) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A static, hand-authored schema failing to compile into a
            // container is a programmer error (e.g. a genuinely invalid
            // model), not a runtime condition the app can recover from.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
