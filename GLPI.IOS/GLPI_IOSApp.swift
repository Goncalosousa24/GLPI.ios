//
//  GLPI_IOSApp.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 17/04/2026.
//

import SwiftUI

@main
struct GLPI_IOSApp: App {
    init() {
        // Força a cor do cursor (tracinho) para o azul universal em toda a app
        UITextField.appearance().tintColor = UIColor(GlpiColors.universalBlue)
        UITextView.appearance().tintColor = UIColor(GlpiColors.universalBlue)
        
        // Desativar o modo offline por padrão para ligar ao servidor
        PreferenceManager.shared.isOfflineMode = false
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(GlpiColors.universalBlue)
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        }
    }
}
