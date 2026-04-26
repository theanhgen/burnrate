import CloudSync
import Domain
import SwiftUI
import WidgetKit

@main
struct BurnrateIOSApp: App {
    @State private var viewModel = SnapshotViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ProviderListView(viewModel: viewModel)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
        }
    }
}
