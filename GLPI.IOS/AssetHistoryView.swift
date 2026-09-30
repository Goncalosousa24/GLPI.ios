import SwiftUI

struct AssetHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    // Quick Actions
    @State private var quickActionAsset: Asset? = nil
    
    @State private var selectedAssetForHistory: Asset? = nil
    @State private var showHistoryForAsset = false
    
    // Estado para portas de rede
    @State private var selectedAssetForPorts: Asset? = nil
    
    @State private var allAssets: [GLPIClient.TicketWithAsset] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    // Pagination
    @State private var currentPage = 1
    private let itemsPerPage = 5
    
    var filteredAssets: [GLPIClient.TicketWithAsset] {
        if searchText.isEmpty { return allAssets }
        return allAssets.filter { 
            $0.ticket.title.localizedCaseInsensitiveContains(searchText) || 
            $0.asset.name.localizedCaseInsensitiveContains(searchText) ||
            $0.asset.serialNumber.localizedCaseInsensitiveContains(searchText) 
        }
    }
    
    var uniqueAssets: [GLPIClient.AssetHistoryItem] {
        var grouped: [String: (asset: Asset, count: Int)] = [:]
        for item in filteredAssets {
            let key = "\(item.asset.type.rawValue)-\(item.asset.realId)"
            if let existing = grouped[key] {
                grouped[key] = (existing.asset, existing.count + 1)
            } else {
                grouped[key] = (item.asset, 1)
            }
        }
        return grouped.values.map { 
            GLPIClient.AssetHistoryItem(asset: $0.asset, ticketCount: $0.count) 
        }.sorted(by: { $0.asset.name < $1.asset.name })
    }
    
    var totalPages: Int {
        let count = uniqueAssets.count
        return count == 0 ? 1 : (count + itemsPerPage - 1) / itemsPerPage
    }
    
    var paginatedAssets: [GLPIClient.AssetHistoryItem] {
        let start = (currentPage - 1) * itemsPerPage
        let end = min(start + itemsPerPage, uniqueAssets.count)
        guard start < uniqueAssets.count else { return [] }
        return Array(uniqueAssets[start..<end])
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (isLightMode ? Color.white : Color.black).ignoresSafeArea()
                    .universalBackgroundDismiss { hideKeyboard() }
                
                VStack(spacing: 0) {
                    headerView
                    
                    // 1. Pesquisa (Standard)
                    GLPISearchHeader(
                        searchText: $searchText,
                        placeholder: "Pesquisar no histórico..."
                    )
                    .padding(.top, 5)
                    .padding(.bottom, 10)
                    .onChange(of: searchText) { _ in currentPage = 1 }
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(GlpiColors.universalBlue)
                        Spacer()
                    } else if uniqueAssets.isEmpty {
                        Spacer()
                        VStack(spacing: 15) {
                            Image(systemName: "display")
                                .font(.system(size: 40))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                            Text(searchText.isEmpty ? "Sem Dispositivos com Tickets" : "Nenhum dispositivo encontrado")
                                .font(.amiko(size: 16, weight: .bold))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
                        }
                        Spacer()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                ForEach(paginatedAssets) { item in
                                    HistoryAssetRow(item: item)
                                        .onTapGesture {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            selectedAssetForHistory = item.asset
                                            showHistoryForAsset = true
                                        }
                                        .onLongPressGesture(minimumDuration: 0.4) {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                quickActionAsset = item.asset
                                            }
                                        }
                                }
                                
                                if totalPages > 1 {
                                    // Barra de Navegação Universal (Branca/Azul como InventoryView)
                                    HStack(spacing: 0) {
                                        Button(action: {
                                            if currentPage > 1 {
                                                withAnimation(.spring()) { currentPage -= 1 }
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(GlpiColors.universalBlue)
                                                .opacity(currentPage == 1 ? 0.2 : 1.0)
                                                .frame(width: 50, height: 50)
                                        }
                                        .disabled(currentPage == 1)
                                        
                                        Spacer()
                                        
                                        Rectangle()
                                            .fill(GlpiColors.dynamicText.opacity(0.15))
                                            .frame(width: 1, height: 24)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            if currentPage < totalPages {
                                                withAnimation(.spring()) { currentPage += 1 }
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        }) {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(GlpiColors.universalBlue)
                                                .opacity(currentPage == totalPages ? 0.2 : 1.0)
                                                .frame(width: 50, height: 50)
                                        }
                                        .disabled(currentPage == totalPages)
                                    }
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(GlpiColors.dynamicOffWhite)
                                    .cornerRadius(15)
                                    .padding(.top, 10)
                                    .padding(.bottom, 60)
                                }
                            }
                            .padding(.horizontal, GlpiMetrics.padding)
                            .padding(.top, 10)
                        }
                        .scrollDismissesKeyboard(.immediately)
                    }
                }
                .blur(radius: (quickActionAsset != nil) ? 8 : 0)
                .animation(.spring(), value: quickActionAsset != nil)
                
                // Navigation invisível para o Histórico de Tickets do Dispositivo
                NavigationLink(
                    destination: Group {
                        if let asset = selectedAssetForHistory {
                            DeviceTicketHistoryView(asset: asset)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $showHistoryForAsset
                ) {
                    EmptyView()
                }
                .hidden()
                
                // Overlay de Ações Rápidas
                if let asset = quickActionAsset {
                    DeviceQuickActionsOverlay(
                        asset: asset,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                quickActionAsset = nil
                            }
                        },
                        onReport: {
                            // Desativado neste ecrã
                        },
                        onHistory: {
                            selectedAssetForHistory = asset
                            withAnimation(.spring()) { quickActionAsset = nil }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showHistoryForAsset = true
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        },
                        onChangeState: {
                            withAnimation(.spring()) { quickActionAsset = nil }
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        },
                        onNetworkPorts: {
                            let assetToPorts = asset
                            withAnimation(.spring()) { quickActionAsset = nil }
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                selectedAssetForPorts = assetToPorts
                            }
                        },
                        showReportOption: false
                    )
                }
            }
            .preferredColorScheme(isLightMode ? .light : .dark)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $selectedAssetForPorts) { asset in
            DeviceNetworkPortsView(asset: asset)
        }
        .onAppear {
            Task {
                await loadAssetsWithHistory()
            }
        }
    }
    
    private func loadAssetsWithHistory() async {
        do {
            let fetched = try await GLPIClient.shared.getAssetsWithTickets()
            await MainActor.run {
                self.allAssets = fetched
                self.isLoading = false
            }
        } catch {
            print("Erro ao carregar dispositivos com histórico: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: GlpiMetrics.universalBackIcon)
                    .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                    .foregroundColor(GlpiColors.universalBlue)
            }
            .padding(.leading, GlpiMetrics.padding + 5)
            
            Spacer()
            
            Text("HISTÓRICO")
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicBlueText)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 5)
        .frame(height: GlpiMetrics.navAreaHeight)
    }
}

struct HistoryAssetRow: View {
    let item: GLPIClient.AssetHistoryItem
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                // Nome do Dispositivo
                Text(item.asset.name.uppercased())
                    .font(.amiko(size: 15, weight: .black))
                    .foregroundColor(isLightMode ? GlpiColors.universalBlue : .white)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Detalhes Horizontais
            HStack(alignment: .top, spacing: 0) {
                InfoColumn(label: "TIPO", value: item.asset.type.displayName.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                InfoColumn(label: "DEPARTAMENTO", value: item.asset.department?.uppercased() ?? "GERAL")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                InfoColumn(label: "S/N", value: item.asset.serialNumber.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(height: 115)
        .glassStyle(cornerRadius: 22)
    }
}

#Preview {
    AssetHistoryView()
}
