import SwiftUI
import Combine
/// Switches the whole app between logged-out and logged-in.
struct RootView: View {
    @EnvironmentObject var session: AppSession
    @State private var viewModel = RootViewModel()

    var body: some View {
        let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)
        
        switch session.state {
        case .loading:
            ProgressView()
        case .signedOut:
            AuthFlowView()
        case .signedIn:
            NavigationStack {
                VStack(spacing: 12) {
                    Text("Hi, \(session.profile?.displayName ?? "")!").font(.title2.bold())
                    InvitesView(
                        pendingGroups: viewModel.pending,
                        refreshPending: {
                            await viewModel.loadPending(for: session.userID)
                        }
                    )
                    
                    GroupsView() // TODO (Part B): Collapse view if there are a lot of groups
                    
                    NavigationLink("New Group") {
                        NewGroupView()
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.black)
                    .tint(coral)
                    
                    NavigationLink("Join Group") {
                        JoinGroupView()
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.black)
                    .tint(coral)
                    
                    // TODO (Part C): Camera

                }
                .task(id: session.userID) {
                    await viewModel.loadPending(for: session.userID)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { SettingsView() } label: { Image(systemName: "person.circle") }
                    }
                }
            }
        }
    }
    
}
