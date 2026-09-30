//
//  TicketStatusFilterSheet.swift
//  GLPI.IOS
//

import SwiftUI

struct TicketStatusFilterSheet: View {
    @Binding var selectedStatus: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    let statuses = [
        "Todos",
        "Novo",
        "A processar (atribuído)",
        "A processar (planeado)",
        "Aguardando",
        "Finalizado",
        "Encerrado",
        "Não Finalizado",
        "Não Encerrado",
        "A processar",
        "Finalizado + Encerrado"
    ]
    
    @State private var initialSelectedStatus: String
    
    init(selectedStatus: Binding<String>) {
        self._selectedStatus = selectedStatus
        self._initialSelectedStatus = State(initialValue: selectedStatus.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fundo dinâmico da app (Branco no modo claro, Preto no modo escuro)
                (isLightMode ? Color.white : Color.black).ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(statuses, id: \.self) { status in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(nil) {
                                    selectedStatus = status
                                }
                                dismiss()
                            }) {
                                HStack {
                                    Text(status)
                                        .font(.amiko(size: 16, weight: initialSelectedStatus.lowercased() == status.lowercased() ? .bold : .regular))
                                        .foregroundColor(GlpiColors.dynamicText)
                                    Spacer()
                                    if initialSelectedStatus.lowercased() == status.lowercased() {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(GlpiColors.universalBlue)
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(initialSelectedStatus.lowercased() == status.lowercased() ? GlpiColors.dynamicOffWhite : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(NoHighlightButtonStyle())
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Filtrar por Estado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(isLightMode ? Color.white : Color.black, for: .navigationBar)
            .toolbarColorScheme(isLightMode ? .light : .dark, for: .navigationBar)
        }
    }
}
