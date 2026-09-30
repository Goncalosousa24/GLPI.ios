import SwiftUI

struct TicketRowView: View {
    let ticket: GLPITicket
    let isSelected: Bool
    var selectionColor: Color = GlpiColors.universalBlue
    var isExpanded: Bool = false
    var isDeleteMode: Bool = false
    var listCategory: String = ""
    var onLongPress: (CGFloat) -> Void = { _ in }
    var onSelect: () -> Void = {}
    @Binding var currentY: CGFloat
    @AppStorage("isLightMode_V2") private var isLightMode = true
    
    // Respostas reais do ticket com fallback para mock apenas no modo offline
    private var displayedResponses: [TicketResponse] {
        if !ticket.responses.isEmpty { return ticket.responses }
        if PreferenceManager.shared.isOfflineMode {
            return [
                TicketResponse(author: "Suporte Técnico", content: "Estamos a analisar o problema. Pode confirmar se o cabo está bem ligado?", date: Date().addingTimeInterval(-3600), isInternal: false),
                TicketResponse(author: ticket.requester, content: "Sim, tudo verificado. Continua sem funcionar e as luzes estão apagadas.", date: Date().addingTimeInterval(-1800), isInternal: false)
            ]
        }
        return []
    }
    
    private func getBottomText() -> String {
        if ticket.status == .deleted {
            return ""
        }
        if listCategory.uppercased() == "PRIORITÁRIOS" {
            switch ticket.priority {
            case .high: return "ALTO"
            case .veryHigh: return "MUITO ALTO"
            case .major: return "PRINCIPAL"
            default: return ticket.priority.rawValue.uppercased()
            }
        } else {
            switch ticket.rawStatus {
            case "1": return "NOVO"
            case "2": return "A PROCESSAR (ATRIBUÍDO)"
            case "3": return "A PROCESSAR (PLANEADO)"
            case "4": return "AGUARDANDO"
            case "5": return "FINALIZADO"
            case "6": return "ENCERRADO"
            default: return ticket.status.rawValue.uppercased()
            }
        }
    }
    
    var body: some View {
        // Usamos um VStack com contentShape em vez de Button direto para melhor controlo de gestos
        VStack(alignment: .leading, spacing: 0) {
            // ÁREA PRINCIPAL
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(ticket.name.uppercased())
                        .font(.amiko(size: 17, weight: .black))
                        .foregroundColor(GlpiColors.dynamicBlueText)
                        .lineLimit(isExpanded ? 3 : 1)
                        .multilineTextAlignment(.leading)
                    
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
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        Text("ATRIBUÍDO:")
                            .font(.amiko(size: 10, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                        Text(ticket.assignedTo.isEmpty ? "PENDENTE" : ticket.assignedTo.uppercased())
                            .font(.amiko(size: 14, weight: .black))
                            .foregroundColor(ticket.assignedTo.isEmpty ? GlpiColors.dynamicBlueText : GlpiColors.dynamicText.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                
                if !isExpanded {
                    Spacer(minLength: 15)
                    ZStack {
                        HStack {
                            Text(formatDate(ticket.date).uppercased())
                                .font(.amiko(size: 11, weight: .black))
                                .foregroundColor(GlpiColors.dynamicBlueText)
                            Spacer()
                            Text(getBottomText())
                                .font(.amiko(size: 11, weight: .bold))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                        }
                        
                        HStack {
                            Spacer()
                            if isDeleteMode {
                                if isSelected {
                                    if selectionColor == .red {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(.red)
                                    } else {
                                        Image(systemName: "arrow.uturn.backward.circle.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(selectionColor)
                                    }
                                } else {
                                    Image(systemName: "circle")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.2))
                                }
                            }
                        }
                    }
                    .frame(height: 22)
                }
            }
            .frame(height: isExpanded ? nil : GlpiMetrics.ticketHeight - 48, alignment: .top)
            
            // CONTEÚDO EXPANDIDO
            if isExpanded {
                VStack(alignment: .leading, spacing: 25) {
                    Divider()
                        .background(GlpiColors.dynamicText.opacity(0.1))
                        .padding(.vertical, 10)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DESCRIÇÃO")
                            .font(.amiko(size: 10, weight: .black))
                            .foregroundColor(GlpiColors.dynamicBlueText)
                        
                        Text(ticket.description)
                            .font(.amiko(size: 15, weight: .regular))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
                            .lineSpacing(4)
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text("RESPOSTAS")
                            .font(.amiko(size: 10, weight: .black))
                            .foregroundColor(GlpiColors.dynamicBlueText)
                        
                        if displayedResponses.isEmpty {
                            Text("Sem respostas adicionais.")
                                .font(.amiko(size: 13, weight: .regular))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                .padding(.vertical, 8)
                        } else {
                            ForEach(displayedResponses) { response in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(response.author.uppercased())
                                            .font(.amiko(size: 9, weight: .black))
                                            .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
                                        Spacer()
                                        Text(formatDate(response.date))
                                            .font(.amiko(size: 9, weight: .bold))
                                            .foregroundColor(isLightMode ? GlpiColors.universalBlue : .white)
                                    }
                                    Text(response.content)
                                        .font(.amiko(size: 13, weight: .regular))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.7))
                                }
                                .padding(18)
                                .background(GlpiColors.dynamicText.opacity(0.04))
                                .cornerRadius(20)
                            }
                        }
                    }
                    
                    HStack {
                        Text(formatDate(ticket.date).uppercased())
                            .font(.amiko(size: 10, weight: .black))
                            .foregroundColor(GlpiColors.dynamicBlueText)
                        Spacer()
                    }
                    .padding(.top, 10)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).animation(.easeInOut(duration: 0.3).delay(0.1)),
                    removal: .opacity.animation(.easeInOut(duration: 0.2))
                ))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geo in
                Color.white.opacity(0.001) // Invisível mas detetável
                    .onTapGesture { onSelect() }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4)
                            .onEnded { _ in
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onLongPress(geo.frame(in: .global).midY)
                            }
                    )
            }
        )
        .glassStyle(cornerRadius: 30, isSelection: isSelected, selectionColor: selectionColor)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isExpanded)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM · HH:mm"
        formatter.locale = Locale(identifier: "pt_PT")
        return formatter.string(from: date)
    }
}
