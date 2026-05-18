import SwiftUI

struct ReservationAsset: Identifiable {
    let id = UUID()
    let name: String
    let serial: String
    let type: AssetType
    var isReserved: Bool
    var reservedBy: String?
    var reservationDate: String?
}

struct ReservationsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedStatus = "Geral"
    @State private var showFilterMenu = false
    
    let categoryOptions = ["Computadores", "Periféricos"]
    let statusOptions = ["Geral", "Livres", "Reservados"]
    
    private var pillWidth: CGFloat {
        let totalPadding = (GlpiMetrics.padding * 2)
        let spacing: CGFloat = 12
        return (UIScreen.screenWidth - totalPadding - spacing) / 2
    }
    
    @State private var reservations: [ReservationAsset] = [
        ReservationAsset(name: "MacBook Air M2", serial: "MBA-9102", type: .computer, isReserved: true, reservedBy: "Gonçalo Sousa", reservationDate: "24/04/2026 - 28/04/2026"),
        ReservationAsset(name: "Projector Epson X41", serial: "EP-4412", type: .network, isReserved: false),
        ReservationAsset(name: "iPad Pro 12.9\"", serial: "IP-7788", type: .computer, isReserved: true, reservedBy: "Ana Martins", reservationDate: "23/04/2026 - 25/04/2026"),
        ReservationAsset(name: "Monitor Portátil ASUS", serial: "AS-1122", type: .monitor, isReserved: false),
        ReservationAsset(name: "Kit WebCam + Tripé", serial: "WC-3344", type: .network, isReserved: false)
    ]
    
    var filteredReservations: [ReservationAsset] {
        reservations.filter { asset in
            let matchesSearch = searchText.isEmpty || asset.name.lowercased().contains(searchText.lowercased()) || asset.serial.lowercased().contains(searchText.lowercased())
            
            let matchesCategory: Bool
            if let selected = selectedCategory {
                switch selected {
                case "Computadores": matchesCategory = asset.type == .computer
                case "Periféricos": matchesCategory = asset.type != .computer
                default: matchesCategory = true
                }
            } else {
                matchesCategory = true
            }
            
            let matchesStatus: Bool
            switch selectedStatus {
            case "Livres": matchesStatus = !asset.isReserved
            case "Reservados": matchesStatus = asset.isReserved
            default: matchesStatus = true
            }
            
            return matchesSearch && matchesCategory && matchesStatus
        }
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss {
                    if showFilterMenu {
                        withAnimation(.spring()) { showFilterMenu = false }
                    }
                }
            
            VStack(spacing: 0) {
                headerView
                
                // 1. Pesquisa e Filtros (Estilo Dashboard)
                VStack(spacing: 20) {
                    GLPISearchHeader(
                        searchText: $searchText,
                        placeholder: "Pesquisar equipamento...",
                        rightIcon: "line.3.horizontal.decrease.circle",
                        isSystemIcon: true,
                        isRightIconSelected: selectedStatus != "Geral",
                        rightIconAction: {
                            withAnimation(.spring()) {
                                showFilterMenu.toggle()
                            }
                        }
                    )
                    
                    // Category Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categoryOptions, id: \.self) { option in
                                FilterPill(title: option.uppercased(), isSelected: selectedCategory == option, width: pillWidth) {
                                    withAnimation(.spring()) {
                                        if selectedCategory == option {
                                            selectedCategory = nil
                                        } else {
                                            selectedCategory = option
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, GlpiMetrics.padding)
                    }
                }
                .padding(.top, 5)
                
                // 2. Lista de Ativos
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 15) {
                        ScrollOffsetTracker()
                        
                        HStack {
                            Text("DISPONIBILIDADE - \(selectedStatus.uppercased())")
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
                            Spacer()
                        }
                        .padding(.horizontal, GlpiMetrics.padding + 5)
                        .padding(.top, 10)
                        
                        VStack(spacing: 12) {
                            ForEach(filteredReservations) { asset in
                                ReservationRow(asset: asset)
                            }
                        }
                        .padding(.horizontal, GlpiMetrics.padding)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
            }
            .blur(radius: showFilterMenu ? 15 : 0)
            
            // Menu de Filtros de Status (Estilo Tickets)
            if showFilterMenu {
                filterMenuOverlay
            }
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: GlpiMetrics.universalBackIcon)
                    .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                    .foregroundColor(GlpiColors.dynamicText)
            }
            .padding(.leading, GlpiMetrics.padding + 5)
            
            Spacer()
            
            Text("RESERVAS")
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicBlueText)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 5)
        .frame(height: GlpiMetrics.navAreaHeight - 5)
    }
    
    private var filterMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) { showFilterMenu = false }
                }
            
            VStack(spacing: 0) {
                Text("FILTRAR POR ESTADO")
                    .font(.amiko(size: 12, weight: .bold))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                    .padding(.top, 25)
                    .padding(.bottom, 15)
                
                VStack(spacing: 0) {
                    ForEach(statusOptions, id: \.self) { option in
                        Button(action: {
                            withAnimation(.spring()) {
                                selectedStatus = option
                                showFilterMenu = false
                            }
                        }) {
                            HStack {
                                Text(option.uppercased())
                                    .font(.amiko(size: 14, weight: selectedStatus == option ? .black : .bold))
                                Spacer()
                                if selectedStatus == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(GlpiColors.universalBlue)
                                }
                            }
                            .foregroundColor(GlpiColors.dynamicText)
                            .padding(20)
                        }
                        
                        if option != statusOptions.last {
                            Divider().background(GlpiColors.dynamicText.opacity(0.05))
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .glassStyle(cornerRadius: 30)
                .padding(.horizontal, 20)
                
                Spacer().frame(height: 30)
            }
            .padding(.horizontal, 16)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(10)
    }
}

struct ReservationRow: View {
    let asset: ReservationAsset
    @State private var showInfo = false
    @State private var showReserveSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Header do Ativo
            HStack(spacing: 15) {
                // Nome em Azul (Padronizado)
                Text(asset.name.uppercased())
                    .font(.amiko(size: 16, weight: .black))
                    .foregroundColor(GlpiColors.dynamicBlueText)
                
                Spacer()
                
                // Status Badge
                GLPIBadge(text: asset.isReserved ? "RESERVADO" : "LIVRE")
            }
            
            // 2. Info Grid
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("S/N")
                        .font(.amiko(size: 9, weight: .bold))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                    Text(asset.serial.uppercased())
                        .font(.amiko(size: 11, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIPO")
                        .font(.amiko(size: 9, weight: .bold))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                    Text(asset.type.displayName.uppercased())
                        .font(.amiko(size: 11, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if asset.isReserved {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RESERVADO POR")
                            .font(.amiko(size: 9, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                        Text(asset.reservedBy?.uppercased() ?? "N/A")
                            .font(.amiko(size: 11, weight: .black))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Divider().background(GlpiColors.dynamicText.opacity(0.05))
            
            // 3. Botões de Ação
            HStack(spacing: 12) {
                Button(action: { 
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showInfo = true 
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("MAIS INFO")
                    }
                    .font(.amiko(size: 11, weight: .black))
                    .foregroundColor(GlpiColors.dynamicText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .glassStyle(cornerRadius: 15)
                }
                
                Button(action: { 
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showReserveSheet = true 
                }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text(asset.isReserved ? "ALTERAR" : "RESERVAR")
                    }
                    .font(.amiko(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(GlpiColors.universalBlue)
                    )
                }
                .disabled(asset.isReserved)
                .opacity(asset.isReserved ? 0.3 : 1.0)
            }
        }
        .padding(20)
        .glassStyle(cornerRadius: 22)
        .fullScreenCover(isPresented: $showInfo) {
            ReservationDetailView(asset: asset)
        }
        .fullScreenCover(isPresented: $showReserveSheet) {
            AssetReservationView(asset: asset)
        }
    }
}

struct ReservationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    let asset: ReservationAsset
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss { dismiss() }
            
            VStack(spacing: 0) {
                // Header Standard
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: GlpiMetrics.universalBackIcon)
                            .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                            .foregroundColor(GlpiColors.dynamicText)
                    }
                    .padding(.leading, GlpiMetrics.padding + 5)
                    
                    Spacer()
                    
                    Text("DETALHES DO ATIVO")
                        .font(.amiko(size: 16, weight: .black))
                        .foregroundColor(GlpiColors.dynamicBlueText)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .frame(height: GlpiMetrics.navAreaHeight)
                
                Spacer() // Empurra para o centro
                
                // Card de Informação Premium (Centrado)
                VStack(alignment: .leading, spacing: 20) {
                    DetailRow(label: "NOME DO EQUIPAMENTO", value: asset.name.uppercased())
                    DetailRow(label: "NÚMERO DE SÉRIE", value: asset.serial.uppercased())
                    DetailRow(label: "CATEGORIA", value: asset.type.displayName.uppercased())
                    
                    Divider().background(GlpiColors.dynamicText.opacity(0.1))
                    
                    if asset.isReserved {
                        DetailRow(label: "RESERVADO POR", value: asset.reservedBy?.uppercased() ?? "N/A")
                        DetailRow(label: "PERÍODO DA RESERVA", value: asset.reservationDate?.uppercased() ?? "N/A")
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16, weight: .bold))
                            Text("DISPONÍVEL PARA RESERVA")
                                .font(.amiko(size: 13, weight: .black))
                                .foregroundColor(.green)
                        }
                        .padding(.top, 5)
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 350)
                .glassStyle(cornerRadius: 30)
                .padding(.horizontal, 16)
                
                Spacer() // Empurra para o centro
                Spacer().frame(height: 50) // Compensação visual para o centro real
            }
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.amiko(size: 10, weight: .bold))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
            Text(value)
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicText)
        }
    }
}

#Preview {
    ReservationsView()
}

#Preview {
    ReservationsView()
}
