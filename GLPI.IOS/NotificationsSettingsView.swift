//
//  NotificationsSettingsView.swift
//  GLPI.IOS
//
//  Created by Antigravity on 27/04/2026.
//

import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    @State private var allowNotifications = true
    @State private var notifyNewTickets = true
    @State private var notifyResolvedTickets = false
    @State private var notifyAssignedTickets = true
    
    var body: some View {
        ZStack {
            GlpiColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Cabeçalho Universal (Seta de Voltar)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(GlpiColors.universalBlue)
                    }
                    .padding(.leading, GlpiMetrics.padding + 5)
                    
                    Spacer()
                }
                .padding(.top, 5)
                .frame(height: GlpiMetrics.navAreaHeight)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        // MARK: - Interruptor Principal
                        VStack(spacing: 0) {
                            NotificationToggleRow(
                                title: "Permitir Notificações",
                                subtitle: "Receber alertas importantes no telemóvel",
                                icon: "bell.badge.fill",
                                isOn: $allowNotifications
                            )
                        }
                        .padding(20)
                        .background(GlpiColors.dynamicOffWhite)
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .strokeBorder(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.15), lineWidth: GlpiMetrics.inactiveBorderWidth)
                        )
                        .padding(.horizontal, 16)
                        
                        // MARK: - Opções Específicas
                        if allowNotifications {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("NOTIFICAR-ME SOBRE")
                                    .font(.amiko(size: 11, weight: .bold))
                                    .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                    .padding(.leading, 21)
                                
                                VStack(spacing: 0) {
                                    NotificationToggleRow(
                                        title: "Tickets Novos",
                                        subtitle: "Sempre que um novo ticket for criado",
                                        icon: "plus.circle.fill",
                                        isOn: $notifyNewTickets
                                    )
                                    
                                    Divider()
                                        .background(GlpiColors.dynamicText.opacity(0.05))
                                        .padding(.vertical, 10)
                                    
                                    NotificationToggleRow(
                                        title: "Tickets Resolvidos",
                                        subtitle: "Quando um ticket for marcado como concluído",
                                        icon: "checkmark.circle.fill",
                                        isOn: $notifyResolvedTickets
                                    )
                                    
                                    Divider()
                                        .background(GlpiColors.dynamicText.opacity(0.05))
                                        .padding(.vertical, 10)
                                    
                                    NotificationToggleRow(
                                        title: "Tickets Atribuídos",
                                        subtitle: "Quando um ticket lhe for atribuído",
                                        icon: "person.badge.plus.fill",
                                        isOn: $notifyAssignedTickets
                                    )
                                }
                                .padding(20)
                                .background(GlpiColors.dynamicOffWhite)
                                .cornerRadius(25)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .strokeBorder(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.15), lineWidth: GlpiMetrics.inactiveBorderWidth)
                                )
                                .padding(.horizontal, 16)
                            }
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
                    .fill(GlpiColors.dynamicText.opacity(0.03))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(isOn ? GlpiColors.universalBlue : GlpiColors.dynamicText.opacity(0.2))
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.amiko(size: 16, weight: .bold))
                    .foregroundColor(GlpiColors.dynamicText)
                Text(subtitle)
                    .font(.amiko(size: 12))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(GlpiColors.universalBlue)
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    NotificationsSettingsView()
}
