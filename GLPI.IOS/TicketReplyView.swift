import SwiftUI

struct TicketReplyView: View {
    @Environment(\.dismiss) private var dismiss
    let ticket: GLPITicket
    
    @State private var replyText: String = ""
    @State private var isTicketExpanded: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // 1. FUNDO COM REGRA UNIVERSAL DE CANCELAMENTO
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss {
                    isFocused = false
                }
            
            VStack(spacing: 0) {
                // 2. HEADER
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(GlpiColors.dynamicText)
                    }
                    .padding(.leading, GlpiMetrics.padding + 5)
                    
                    Spacer()
                    
                    Text("RESPONDER")
                        .font(.amiko(size: 16, weight: .black))
                        .foregroundColor(GlpiColors.universalBlue)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                        .padding(.trailing, GlpiMetrics.padding)
                }
                .frame(height: 60)
                .padding(.top, 10)
                
                // 3. CONTEÚDO
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        
                        TicketRowViewReplyContext(ticket: ticket, isExpanded: $isTicketExpanded)
                            .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("A SUA RESPOSTA")
                                .font(.amiko(size: 10, weight: .black))
                                .foregroundColor(GlpiColors.universalBlue)
                                .padding(.leading, 8)
                            
                            ZStack(alignment: .topLeading) {
                                if replyText.isEmpty {
                                    Text("Escreva aqui a sua mensagem...")
                                        .font(.amiko(size: 16, weight: .regular))
                                        .foregroundColor(.black.opacity(0.2))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 20)
                                }
                                
                                TextEditor(text: $replyText)
                                    .font(.amiko(size: 16, weight: .regular))
                                    .foregroundColor(.black.opacity(0.8))
                                    .scrollContentBackground(.hidden)
                                    .padding(15)
                                    .focused($isFocused)
                                    .tint(GlpiColors.universalBlue)
                            }
                            .frame(minHeight: 250)
                            .glassStyle(cornerRadius: 30, isSelection: isFocused)
                        }
                        .padding(.horizontal, 16)
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                        }) {
                            Text("ENVIAR RESPOSTA")
                                .font(.amiko(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    Capsule()
                                        .fill(replyText.isEmpty ? GlpiColors.universalBlue.opacity(0.3) : GlpiColors.universalBlue)
                                        .shadow(color: GlpiColors.universalBlue.opacity(0.3), radius: 15, y: 8)
                                )
                        }
                        .disabled(replyText.isEmpty)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 50)
                    }
                    .padding(.top, 10)
                    .universalBackgroundDismiss { // Aplica a regra também à zona de scroll
                        isFocused = false
                    }
                }
            }
        }
    }
}

// Versão do TicketRow com Paridade Total (170px + Data)
struct TicketRowViewReplyContext: View {
    let ticket: GLPITicket
    @Binding var isExpanded: Bool
    
    private var mockResponses: [TicketResponse] {
        if !ticket.responses.isEmpty { return ticket.responses }
        return [
            TicketResponse(author: "Suporte Técnico", content: "Estamos a analisar o problema. Pode confirmar se o cabo está bem ligado?", date: Date().addingTimeInterval(-3600), isInternal: false),
            TicketResponse(author: ticket.requester, content: "Sim, tudo verificado. Continua sem funcionar.", date: Date().addingTimeInterval(-1800), isInternal: false)
        ]
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text(ticket.name.uppercased())
                            .font(.amiko(size: 17, weight: .black))
                            .foregroundColor(GlpiColors.universalBlue)
                            .lineLimit(isExpanded ? 3 : 1)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Text("\(ticket.id)")
                            .font(.inconsolata(size: 14, weight: .bold))
                            .foregroundColor(.black.opacity(0.3))
                    }
                    .padding(.bottom, 20)
                    
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 8) {
                            Text("REQUERENTE:")
                                .font(.amiko(size: 10, weight: .bold))
                                .foregroundColor(.black.opacity(0.4))
                            Text(ticket.requester.uppercased())
                                .font(.amiko(size: 14, weight: .black))
                                .foregroundColor(.black.opacity(0.9))
                        }
                        
                        HStack(spacing: 8) {
                            Text("ATRIBUÍDO:")
                                .font(.amiko(size: 10, weight: .bold))
                                .foregroundColor(.black.opacity(0.4))
                            Text(ticket.assignedTo.isEmpty ? "PENDENTE" : ticket.assignedTo.uppercased())
                                .font(.amiko(size: 14, weight: .black))
                                .foregroundColor(ticket.assignedTo.isEmpty ? GlpiColors.universalBlue : .black.opacity(0.9))
                        }
                    }
                    
                    if !isExpanded {
                        Spacer(minLength: 15)
                        HStack {
                            Text(formatDate(ticket.date).uppercased())
                                .font(.amiko(size: 11, weight: .black))
                                .foregroundColor(GlpiColors.universalBlue)
                            Spacer()
                        }
                    }
                }
                .frame(minHeight: isExpanded ? 0 : GlpiMetrics.ticketHeight - 48, alignment: .top)
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 20) {
                        Divider().background(Color.black.opacity(0.1)).padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DESCRIÇÃO")
                                .font(.amiko(size: 10, weight: .black))
                                .foregroundColor(GlpiColors.universalBlue)
                            
                            Text(ticket.description)
                                .font(.amiko(size: 15, weight: .regular))
                                .foregroundColor(.black.opacity(0.8))
                                .lineSpacing(4)
                        }
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("RESPOSTAS ANTERIORES")
                                .font(.amiko(size: 10, weight: .black))
                                .foregroundColor(GlpiColors.universalBlue)
                            
                            ForEach(mockResponses) { response in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(response.author.uppercased())
                                            .font(.amiko(size: 9, weight: .black))
                                            .foregroundColor(.black.opacity(0.5))
                                        Spacer()
                                        Text(formatDate(response.date))
                                            .font(.amiko(size: 9, weight: .bold))
                                            .foregroundColor(.black.opacity(0.2))
                                    }
                                    Text(response.content)
                                        .font(.amiko(size: 13, weight: .regular))
                                        .foregroundColor(.black.opacity(0.7))
                                }
                                .padding(15)
                                .background(Color.black.opacity(0.03))
                                .cornerRadius(18)
                            }
                        }
                        
                        HStack {
                            Text(formatDate(ticket.date).uppercased())
                                .font(.amiko(size: 10, weight: .black))
                                .foregroundColor(GlpiColors.universalBlue)
                            Spacer()
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .padding(24)
            .glassStyle(cornerRadius: 30)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM · HH:mm"
        formatter.locale = Locale(identifier: "pt_PT")
        return formatter.string(from: date)
    }
}
