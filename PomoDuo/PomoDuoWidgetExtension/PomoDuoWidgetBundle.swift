import SwiftUI
import WidgetKit

@main
struct PomoDuoWidgetBundle: WidgetBundle {
    var body: some Widget {
        PomoDuoLiveActivity()
        FocusStatsWidget()
    }
}
