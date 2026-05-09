
//
//  BlueAssistApp.swift
//  BlueAssist
//
//  Created by Jatin Rakesh on 7/5/26.

import SwiftData
import SwiftUI

@main
struct BluetoothDoctorApp: App {
    init() {
        BluetoothDoctorSettings.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        #if os(macOS)
        Settings {
            MacSettingsView()
        }
        #endif
    }
}



