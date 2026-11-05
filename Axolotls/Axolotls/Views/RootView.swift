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
            HStack {
                GroupsView() // TODO (Part B): Collapse view if there are a lot of groups

                NavigationStack {
                    NewGroupView()
                    // TODO (Part B): Join Group View
                    // TODO (Part C): Camera
                }
            }
        }
    }
    
}
