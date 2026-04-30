import SwiftUI

struct TicketQuickActionsOverlay: View {
    let ticket: GLPITicket
    let onDismiss: () -> Void
    let onEdit: () -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    let isReciclagem: Bool
    
    var body: some View {
        ZStack { 
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 25) { 
                // O TICKET (Visualização rápida)
                VStack(alignment: .leading, spacing: 15) {
                    Text(ticket.name)
                        .font(.amiko(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text("Requerente: ")
                                .font(.amiko(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                            Text(ticket.requester)
                                .font(.amiko(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        HStack(spacing: 4) {
                            Text("Atribuído: ")
                                .font(.amiko(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                            Text(ticket.assignedTo)
                                .font(.amiko(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    HStack(alignment: .bottom) {
                        Text(formatDate(ticket.date))
                            .font(.amiko(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text(ticket.id)
                            .font(.amiko(size: 18, weight: .bold))
                            .foregroundColor(Color.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .glassStyle(cornerRadius: 22)
                .padding(.horizontal, 16)
                
                // MENU DE AÇÕES
                VStack(alignment: .leading, spacing: 0) {
                    Text("AÇÕES DO TICKET")
                        .font(.amiko(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 16)
                        .padding(.top, 25)
                        .padding(.bottom, 12)
                    
                    Group {
                        if !isReciclagem {
                            actionMenuItem(title: "Responder", icon: "arrowshape.turn.up.left.fill", color: .white) {
                                onReply()
                            }
                            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 16)
                            
                            actionMenuItem(title: "Editar", icon: "pencil", color: .white) {
                                onEdit()
                            }
                            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 16)
                        }
                        
                        actionMenuItem(
                            title: isReciclagem ? "Eliminar para sempre" : "Reciclar",
                            icon: isReciclagem ? "trash.fill" : "trash.fill",
                            color: .white
                        ) {
                            onDelete()
                        }
                    }
                    
                    Spacer().frame(height: 15)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassStyle(cornerRadius: 30)
                .shadow(color: .blue.opacity(0.2), radius: 40)
                .padding(.horizontal, 16)
            }
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .zIndex(150)
    }
    
    private func actionMenuItem(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18))
                    .frame(width: 24)
                
                Text(title)
                    .font(.amiko(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(18)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}
