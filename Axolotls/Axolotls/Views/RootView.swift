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
            NavigationStack {
                VStack(spacing: 12) {
                    Text("Hi, \(session.profile?.displayName ?? "")!").font(.title2.bold())
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { SettingsView() } label: { Image(systemName: "person.circle") }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        NavigationLink("New Group") {
                            NewGroupView()
                        }
                    }
                }
                GroupsView() // TODO (Part B): Collapse view if there are a lot of groups
                    .safeAreaInset(edge: .bottom) {
                        HomeCaptureButton() // Part C: camera (asks which group if you're in more than one)
                    }

                // TODO (Part B): Join Group View
            }
        }
    }
    
}
