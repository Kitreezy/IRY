import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text(L10n.Settings.title)
                .navigationTitle(L10n.Settings.title)
        }
    }
}
