//
//  MainView.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 30/04/2026.
//

import SwiftUI

struct MainView: View {
    @State private var selectedTab: GLPITab = .tickets
    @Binding var isLoggedIn: Bool
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    @StateObject private var inventoryViewModel = InventoryViewModel()
    @State private var showTabBar = true
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Fundo Único e Universal (Sincronizado com o Tema)
                (isLightMode ? Color.white : Color.black).ignoresSafeArea()
                
                // Conteúdo da Tab Selecionada
                Group {
                    switch selectedTab {
                    case .tickets:
                        DashboardView(isLoggedIn: $isLoggedIn)
                    case .inventory:
                        InventoryView(showTabBar: $showTabBar, viewModel: inventoryViewModel)
                    case .agenda:
                        AgendaView()
                    case .profile:
                        ProfileView(isLoggedIn: $isLoggedIn)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    if showTabBar {
                        Color.clear.frame(height: 80) // Reserva espaço para a barra
                    }
                }
                
                // Barra Flutuante (Posição Fixa, Absoluta e Blindada)
                if showTabBar {
                    FloatingTabBar(selectedTab: $selectedTab)
                        .frame(width: UIScreen.main.bounds.width)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}
