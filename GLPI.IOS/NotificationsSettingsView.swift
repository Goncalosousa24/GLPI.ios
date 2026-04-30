//
//  NotificationsSettingsView.swift
//  GLPI.IOS
//
//  Created by Antigravity on 27/04/2026.
//

import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var allowNotifications = true
    @State private var notifyNewTickets = true
    @State private var notifyResolvedTickets = false
    @State private var notifyAssignedTickets = true
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .glassStyle(cornerRadius: 12)
                    }
                    
                    Spacer()
                    
                    Text("NOTIFICAÇÕES")
                        .font(.amiko(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 45, height: 45)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        // MARK: - Main Toggle
                        VStack(spacing: 0) {
                            NotificationToggleRow(
                                title: "Permitir Notificações",
                                subtitle: "Receber alertas importantes no telemóvel",
                                icon: "bell.badge.fill",
                                isOn: $allowNotifications
                            )
                        }
                        .padding(20)
                        .glassStyle(cornerRadius: 25)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        
                        // MARK: - Specific Options
                        if allowNotifications {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("NOTIFICAR-ME SOBRE")
                                    .font(.amiko(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.leading, 5)
                                
                                VStack(spacing: 0) {
                                    NotificationToggleRow(
                                        title: "Tickets Novos",
                                        subtitle: "Sempre que um novo ticket for criado",
                                        icon: "plus.circle.fill",
                                        isOn: $notifyNewTickets
                                    )
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.vertical, 10)
                                    
                                    NotificationToggleRow(
                                        title: "Tickets Resolvidos",
                                        subtitle: "Quando um ticket for marcado como concluído",
                                        icon: "checkmark.circle.fill",
                                        isOn: $notifyResolvedTickets
                                    )
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.vertical, 10)
                                    
                                    NotificationToggleRow(
                                        title: "Tickets Atribuídos",
                                        subtitle: "Quando um ticket lhe for atribuído",
                                        icon: "person.badge.plus.fill",
                                        isOn: $notifyAssignedTickets
                                    )
                                }
                                .padding(20)
                                .glassStyle(cornerRadius: 25)
                            }
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        Spacer(minLength: 120)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: allowNotifications)
    }
}

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(isOn ? .blue : .white.opacity(0.3))
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.amiko(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.amiko(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.blue)
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    NotificationsSettingsView()
}
