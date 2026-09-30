import SwiftUI

struct InventoryView: View {
    @Binding var showTabBar: Bool
    @ObservedObject var viewModel: InventoryViewModel
    
    enum InventorySheet: Identifiable {
        case scanner, create, report, reservations, history
        var id: Int {
            switch self {
            case .scanner: return 1
            case .create: return 2
            case .report: return 3
            case .reservations: return 4
            case .history: return 5
            }
        }
    }
    
    @AppStorage("isLightMode_V2") var isLightMode = true
    @State private var activeSheet: InventorySheet? = nil
    @State private var filterPageIndex = 0
    @State private var showLocationFilter = false
    
    @State private var quickActionAsset: Asset? = nil
    @State private var assetForStateChange: Asset? = nil
    @State private var showStateChangeOverlay = false
    @State private var lastScrollOffset: CGFloat = 0
    
    // Estado para passar ativo para a página de reporte
    @State private var assetForReport: Asset? = nil
    
    // Estados para controlo da UI
    @State private var showHistoryForAsset = false
    @State private var selectedAssetForHistory: Asset? = nil
    
    // Estado para portas de rede
    @State private var selectedAssetForPorts: Asset? = nil
    
    let categories = ["Computadores", "Monitores", "Impressoras", "Rede"]
    
    private var pillWidth: CGFloat {
        let screenWidth = UIScreen.screenWidth
        let totalPadding: CGFloat = GlpiMetrics.padding * 2
        let arrowContainerWidth: CGFloat = 75 // Espaço para as setas e divisor
        let spacing: CGFloat = 12
        return (screenWidth - totalPadding - arrowContainerWidth - spacing) / 2
    }
    
    private var currentFilters: [String] {
        let chunkSize = 2
        let start = filterPageIndex * chunkSize
        let end = min(start + chunkSize, categories.count)
        return Array(categories[start..<end])
    }
    
    private var totalFilterPages: Int {
        Int(ceil(Double(categories.count) / 2.0))
    }
    
    var body: some View {
        ZStack {
            (isLightMode ? Color.white : Color.black).ignoresSafeArea()
            VStack(spacing: 0) {
                // Header + Search (Sincronizado com o Dashboard)
                GLPISearchHeader(
                    searchText: $viewModel.searchText,
                    placeholder: "Pesquisar ativos...",
                    rightIcon: "line.3.horizontal.decrease.circle",
                    isSystemIcon: true,
                    isRightIconSelected: viewModel.selectedLocation != nil,
                    rightIconAction: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation {
                            showLocationFilter = true
                        }
                    },
                    innerRightIcon: "qrcode.viewfinder",
                    innerRightIconAction: {
                        activeSheet = .scanner
                    }
                )
                .padding(.top, GlpiMetrics.topPadding)
                .padding(.bottom, 5)
                
                // 1. Filtros de Categoria (Paginados 2 a 2) - Agora FIXO fora do ScrollView
                HStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ForEach(currentFilters, id: \.self) { cat in
                            FilterPill(title: cat, isSelected: viewModel.selectedCategory == cat, width: pillWidth) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if viewModel.selectedCategory == cat {
                                        viewModel.selectedCategory = nil
                                    } else {
                                        viewModel.selectedCategory = cat
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                            .id(cat)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .id("InventoryFilterPage_\(filterPageIndex)")
                    
                    // Controlos de Navegação das Categorias
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                if filterPageIndex > 0 {
                                    filterPageIndex -= 1
                                } else {
                                    filterPageIndex = totalFilterPages - 1
                                }
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                .frame(width: 30, height: 44)
                        }
                        
                        Rectangle()
                            .fill(GlpiColors.dynamicText.opacity(0.1))
                            .frame(width: 1, height: 14)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                filterPageIndex = (filterPageIndex + 1) % totalFilterPages
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                .frame(width: 30, height: 44)
                        }
                    }
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(GlpiColors.dynamicOffWhite))
                    .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 0.5))
                }
                .frame(height: 50)
                .padding(.horizontal, GlpiMetrics.padding)
                .padding(.bottom, 10)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        ScrollOffsetTracker()
                            .onPreferenceChange(ScrollDirectionPreferenceKey.self) { value in
                                if abs(value - lastScrollOffset) > 15 {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    lastScrollOffset = value
                                }
                            }
                        
                        // 2. Asset List (Glass Cards) - Agora logo abaixo dos filtros
                        VStack(alignment: .leading, spacing: 15) {

                            VStack(spacing: 12) {
                                ForEach(viewModel.assets) { asset in
                                    AssetRow(asset: asset)
                                        .onTapGesture {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            // Futuro: Expandir detalhes do dispositivo
                                        }
                                        .onLongPressGesture(minimumDuration: 0.4) {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                quickActionAsset = asset
                                            }
                                        }
                                }
                                
                                if viewModel.totalPages > 1 {
                                    HStack(spacing: 0) {
                                        Button(action: {
                                            if viewModel.currentPage > 1 {
                                                withAnimation(.spring()) {
                                                    viewModel.currentPage -= 1
                                                }
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(GlpiColors.universalBlue)
                                                .opacity(viewModel.currentPage == 1 ? 0.2 : 1.0)
                                                .frame(width: 50, height: 50)
                                        }
                                        .disabled(viewModel.currentPage == 1)
                                        
                                        Spacer()
                                        
                                        Rectangle()
                                            .fill(GlpiColors.dynamicText.opacity(0.15))
                                            .frame(width: 1, height: 24)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            if viewModel.currentPage < viewModel.totalPages {
                                                withAnimation(.spring()) {
                                                    viewModel.currentPage += 1
                                                }
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        }) {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(GlpiColors.universalBlue)
                                                .opacity(viewModel.currentPage == viewModel.totalPages ? 0.2 : 1.0)
                                                .frame(width: 50, height: 50)
                                        }
                                        .disabled(viewModel.currentPage == viewModel.totalPages)
                                    }
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .glassStyle(cornerRadius: 15)
                                    .padding(.top, 10)
                                }
                            }
                            .padding(.horizontal, GlpiMetrics.padding)
                        }
                        
                        // 3. Ações Rápidas (Sincronizado com o Dashboard - "Gêmeos")
                        GLPIHorizontalScrollContainer {
                            HStack(spacing: 20) {
                                let cardWidth = (UIScreen.screenWidth - (GlpiMetrics.padding * 2) - (20 * 2)) / 3
                                
                                DashboardQuickActionCard(title: "ADICIONAR", icon: "plus.circle.fill") {
                                    activeSheet = .create
                                }
                                .frame(width: cardWidth)
                                
                                DashboardQuickActionCard(title: "REPORTAR", icon: "exclamationmark.triangle.fill") {
                                    activeSheet = .report
                                }
                                .frame(width: cardWidth)
                                
                                DashboardQuickActionCard(title: "RESERVAS", icon: "calendar") {
                                    activeSheet = .reservations
                                }
                                .frame(width: cardWidth)
                                
                                DashboardQuickActionCard(title: "HISTÓRICO", icon: "clock.arrow.2.circlepath") {
                                    activeSheet = .history
                                }
                                .frame(width: cardWidth)
                            }
                            .padding(.horizontal, GlpiMetrics.padding)
                        }
                        
                        Spacer(minLength: 20)
                    }
                    .background(isLightMode ? Color.white : Color.black)
                }
                .background(isLightMode ? Color.white : Color.black)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .refreshable {
                    viewModel.refreshAssets()
                    while viewModel.isLoading {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }
            }
            .blur(radius: (activeSheet != nil || showLocationFilter || quickActionAsset != nil) ? 8 : 0)
            .animation(.spring(), value: activeSheet != nil || showLocationFilter || quickActionAsset != nil)
            
            if viewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                        .scaleEffect(1.5)
                }
            }
            
            if showLocationFilter {
                InventoryLocationFilterOverlay(isPresented: $showLocationFilter, selectedLocation: $viewModel.selectedLocation)
            }
            
            // Navigation invisível para o Histórico
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
                        assetForReport = asset
                        activeSheet = .report
                        withAnimation(.spring()) { quickActionAsset = nil }
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    },
                    onHistory: {
                        selectedAssetForHistory = asset
                        withAnimation(.spring()) { quickActionAsset = nil }
                        // Navegar para o histórico
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showHistoryForAsset = true
                        }
                    },
                    onChangeState: {
                        let assetToChange = asset
                        withAnimation(.spring()) { quickActionAsset = nil }
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            assetForStateChange = assetToChange
                            withAnimation {
                                showStateChangeOverlay = true
                            }
                        }
                    },
                    onNetworkPorts: {
                        let assetToPorts = asset
                        withAnimation(.spring()) { quickActionAsset = nil }
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedAssetForPorts = assetToPorts
                        }
                    }
                )
            }
            
            // Overlay de Alterar Estado
            if showStateChangeOverlay, let asset = assetForStateChange {
                DeviceStateChangeOverlay(
                    asset: asset,
                    isPresented: $showStateChangeOverlay,
                    onStateChanged: {
                        viewModel.fetchAssets()
                    }
                )
            }
        }
        .frame(width: UIScreen.main.bounds.width)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .scanner:
                ScannerView { scannedCode in
                    self.viewModel.searchText = scannedCode
                }
            case .create:
                AssetCreateView()
            case .report:
                AssetReportView(prefilledAsset: assetForReport)
            case .reservations:
                ReservationsView()
            case .history:
                AssetHistoryView()
            }
        }
        .sheet(item: $selectedAssetForPorts) { asset in
            DeviceNetworkPortsView(asset: asset)
        }
        .onChange(of: showLocationFilter) { newValue in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showTabBar = !newValue && quickActionAsset == nil
            }
        }
        .onChange(of: quickActionAsset?.id) { newValue in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showTabBar = (newValue == nil) && !showLocationFilter
            }
        }
    }
}

struct InventoryStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.amiko(size: 28, weight: .bold))
                .foregroundColor(GlpiColors.dynamicText)
            
            Text(title)
                .font(.amiko(size: 11, weight: .bold))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassStyle(cornerRadius: 22)
    }
}

struct AssetRow: View {
    let asset: Asset
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                // 1. Nome do Dispositivo (Azul em light mode, Branco em dark mode)
                Text(asset.name.uppercased())
                    .font(.amiko(size: 16, weight: .black))
                    .foregroundColor(isLightMode ? GlpiColors.universalBlue : .white)
                    
                Spacer()
                
                if !asset.status.isEmpty && asset.status.lowercased() != "nenhum" && asset.status.lowercased() != "null" {
                    Text(asset.status.uppercased())
                        .font(.amiko(size: 9, weight: .bold))
                        .frame(width: 75)
                        .padding(.vertical, 4)
                        .background(GlpiColors.universalBlue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            
            // 2. Utilizador
            Text(asset.owner?.uppercased() ?? "NÃO ATRIBUÍDO")
                .font(.amiko(size: 12, weight: .black))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
            
            Divider().background(GlpiColors.dynamicText.opacity(0.05))
            
            // 3. Detalhes Horizontais
            HStack(alignment: .top, spacing: 0) {
                InfoColumn(label: "TIPO", value: asset.type.displayName.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                InfoColumn(label: "DEPARTAMENTO", value: asset.department?.uppercased() ?? "GERAL")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                InfoColumn(label: "S/N", value: asset.serialNumber.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(height: GlpiMetrics.ticketHeight)
        .glassStyle(cornerRadius: 22)
    }
}

struct InfoColumn: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.amiko(size: 9, weight: .bold))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
            Text(value)
                .font(.amiko(size: 11, weight: .black))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                .lineLimit(1)
        }
    }
}

#Preview {
    InventoryView(showTabBar: .constant(true), viewModel: InventoryViewModel())
}
