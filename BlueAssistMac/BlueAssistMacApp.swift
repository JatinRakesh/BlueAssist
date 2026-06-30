
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
//        BluetoothDoctorSettings.registerDefaults()
//        Purchases.configure(withAPIKey: "test_CytcJLgcBucAfqNxtbTCOitKqZR")
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

//
//
//func checkEntitlement() async {
//    do {
//        let customerInfo = try await Purchases.shared.customerInfo()
//        if customerInfo.entitlements.all["BlueMacAssist Pro"]?.isActive == true {
//            // User has access to entitlement
//        }
//    } catch {
//        print("Error: \(error)")
//    }
//}


