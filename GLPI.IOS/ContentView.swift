//
//  ContentView.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 17/04/2026.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("isLoggedIn") var isLoggedIn = false
    
    var body: some View {
        Group {
            if isLoggedIn {
                MainView()
            } else {
                LoginView(isLoggedIn: $isLoggedIn)
            }
        }
        .animation(.spring(), value: isLoggedIn)
    }
}

#Preview {
    ContentView()
}
