import SwiftUI
import WidgetData
import WidgetKit

struct AllProvidersWidget: Widget {
    let kind = "AllProvidersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: AllProvidersTimelineProvider()
        ) { entry in
            AllProvidersView(entry: entry)
        }
        .configurationDisplayName("All Providers")
        .description("Overview of all AI provider quotas")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
