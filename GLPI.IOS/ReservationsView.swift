import SwiftUI

struct ReservationAsset: Identifiable, Equatable {
    let id = UUID()
    let reservationItemsId: Int
    let itemtype: String
    let itemsId: Int
    let name: String
    let serial: String
    let type: AssetType
    var isReserved: Bool
    var reservedBy: String?
    var reservationDate: String?
    
    // Additional fields for detail view
    var activeEndDate: String?
    var activeComment: String?
    var nextReservationDate: String?
}

struct ReservationsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedStatus = "Geral"
    @State private var showFilterMenu = false
    @State private var lastScrollOffset: CGFloat = 0
    
    @State private var reservations: [ReservationAsset] = []
    @State private var isLoading = false
    @State private var paginaAtual = 0
    @State private var selectedDetailAsset: ReservationAsset? = nil
    
    private let itensParaExibir = 10
    private let buscaRangeAPI = 100
    
    let categoryOptions = ["Computadores", "Periféricos"]
    let statusOptions = ["Geral", "Livres", "Reservados"]
    
    private var pillWidth: CGFloat {
        let totalPadding = (GlpiMetrics.padding * 2)
        let spacing: CGFloat = 12
        return (UIScreen.screenWidth - totalPadding - spacing) / 2
    }
    
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
    
    var displayedReservations: [ReservationAsset] {
        Array(filteredReservations.prefix(itensParaExibir))
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
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 5)
                
                // 2. Lista de Ativos
                ZStack {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 15) {
                            ScrollOffsetTracker()
                                .onPreferenceChange(ScrollDirectionPreferenceKey.self) { value in
                                    if abs(value - lastScrollOffset) > 15 {
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        lastScrollOffset = value
                                    }
                                }
                            
                            HStack {
                                Text("DISPONIBILIDADE - \(selectedStatus.uppercased())")
                                    .font(.amiko(size: 14, weight: .bold))
                                    .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
                                Spacer()
                            }
                            .padding(.horizontal, GlpiMetrics.padding + 5)
                            .padding(.top, 10)
                            
                            if displayedReservations.isEmpty && !isLoading {
                                VStack(spacing: 15) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.system(size: 40))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                                    Text("NENHUM EQUIPAMENTO ENCONTRADO")
                                        .font(.amiko(size: 12, weight: .bold))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                }
                                .padding(.top, 40)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(displayedReservations) { asset in
                                        ReservationRow(asset: asset, onRefresh: {
                                            Task {
                                                await carregarReservas()
                                            }
                                        }, onShowInfo: {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                selectedDetailAsset = asset
                                            }
                                        })
                                    }
                                }
                                .padding(.horizontal, GlpiMetrics.padding)
                            }
                            
                            // Controlo de Paginação
                            if !displayedReservations.isEmpty {
                                HStack(spacing: 0) {
                                    Button(action: {
                                        if paginaAtual > 0 {
                                            withAnimation(.spring()) { paginaAtual -= 1 }
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            Task { await carregarReservas() }
                                        }
                                    }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(GlpiColors.universalBlue)
                                            .opacity(paginaAtual > 0 ? 1.0 : 0.2)
                                            .frame(width: 50, height: 50)
                                    }
                                    .disabled(paginaAtual == 0)
                                    
                                    Spacer()
                                    
                                    Rectangle()
                                        .fill(GlpiColors.dynamicText.opacity(0.15))
                                        .frame(width: 1, height: 24)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        if filteredReservations.count >= itensParaExibir {
                                            withAnimation(.spring()) { paginaAtual += 1 }
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            Task { await carregarReservas() }
                                        }
                                    }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(GlpiColors.universalBlue)
                                            .opacity(filteredReservations.count >= itensParaExibir ? 1.0 : 0.2)
                                            .frame(width: 50, height: 50)
                                    }
                                    .disabled(filteredReservations.count < itensParaExibir)
                                }
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(GlpiColors.dynamicOffWhite)
                                .cornerRadius(15)
                                .padding(.horizontal, GlpiMetrics.padding)
                                .padding(.top, 10)
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 60)
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .blur(radius: showFilterMenu ? 15 : 0)
            
            if isLoading {
                ZStack {
                    (isLightMode ? Color.white : Color.black).ignoresSafeArea()
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                            .scaleEffect(1.6)
                        Text("A carregar reservas...")
                            .font(.amiko(size: 14, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
                    }
                }
                .transition(.opacity)
            }
            
            // Menu de Filtros de Status (Estilo Tickets)
            if showFilterMenu {
                ReservationStatusFilterOverlay(
                    isPresented: $showFilterMenu,
                    selectedStatus: $selectedStatus
                )
            }
            
            // Overlay de Detalhes da Reserva (Quadrado Oval no fundo)
            if let asset = selectedDetailAsset {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 18) {
                        // Header com título e botão de fechar
                        HStack {
                            Text("DETALHES DO ATIVO")
                                .font(.amiko(size: 15, weight: .black))
                                .foregroundColor(GlpiColors.dynamicBlueText)
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedDetailAsset = nil
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(GlpiColors.universalBlue)
                            }
                        }
                        .padding(.bottom, 5)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            DetailRow(label: "NOME DO EQUIPAMENTO", value: asset.name.uppercased())
                            DetailRow(label: "NÚMERO DE SÉRIE", value: asset.serial.uppercased())
                            DetailRow(label: "CATEGORIA", value: asset.type.displayName.uppercased())
                            
                            Divider().background(GlpiColors.dynamicText.opacity(0.1))
                            
                            if asset.isReserved {
                                DetailRow(label: "RESERVADO POR", value: asset.reservedBy?.uppercased() ?? "N/A")
                                if let activeEndDate = asset.activeEndDate {
                                    DetailRow(label: "PERÍODO DA RESERVA", value: "ATÉ \(activeEndDate)")
                                }
                                if let comment = asset.activeComment, !comment.isEmpty {
                                    DetailRow(label: "COMENTÁRIO", value: comment)
                                }
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 15, weight: .bold))
                                    Text("DISPONÍVEL PARA RESERVA")
                                        .font(.amiko(size: 12, weight: .black))
                                        .foregroundColor(.green)
                                }
                                .padding(.top, 4)
                                
                                if let nextRes = asset.nextReservationDate {
                                    DetailRow(label: "PRÓXIMA RESERVA PREVISTA", value: nextRes)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(isLightMode ? Color.white : Color(hexString: "1C1C1E"))
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(GlpiColors.dynamicBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, GlpiMetrics.padding)
                    .padding(.bottom, GlpiMetrics.padding)
                    .shadow(color: Color.black.opacity(isLightMode ? 0.15 : 0.45), radius: 25, x: 0, y: 10)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
        .onAppear {
            Task {
                await carregarReservas()
            }
        }
    }
    
    // MARK: - API Loading Method
    
    func carregarReservas() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        let rangeStr = "\(paginaAtual * itensParaExibir)-\(paginaAtual * itensParaExibir + buscaRangeAPI - 1)"
        
        do {
            let items = try await GLPIClient.shared.getAllReservationItems(range: rangeStr)
            
            var loadedAssets: [ReservationAsset] = []
            
            try await withThrowingTaskGroup(of: ReservationAsset?.self) { group in
                for item in items {
                    let isActive: Bool
                    if let actVal = item["is_active"] as? Bool {
                        isActive = actVal
                    } else if let actVal = item["is_active"] as? Int {
                        isActive = (actVal == 1)
                    } else if let actVal = item["is_active"] as? String {
                        isActive = (actVal == "1" || actVal.lowercased() == "true")
                    } else {
                        isActive = false
                    }
                    
                    guard isActive else { continue }
                    guard let id = item["id"] as? Int ?? (item["id"] as? String).flatMap(Int.init),
                          let itemsId = item["items_id"] as? Int ?? (item["items_id"] as? String).flatMap(Int.init),
                          let itemtype = item["itemtype"] as? String else { continue }
                    
                    group.addTask {
                        let genericItem = try await GLPIClient.shared.getGenericItem(itemtype: itemtype, id: itemsId)
                        
                        let isDeleted: Bool
                        if let delVal = genericItem["is_deleted"] as? Bool {
                            isDeleted = delVal
                        } else if let delVal = genericItem["is_deleted"] as? Int {
                            isDeleted = (delVal == 1)
                        } else if let delVal = genericItem["is_deleted"] as? String {
                            isDeleted = (delVal == "1" || delVal.lowercased() == "true")
                        } else {
                            isDeleted = false
                        }
                        
                        if isDeleted { return nil }
                        
                        let name = genericItem["name"] as? String ?? "Dispositivo \(itemsId)"
                        let serial = genericItem["serial"] as? String ?? "N/A"
                        
                        let type: AssetType
                        switch itemtype.lowercased() {
                        case "computer": type = .computer
                        case "display", "monitor": type = .monitor
                        case "printer": type = .printer
                        case "networkequipment": type = .network
                        default: type = .network
                        }
                        
                        let resList = try await GLPIClient.shared.getReservationsForItem(resItemId: id)
                        
                        let now = Date()
                        let sdf = DateFormatter()
                        sdf.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        sdf.timeZone = TimeZone(secondsFromGMT: 0)
                        
                        var isReservedNow = false
                        var reservedByStr: String? = nil
                        var activeEndDateStr: String? = nil
                        var activeCommentStr: String? = nil
                        var nextResDateStr: String? = nil
                        
                        var reservationsData: [(begin: Date, end: Date, user: String, comment: String)] = []
                        for res in resList {
                            guard let beginStr = res["begin"] as? String,
                                  let endStr = res["end"] as? String else { continue }
                            
                            let beginDate = sdf.date(from: beginStr) ?? Date()
                            let endDate = sdf.date(from: endStr) ?? Date()
                            
                            var userName = "N/A"
                            if let uField = res["users_id"] {
                                if let uArr = uField as? [Any], uArr.count > 1, let uName = uArr[1] as? String {
                                    userName = uName
                                } else if let uDict = uField as? [String: Any], let uName = uDict["name"] as? String {
                                    userName = uName
                                } else {
                                    userName = String(describing: uField)
                                }
                            }
                            
                            let comment = res["comment"] as? String ?? ""
                            reservationsData.append((begin: beginDate, end: endDate, user: userName, comment: comment))
                        }
                        
                        reservationsData.sort { $0.begin < $1.begin }
                        
                        let displaySdf = DateFormatter()
                        displaySdf.dateFormat = "dd/MM/yyyy HH:mm"
                        displaySdf.locale = Locale(identifier: "pt_PT")
                        
                        let daySdf = DateFormatter()
                        daySdf.dateFormat = "dd/MM/yyyy"
                        daySdf.locale = Locale(identifier: "pt_PT")
                        
                        for res in reservationsData {
                            if now >= res.begin && now <= res.end {
                                isReservedNow = true
                                reservedByStr = formatarStringNome(res.user) ?? res.user
                                activeEndDateStr = displaySdf.string(from: res.end)
                                activeCommentStr = res.comment
                                break
                            }
                        }
                        
                        if !isReservedNow {
                            if let nextRes = reservationsData.first(where: { $0.begin > now }) {
                                nextResDateStr = daySdf.string(from: nextRes.begin)
                            }
                        }
                        
                        let periodStr: String?
                        if isReservedNow, let activeEndDateStr = activeEndDateStr {
                            periodStr = "Até \(activeEndDateStr)"
                        } else if let nextResDateStr = nextResDateStr {
                            periodStr = "Próxima: \(nextResDateStr)"
                        } else {
                            periodStr = nil
                        }
                        
                        return ReservationAsset(
                            reservationItemsId: id,
                            itemtype: itemtype,
                            itemsId: itemsId,
                            name: name,
                            serial: serial,
                            type: type,
                            isReserved: isReservedNow,
                            reservedBy: reservedByStr,
                            reservationDate: periodStr,
                            activeEndDate: activeEndDateStr,
                            activeComment: activeCommentStr,
                            nextReservationDate: nextResDateStr
                        )
                    }
                }
                
                for try await asset in group {
                    if let asset = asset {
                        loadedAssets.append(asset)
                    }
                }
            }
            
            loadedAssets.sort { $0.name.lowercased() < $1.name.lowercased() }
            
            await MainActor.run {
                self.reservations = loadedAssets
                self.isLoading = false
            }
        } catch {
            print("Erro ao carregar reservas: \(error)")
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
            
            Text("RESERVAS")
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicBlueText)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 5)
        .frame(height: GlpiMetrics.navAreaHeight - 5)
    }
}

struct ReservationRow: View {
    let asset: ReservationAsset
    let onRefresh: () -> Void
    let onShowInfo: () -> Void
    @State private var showReserveSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 1. Header do Ativo
            HStack(spacing: 15) {
                Text(asset.name.uppercased())
                    .font(.amiko(size: 14, weight: .black))
                    .foregroundColor(GlpiColors.dynamicBlueText)
                    .lineLimit(1)
                
                Spacer()
                
                GLPIBadge(text: asset.isReserved ? "RESERVADO" : "LIVRE")
            }
            
            // 2. Info Grid
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("S/N")
                        .font(.amiko(size: 9, weight: .bold))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                    Text(asset.serial.uppercased())
                        .font(.amiko(size: 10, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TIPO")
                        .font(.amiko(size: 9, weight: .bold))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                    Text(asset.type.displayName.uppercased())
                        .font(.amiko(size: 10, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if asset.isReserved {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RESERVADO POR")
                            .font(.amiko(size: 9, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                        Text(asset.reservedBy?.uppercased() ?? "N/A")
                            .font(.amiko(size: 10, weight: .black))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Spacer(minLength: 0)
            
            Divider().background(GlpiColors.dynamicText.opacity(0.05))
            
            // 3. Botões de Ação
            HStack(spacing: 12) {
                Button(action: { 
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onShowInfo()
                }) {
                    Text("MAIS INFO")
                        .font(.amiko(size: 10, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .glassStyle(cornerRadius: 12)
                }
                
                Button(action: { 
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showReserveSheet = true 
                }) {
                    Text(asset.isReserved ? "ALTERAR" : "RESERVAR")
                        .font(.amiko(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            Capsule()
                                .fill(GlpiColors.universalBlue)
                        )
                }
            }
        }
        .padding(14)
        .frame(height: 145)
        .glassStyle(cornerRadius: 22)
        .fullScreenCover(isPresented: $showReserveSheet, onDismiss: onRefresh) {
            AssetReservationView(asset: asset)
        }
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
