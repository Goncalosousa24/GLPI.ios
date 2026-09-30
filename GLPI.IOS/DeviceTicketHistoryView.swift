import SwiftUI

struct DeviceTicketHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    let asset: Asset
    @State private var tickets: [GLPIClient.AssetLinkedTicket] = []
    @State private var isLoading = true
    
    // Paginação
    @State private var currentPage = 1
    let itemsPerPage = 5
    
    var totalPages: Int {
        max(1, Int(ceil(Double(tickets.count) / Double(itemsPerPage))))
    }
    
    var paginatedTickets: [GLPIClient.AssetLinkedTicket] {
        let start = (currentPage - 1) * itemsPerPage
        let end = min(start + itemsPerPage, tickets.count)
        guard start < tickets.count else { return [] }
        return Array(tickets[start..<end])
    }
    
    var body: some View {
        ZStack {
            (isLightMode ? Color.white : Color.black).ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(GlpiColors.universalBlue)
                    Spacer()
                } else if tickets.isEmpty {
                    Spacer()
                    VStack(spacing: 15) {
                        Text("Este dispositivo não possui tickets associados.")
                            .font(.amiko(size: 14, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(paginatedTickets) { ticket in
                                HistoryRow(item: ticket)
                            }
                            
                            if totalPages > 1 {
                                // Barra de Navegação Universal
                                HStack(spacing: 0) {
                                    Button(action: {
                                        if currentPage > 1 { 
                                            withAnimation(.spring()) { currentPage -= 1 } 
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(currentPage > 1 ? GlpiColors.dynamicText : GlpiColors.dynamicText.opacity(0.3))
                                            .frame(width: 44, height: 35)
                                    }
                                    .disabled(currentPage == 1)
                                    
                                    Rectangle()
                                        .fill(GlpiColors.dynamicText.opacity(0.1))
                                        .frame(width: 1, height: 15)
                                    
                                    Button(action: {
                                        if currentPage < totalPages { 
                                            withAnimation(.spring()) { currentPage += 1 } 
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        }
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(currentPage < totalPages ? GlpiColors.dynamicText : GlpiColors.dynamicText.opacity(0.3))
                                            .frame(width: 44, height: 35)
                                    }
                                    .disabled(currentPage == totalPages)
                                }
                                .background(GlpiColors.dynamicText.opacity(0.05))
                                .clipShape(Capsule())
                                .padding(.top, 10)
                                .padding(.bottom, 60)
                            }
                        }
                        .padding(.horizontal, GlpiMetrics.padding)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task { await loadTickets() }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: GlpiMetrics.universalBackIcon)
                    .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                    .foregroundColor(GlpiColors.universalBlue)
            }
            .padding(.leading, GlpiMetrics.padding + 5)
            
            Spacer()
            
            Text(asset.name.uppercased())
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicBlueText)
                .lineLimit(1)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 5)
        .frame(height: GlpiMetrics.navAreaHeight - 5)
    }
    
    private func loadTickets() async {
        do {
            let assetTypeRaw: String
            switch asset.type {
            case .computer: assetTypeRaw = "Computer"
            case .monitor: assetTypeRaw = "Monitor"
            case .printer: assetTypeRaw = "Printer"
            case .network: assetTypeRaw = "NetworkEquipment"
            }
            
            let fetched = try await GLPIClient.shared.getTicketsForAsset(assetType: assetTypeRaw, assetId: asset.realId)
            await MainActor.run {
                self.tickets = fetched
                self.isLoading = false
            }
        } catch {
            print("Erro ao carregar tickets do dispositivo: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct HistoryRow: View {
    let item: GLPIClient.AssetLinkedTicket
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                // 1. Título do Ticket (Maiúsculas)
                Text(item.ticketName.uppercased())
                    .font(.amiko(size: 14, weight: .black))
                    .foregroundColor(GlpiColors.dynamicBlueText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // 2. ID
                Text(item.id)
                    .font(.inconsolata(size: 14, weight: .bold))
                    .foregroundColor(GlpiColors.universalBlue)
            }
            
            Spacer()
            
            // 3. Data do Ticket em baixo
            Text(formatDate(item.date).uppercased())
                .font(.amiko(size: 10, weight: .bold))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
        }
        .padding(20)
        .frame(height: 115, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .glassStyle(cornerRadius: 22)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM · HH:mm"
        formatter.locale = Locale(identifier: "pt_PT")
        return formatter.string(from: date)
    }
}
