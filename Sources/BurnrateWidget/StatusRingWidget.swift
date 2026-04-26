import SwiftUI
import WidgetData
import WidgetKit

struct StatusRingWidget: Widget {
    let kind = "StatusRingWidget"

    private static var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium]
        #if os(iOS)
        families += [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
        return families
    }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectProviderIntent.self,
            provider: BurnrateTimelineProvider()
        ) { entry in
            StatusRingView(entry: entry)
        }
        .configurationDisplayName("Quota Ring")
        .description("Shows quota status for a single AI provider")
        .supportedFamilies(Self.supportedFamilies)
    }
}
