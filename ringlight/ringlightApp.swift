//
//  ringlightApp.swift
//  ringlight
//
//  Created by Om Sarraf on 20/12/25.
//

import SwiftUI

@main
struct ringlightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
