import SwiftUI
import Combine
/// Switches the whole app between logged-out and logged-in.
struct RootView: View {
    @EnvironmentObject var session: AppSession
    @State private var viewModel = RootViewModel()
    @State private var groupsRefreshID = 0

    var body: some View {
        let darkPurple = Color(red: 0.2196, green: 0.1568, blue: 0.3058)
        let mediumPurple = Color(red: 0.4117, green: 0.2941, blue: 0.5764)
        let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)
        
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [darkPurple, mediumPurple]),
                startPoint: .trailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()

            switch session.state {
            case .loading:
                ProgressView()
            case .signedOut:
                AuthFlowView()
            case .signedIn:
                NavigationStack {
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [darkPurple, mediumPurple]),
                            startPoint: .trailing,
                            endPoint: .bottomLeading
                        )
                        .ignoresSafeArea()

                        VStack(spacing: 12) {
                            Text("Hi, \(session.profile?.displayName ?? "")!")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            InvitesView(
                                pendingGroups: viewModel.pending,
                                refreshPending: {
                                    await viewModel.loadPending(for: session.userID)
                                    groupsRefreshID += 1
                                }
                            )
                            
                            HStack {
                                NavigationLink("New Group") {
                                    NewGroupView()
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle)
                                .controlSize(.large)
                                .foregroundStyle(.black)
                                .tint(coral)
                                
                                NavigationLink("Join Group") {
                                    JoinGroupView()
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle)
                                .controlSize(.large)
                                .foregroundStyle(.black)
                                .tint(coral)
                            }
                            
                            GroupsView(refreshID: groupsRefreshID) // TODO (Part B): Collapse view if there are a lot of groups
                            
                            HomeCaptureButton() // Part C: camera

                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .containerBackground(.clear, for: .navigation)
                .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
    }
    
}
