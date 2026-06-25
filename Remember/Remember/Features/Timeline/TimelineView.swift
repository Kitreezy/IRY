import SwiftUI

struct TimelineView: View {
    var body: some View {
        NavigationStack {
            Text(L10n.Timeline.title)
                .navigationTitle(L10n.Timeline.title)
        }
    }
}
