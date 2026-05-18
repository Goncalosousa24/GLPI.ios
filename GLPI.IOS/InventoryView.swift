import SwiftUI

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil
    
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
    
    @State private var activeSheet: InventorySheet? = nil
    @State private var filterPageIndex = 0
    
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
            GlpiColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header + Search (Sincronizado com o Dashboard)
                GLPISearchHeader(
                    searchText: $searchText,
                    placeholder: "Pesquisar ativos...",
                    rightIcon: "line.3.horizontal.decrease",
                    isSystemIcon: true,
                    isRightIconSelected: false,
                    rightIconAction: {
                        // Ação de Filtros (Pode abrir um menu ou sheet)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                            FilterPill(title: cat, isSelected: selectedCategory == cat, width: pillWidth) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedCategory == cat {
                                        selectedCategory = nil
                                    } else {
                                        selectedCategory = cat
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
                        
                        // 2. Asset List (Glass Cards) - Agora logo abaixo dos filtros
                        VStack(alignment: .leading, spacing: 15) {
                            Text("RECENTES - \(selectedCategory?.uppercased() ?? "TUDO")")
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
                                .padding(.horizontal, GlpiMetrics.padding + 5)
                            
                            VStack(spacing: 12) {
                                ForEach(viewModel.assets) { asset in
                                    AssetRow(asset: asset)
                                }
                            }
                            .padding(.horizontal, GlpiMetrics.padding)
                        }
                        
                        // 3. Ações Rápidas (Sincronizado com o Dashboard - "Gêmeos")
                        GLPIHorizontalScrollContainer {
                            HStack(spacing: GlpiMetrics.actionSpacing) {
                                let cardWidth = (UIScreen.screenWidth - (GlpiMetrics.padding * 2) - (GlpiMetrics.actionSpacing * 2)) / 3
                                
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
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .frame(width: UIScreen.main.bounds.width)
        .clipped()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .scanner:
                ScannerView { scannedCode in
                    self.searchText = scannedCode
                }
            case .create:
                AssetCreateView()
            case .report:
                AssetReportView()
            case .reservations:
                ReservationsView()
            case .history:
                AssetHistoryView()
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
            // 1. Nome do Dispositivo (Azul em light mode, Branco em dark mode)
            Text(asset.name.uppercased())
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(isLightMode ? GlpiColors.universalBlue : .white)
            
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
    InventoryView()
}
