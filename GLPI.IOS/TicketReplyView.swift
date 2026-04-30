import SwiftUI

struct TicketReplyView: View {
    @Environment(\.dismiss) private var dismiss
    let ticket: GLPITicket
    
    @State private var replyText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(12)
                            .glassStyle(cornerRadius: 18)
                    }
                    
                    Spacer()
                    
                    Text("RESPONDER AO TICKET")
                        .font(.amiko(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 20) {
                    // Ticket Info Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ticket.id)
                            .font(.amiko(size: 12, weight: .bold))
                            .foregroundColor(Color.white)
                        
                        Text(ticket.name)
                            .font(.amiko(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    
                    // Reply Box
                    VStack(alignment: .leading, spacing: 12) {
                        Text("A SUA RESPOSTA")
                            .font(.amiko(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 16)
                        
                        ZStack(alignment: .topLeading) {
                            if replyText.isEmpty {
                                Text("Escreva aqui a sua mensagem...")
                                    .font(.amiko(size: 16))
                                    .foregroundColor(.white.opacity(0.2))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                            }
                            
                            TextEditor(text: $replyText)
                                .font(.amiko(size: 16))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .padding(15)
                                .focused($isFocused)
                        }
                        .frame(maxHeight: .infinity)
                        .glassStyle(cornerRadius: 22)
                    }
                    .padding(.horizontal, 16)
                    
                    // Send Button
                    HStack {
                        Spacer()
                        Button(action: {
                            dismiss()
                        }) {
                            HStack(spacing: 10) {
                                Text("ENVIAR RESPOSTA")
                                    .font(.amiko(size: 14, weight: .bold))
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 240, height: 52)
                            .glassStyle(cornerRadius: 22)
                        }
                        .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                        Spacer()
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    TicketReplyView(ticket: GLPITicket(id: "#1030", name: "Servidor Web DOWN", requester: "João Silva", assignedTo: "Técnico Admin", description: "Desc", date: Date(), priority: .major, status: .new, isMine: true, isAssignedToMe: false))
}
