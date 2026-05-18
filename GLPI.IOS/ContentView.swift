//
//  ContentView.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 17/04/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false
    
    var body: some View {
        Group {
            if isLoggedIn {
                MainView(isLoggedIn: $isLoggedIn)
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
