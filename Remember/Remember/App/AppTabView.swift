import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem {
                    Label(L10n.Tab.search, systemImage: "magnifyingglass")
                }

            SettingsView()
                .tabItem {
                    Label(L10n.Tab.settings, systemImage: "gearshape")
                }
        }
    }
}
