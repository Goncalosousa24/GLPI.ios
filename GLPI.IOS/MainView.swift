//
//  MainView.swift
//  GLPI.IOS
//
//  Created by Antigravity on 30/04/2026.
//

import SwiftUI

struct MainView: View {
    @State private var selectedTab: GLPITab = .tickets
    @AppStorage("isLoggedIn") var isLoggedIn = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Conteúdo da Tab Selecionada
            Group {
                switch selectedTab {
                case .tickets:
                    DashboardView(isLoggedIn: $isLoggedIn)
                case .inventory:
                    InventoryView()
                case .agenda:
                    AgendaView()
                case .profile:
                    ProfileView(isLoggedIn: $isLoggedIn)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Barra Flutuante
            FloatingTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 10)
        }
        .ignoresSafeArea(.keyboard)
    }
}
