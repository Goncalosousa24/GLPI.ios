import SwiftUI

struct TicketQuickActionsOverlay: View {
    let ticket: GLPITicket
    let isDeleteMode: Bool
    let onDismiss: () -> Void
    let onEdit: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    let onResolve: () -> Void
    let onSelect: () -> Void
    let onPermanentDelete: () -> Void
    let onRecover: () -> Void
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    init(ticket: GLPITicket, isDeleteMode: Bool = false, onDismiss: @escaping () -> Void, onEdit: @escaping () -> Void = {}, onReply: @escaping () -> Void = {}, onDelete: @escaping () -> Void = {}, onResolve: @escaping () -> Void = {}, onSelect: @escaping () -> Void = {}, onPermanentDelete: @escaping () -> Void = {}, onRecover: @escaping () -> Void = {}) {
        self.ticket = ticket
        self.isDeleteMode = isDeleteMode
        self.onDismiss = onDismiss
        self.onEdit = onEdit
        self.onReply = onReply
        self.onDelete = onDelete
        self.onResolve = onResolve
        self.onSelect = onSelect
        self.onPermanentDelete = onPermanentDelete
        self.onRecover = onRecover
    }
    
    var body: some View {
        ZStack {
            // Fundo com Blur
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 20) {
                // 1. RÉPLICA DO TICKET (Igual à lista)
                TicketRowViewPreview(ticket: ticket)
                    .padding(.horizontal, 16)
                
                // 2. QUADRADO DE FUNÇÕES
                VStack(spacing: 0) {
                    if isDeleteMode {
                        QuickActionItem(title: "ELIMINAR PERMANENTE", icon: "xmark.circle.fill", color: .red.opacity(0.8), action: onPermanentDelete)
                        Divider().background(Color.black.opacity(0.05)).padding(.horizontal, 20)
                        
                        QuickActionItem(title: "RECUPERAR", icon: "arrow.uturn.backward.circle.fill", color: GlpiColors.universalBlue, action: onRecover)
                    } else {
                        QuickActionItem(title: "RESPONDER", icon: "arrowshape.turn.up.left.fill", color: GlpiColors.dynamicText.opacity(0.8), action: onReply)
                        Divider().background(GlpiColors.dynamicText.opacity(0.05)).padding(.horizontal, 20)
                        
                        QuickActionItem(title: "EDITAR", icon: "pencil", color: GlpiColors.dynamicText.opacity(0.8), action: onEdit)
                        Divider().background(GlpiColors.dynamicText.opacity(0.05)).padding(.horizontal, 20)
                        
                        QuickActionItem(title: "RESOLVER", icon: "checkmark.circle.fill", color: GlpiColors.universalBlue, action: onResolve)
                        Divider().background(GlpiColors.dynamicText.opacity(0.05)).padding(.horizontal, 20)
                        
                        QuickActionItem(title: "ELIMINAR", icon: "xmark.circle.fill", color: .red.opacity(0.8), action: onDelete)
                    }
                }
                .background(GlpiColors.dynamicOffWhite)
                .cornerRadius(30)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .strokeBorder(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.15), lineWidth: GlpiMetrics.inactiveBorderWidth)
                )
                .padding(.horizontal, 16)
                .shadow(color: .black.opacity(0.1), radius: 30, x: 0, y: 20)
            }
            .padding(.bottom, 50)
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
        .zIndex(999)
    }
}

// Uma versão estática do TicketRow para o Preview do Overlay
struct TicketRowViewPreview: View {
    let ticket: GLPITicket
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(ticket.name.uppercased())
                        .font(.amiko(size: 17, weight: .black))
                        .foregroundColor(GlpiColors.universalBlue)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(ticket.id)")
                        .font(.inconsolata(size: 14, weight: .bold))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                }
                .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 8) {
                        Text("CRIADO POR:")
                            .font(.amiko(size: 10, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                        Text(ticket.author.uppercased())
                            .font(.amiko(size: 14, weight: .black))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                    }
                    
                    HStack(spacing: 8) {
                        Text("ATRIBUÍDO:")
                            .font(.amiko(size: 10, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                        Text(ticket.assignedTo.isEmpty ? "PENDENTE" : ticket.assignedTo.uppercased())
                            .font(.amiko(size: 14, weight: .black))
                            .foregroundColor(ticket.assignedTo.isEmpty ? GlpiColors.universalBlue : GlpiColors.dynamicText.opacity(0.9))
                    }
                }
                
                Spacer()
                
                HStack {
                    Text(formatDate(ticket.date).uppercased())
                        .font(.amiko(size: 11, weight: .black))
                        .foregroundColor(GlpiColors.universalBlue)
                    Spacer()
                }
            }
            .frame(height: GlpiMetrics.ticketHeight - 48)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(GlpiColors.dynamicOffWhite)
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.15), lineWidth: GlpiMetrics.inactiveBorderWidth)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM · HH:mm"
        return formatter.string(from: date)
    }
}

struct QuickActionItem: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.amiko(size: 15, weight: .black))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
