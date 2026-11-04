//
//  AxolotlsApp.swift
//  Axolotls
//
//  Created by Anabella Arzate on 11/3/26.
//


import SwiftUI
import FirebaseCore


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    FirebaseConfiguration.shared.setLoggerLevel(.debug)

    return true
  }
}
 
@main
struct AxolotlsApp: App {
    @StateObject private var session: AppSession
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
 
    init() {
        //FirebaseApp.configure()                       // must run before AppSession touches Auth
        _session = StateObject(wrappedValue: AppSession())
    }
 
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}
 
