import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Label(L10n.Tab.search, systemImage: "magnifyingglass")
                }

            TimelineView()
                .tabItem {
                    Label(L10n.Tab.timeline, systemImage: "clock")
                }

            SettingsView()
                .tabItem {
                    Label(L10n.Tab.settings, systemImage: "gearshape")
                }
        }
    }
}
