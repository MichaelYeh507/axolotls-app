import SwiftUI
import Combine
/// Switches the whole app between logged-out and logged-in.
struct RootView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        switch session.state {
        case .loading:
            ProgressView()
        case .signedOut:
            AuthFlowView()
        case .signedIn:
            if session.profile == nil {
                ProgressView("Loading your account…")
            } else {
                // TODO (Person B): replace with the real Home page.
                HomePlaceholderView()
            }
        }
    }
}

/// Stand-in so Settings is reachable until Person B's Home page exists.
struct HomePlaceholderView: View {
    @EnvironmentObject var session: AppSession

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Hi, \(session.profile?.displayName ?? "")!").font(.title2.bold())
                Text("Home page goes here (Person B).").foregroundStyle(.secondary)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "person.circle") }
                }
            }
        }
    }
}
