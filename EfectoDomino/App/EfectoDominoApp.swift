import SwiftUI

@main
struct EfectoDominoApp: App {
    @State private var store = ObraStore()

    var body: some Scene {
        WindowGroup {
            RaizView()
                .environment(store)
        }
    }
}
