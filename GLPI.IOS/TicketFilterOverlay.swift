//
//  TicketFilterOverlay.swift
//  GLPI.IOS
//

import SwiftUI

struct TicketFilterOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedScope: String
    let isEditMode: Bool
    let isDeleteMode: Bool
    let title: String
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    var body: some View {
        ZStack {
            // Camada de Dimming (Fundo escurecido)
            Color.black.opacity(isLightMode ? 0.3 : 0.5)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.spring()) { isPresented = false } }
            
            // Modal Centralizado
            VStack(alignment: .leading, spacing: 0) {
                Text("FILTRAR POR")
                    .font(.amiko(size: 13, weight: .bold))
                    .foregroundColor(isLightMode ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.top, 25)
                    .padding(.bottom, 12)
                
                VStack(spacing: 0) {
                    filterMenuItem(title: "Geral", isSelected: selectedScope == "Geral") {
                        selectedScope = "Geral"
                        withAnimation(.spring()) { isPresented = false }
                    }
                    
                    Divider()
                        .background(isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
                        .padding(.horizontal, 16)
                    
                    if isEditMode {
                        filterMenuItem(title: "Novos", isSelected: selectedScope == "Novos") {
                            selectedScope = "Novos"
                            withAnimation(.spring()) { isPresented = false }
                        }
                        Divider()
                            .background(isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
                            .padding(.horizontal, 16)
                        filterMenuItem(title: "Em progresso", isSelected: selectedScope == "Em progresso") {
                            selectedScope = "Em progresso"
                            withAnimation(.spring()) { isPresented = false }
                        }
                        Divider()
                            .background(isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
                            .padding(.horizontal, 16)
                        filterMenuItem(title: "Prioritários", isSelected: selectedScope == "Prioritários") {
                            selectedScope = "Prioritários"
                            withAnimation(.spring()) { isPresented = false }
                        }
                    } else {
                        filterMenuItem(title: "Criados por mim", isSelected: selectedScope == "Criados por mim") {
                            selectedScope = "Criados por mim"
                            withAnimation(.spring()) { isPresented = false }
                        }
                        
                        if title != "NOVOS" {
                            Divider()
                                .background(isLightMode ? Color.black.opacity(0.1) : Color.white.opacity(0.1))
                                .padding(.horizontal, 16)
                            filterMenuItem(title: "Atribuídos a mim", isSelected: selectedScope == "Atribuídos a mim") {
                                selectedScope = "Atribuídos a mim"
                                withAnimation(.spring()) { isPresented = false }
                            }
                        }
                    }
                }
                
                Spacer().frame(height: 15)
            }
            .frame(maxWidth: .infinity)
            .glassStyle(cornerRadius: 30)
            .padding(.horizontal, 16)
            .shadow(color: isLightMode ? Color.black.opacity(0.08) : Color.blue.opacity(0.2), radius: 40)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .zIndex(10)
    }
    
    private func filterMenuItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.amiko(size: 14, weight: isSelected ? .bold : .regular))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(GlpiColors.universalBlue)
                }
            }
            .foregroundColor(isLightMode ? .black : .white)
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoHighlightButtonStyle())
    }
}
