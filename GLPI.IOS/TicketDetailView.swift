import SwiftUI

struct TicketDetailView: View {
    @Environment(\.dismiss) var dismiss
    let ticket: GLPITicket
    
    // Dados de exemplo caso o ticket não tenha respostas
    private var mockResponses: [TicketResponse] {
        if !ticket.responses.isEmpty { return ticket.responses }
        return [
            TicketResponse(author: "Suporte Técnico", content: "Estamos a analisar o problema com a sua impressora. Pode confirmar se o cabo de rede está bem ligado?", date: Date().addingTimeInterval(-3600), isInternal: false),
            TicketResponse(author: ticket.requester, content: "Sim, verifiquei agora e o cabo está bem encaixado, mas as luzes não acendem.", date: Date().addingTimeInterval(-1800), isInternal: false),
            TicketResponse(author: "Manutenção", content: "Ok, vamos enviar um técnico ao local para verificar a fonte de alimentação.", date: Date().addingTimeInterval(-600), isInternal: false)
        ]
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Header (Mantendo o alinhamento universal)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(GlpiColors.dynamicText)
                    }
                    .padding(.leading, GlpiMetrics.padding + 5)
                    
                    Spacer()
                }
                .padding(.top, 5)
                .frame(height: GlpiMetrics.navAreaHeight - 5)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        
                        // 2. Título do Ticket (Destaque)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ticket.name.uppercased())
                                .font(.amiko(size: 24, weight: .black))
                                .foregroundColor(GlpiColors.dynamicBlueText)
                            
                            Text("TICKET \(ticket.id)")
                                .font(.inconsolata(size: 14, weight: .bold))
                                .foregroundColor(.black.opacity(0.4))
                        }
                        .padding(.horizontal, GlpiMetrics.padding)
                        
                        // 3. Informações de Requerente e Atribuído (Cartão Glass)
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 12) {
                                Text("REQUERENTE:")
                                    .font(.amiko(size: 10, weight: .bold))
                                    .foregroundColor(.black.opacity(0.4))
                                Text(ticket.requester.uppercased())
                                    .font(.amiko(size: 14, weight: .black))
                                    .foregroundColor(.black.opacity(0.9))
                            }
                            
                            HStack(spacing: 12) {
                                Text("ATRIBUÍDO:")
                                    .font(.amiko(size: 10, weight: .bold))
                                    .foregroundColor(.black.opacity(0.4))
                                Text(ticket.assignedTo.isEmpty ? "PENDENTE" : ticket.assignedTo.uppercased())
                                    .font(.amiko(size: 14, weight: .black))
                                    .foregroundColor(ticket.assignedTo.isEmpty ? GlpiColors.dynamicBlueText : .black.opacity(0.9))
                            }
                        }
                        .padding(24)
                        .glassStyle(cornerRadius: 30)
                        .padding(.horizontal, GlpiMetrics.padding)
                        
                        // 4. Descrição do Problema
                        VStack(alignment: .leading, spacing: 15) {
                            Text("DESCRIÇÃO")
                                .font(.amiko(size: 12, weight: .black))
                                .foregroundColor(GlpiColors.dynamicBlueText)
                            
                            Text(ticket.description)
                                .font(.amiko(size: 16, weight: .regular))
                                .foregroundColor(.black.opacity(0.8))
                                .lineSpacing(4)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassStyle(cornerRadius: 30)
                        .padding(.horizontal, GlpiMetrics.padding)
                        
                        // 5. Timeline de Respostas (Timeline)
                        VStack(alignment: .leading, spacing: 20) {
                            Text("RESPOSTAS E INTERAÇÕES")
                                .font(.amiko(size: 12, weight: .black))
                                .foregroundColor(GlpiColors.dynamicBlueText)
                            
                            ForEach(mockResponses) { response in
                                ResponseBubble(response: response)
                            }
                        }
                        .padding(.horizontal, GlpiMetrics.padding)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct ResponseBubble: View {
    let response: TicketResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(response.author.uppercased())
                    .font(.amiko(size: 10, weight: .black))
                    .foregroundColor(GlpiColors.dynamicBlueText)
                
                Spacer()
                
                Text(formatTime(response.date))
                    .font(.amiko(size: 10, weight: .bold))
                    .foregroundColor(.black.opacity(0.3))
            }
            
            Text(response.content)
                .font(.amiko(size: 14, weight: .regular))
                .foregroundColor(.black.opacity(0.8))
                .lineSpacing(2)
        }
        .padding(20)
        .glassStyle(cornerRadius: 22)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM · HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    TicketDetailView(ticket: GLPITicket(
        id: "105",
        name: "Erro ao imprimir em PDF",
        requester: "Gonçalo Sousa",
        author: "Eduardo Lima",
        assignedTo: "Suporte",
        description: "Ao tentar gerar o relatório mensal em PDF, a aplicação encerra inesperadamente sem gravar os dados.",
        date: Date(),
        priority: .high,
        status: .new,
        isMine: true,
        isAssignedToMe: false
    ))
}
