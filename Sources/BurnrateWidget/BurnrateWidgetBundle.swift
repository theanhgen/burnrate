import SwiftUI
import WidgetKit

@main
struct BurnrateWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatusRingWidget()
        AllProvidersWidget()
    }
}
