//
//  FloatingTabBar.swift
//  GLPI.IOS
//
//  Created by Antigravity on 18/04/2026.
//

import SwiftUI

enum GLPITab: String, CaseIterable {
    case tickets = "ticket.fill"
    case inventory = "desktopcomputer"
    case agenda = "calendar"
    case profile = "person.fill" // O rawValue será ignorado para o perfil agora
    
    var title: String {
        switch self {
        case .tickets: return "Tickets"
        case .inventory: return "Inventário"
        case .agenda: return "Agenda"
        case .profile: return "Perfil"
        }
    }
    
    func iconName(isSelected: Bool) -> String {
        switch self {
        case .tickets:
            return isSelected ? "ticket2" : "ticket"
        case .inventory:
            return isSelected ? "shippingbox.fill" : "shippingbox"
        case .agenda:
            return isSelected ? "agenda2" : "agenda1"
        case .profile:
            return isSelected ? "pessoa2" : "pessoa"
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: GLPITab
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(GLPITab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            if tab == .inventory {
                                Image(systemName: tab.iconName(isSelected: selectedTab == tab))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 26, height: 26)
                                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.4))
                                    .shadow(color: selectedTab == tab ? .white.opacity(0.8) : .clear, radius: 15)
                            } else {
                                Image(tab.iconName(isSelected: selectedTab == tab))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: tab == .agenda ? 23 : 26, height: tab == .agenda ? 23 : 26)
                                    .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.4))
                                    .shadow(color: selectedTab == tab ? .white.opacity(0.8) : .clear, radius: 15)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
        .tabBarGlassStyle()
        .padding(.horizontal, 16)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            FloatingTabBar(selectedTab: .constant(.tickets))
                .padding(.bottom, 30)
        }
    }
}
