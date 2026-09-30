//
//  TicketListView.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 22/04/2026.
//

import SwiftUI
import Combine

struct TicketListView: View {
    let title: String
    let statusFilter: TicketStatus?
    let priorityFilter: TicketPriority?
    let isEditMode: Bool
    let isDeleteMode: Bool
    let isPersonalView: Bool
    
    enum SelectionType {
        case delete
        case recover
    }
    
    @State private var selectionType: SelectionType? = nil
    
    init(title: String, statusFilter: TicketStatus? = nil, priorityFilter: TicketPriority? = nil, isEditMode: Bool = false, isDeleteMode: Bool = false, isPersonalView: Bool = false, initialPage: Int = 1) {
        self.title = title
        self.statusFilter = statusFilter
        self.priorityFilter = priorityFilter
        self.isEditMode = isEditMode
        self.isDeleteMode = isDeleteMode
        self.isPersonalView = isPersonalView
        self._currentPage = State(initialValue: initialPage)
    }
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var isAscending = false
    @State private var selectedScope: String = "Geral"
    @State private var showFilterMenu = false
    @State private var selectedStatusFilter = "Todos"
    private let statuses = [
        "Todos",
        "Novo",
        "A processar (atribuído)",
        "A processar (planeado)",
        "Aguardando",
        "Finalizado",
        "Encerrado",
        "Não Finalizado"
    ]
    @State private var showStatusFilterMenu = false
    @State private var selectedTicketForEdit: GLPITicket?
    @State private var selectedTicketForDetail: GLPITicket?
    @State private var selectedTicketForReply: GLPITicket?
    @State private var longPressedTicket: GLPITicket?
    @State private var longPressedTicketY: CGFloat = 0
    @State private var selectedTickets = Set<String>()
    @State private var singleActionTicketId: String? = nil
    @State private var showDeleteAlert = false
    @State private var showRecoverAlert = false
    @State private var showResolveAlert = false
    @State private var expandedTicketId: String? = nil
    @State private var showSelectionIcons = false
    @AppStorage("isLightMode_V2") var isLightMode = true
    @State private var isManualRefresh = false
    
    @State private var tickets: [GLPITicket] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var cancellables = Set<AnyCancellable>()
    
    // Paginação
    @State private var currentPage = 1
    @State private var totalCount = 0
    private var ticketsPerPage: Int {
        title == "ATUALIZAÇÕES" ? 3 : 5
    }
    
    @State private var currentY: CGFloat = 0
    
    var totalPages: Int {
        max(1, Int(ceil(Double(totalCount) / Double(ticketsPerPage))))
    }
    
    private func loadTickets() {
        isLoading = true
        errorMessage = nil
        
        let start = (currentPage - 1) * ticketsPerPage
        let end = start + ticketsPerPage - 1
        let range = "\(start)-\(end)"
        
        var statusVal: Int? = nil
        let startDate: String? = nil
        var currentStatusFilter: TicketStatus? = statusFilter
        
        var userId: Int? = nil
        var isRequesterOnly = false
        var isAssignedOnly = false
        
        if selectedScope == "Criados por mim" {
            userId = PreferenceManager.shared.userId
            isRequesterOnly = true
        } else if selectedScope == "Atribuídos a mim" {
            userId = PreferenceManager.shared.userId
            isAssignedOnly = true
        } else if selectedScope == "Geral" {
            if isPersonalView {
                userId = PreferenceManager.shared.userId
            }
        } else {
            if isPersonalView {
                userId = PreferenceManager.shared.userId
            }
        }
        
        let orderParam = isAscending ? "ASC" : "DESC"
        
        if title == "FINALIZADOS" || title == "PRIORITÁRIOS" || title == "ATUALIZAÇÕES" {
            Task {
                do {
                    let result: ([GLPITicket], Int)
                    if title == "FINALIZADOS" {
                        result = try await GLPIClient.shared.getTicketsFinalizados(userId: userId, isRequesterOnly: isRequesterOnly, isAssignedOnly: isAssignedOnly, range: range, order: orderParam)
                    } else if title == "PRIORITÁRIOS" {
                        result = try await GLPIClient.shared.getTicketsPrioritarios(userId: userId, isRequesterOnly: isRequesterOnly, isAssignedOnly: isAssignedOnly, range: range, order: orderParam)
                    } else {
                        // Para ATUALIZAÇÕES, usamos a mesma lógica de busca recente mas com paginação
                        let response = try await GLPIClient.shared.searchTickets(userId: userId, isRequesterOnly: isRequesterOnly, isAssignedOnly: isAssignedOnly, range: range, sort: "19", order: orderParam)
                        result = (GLPIService.shared.mapToTickets(response.data ?? []), response.totalInt)
                    }
                    
                    await MainActor.run {
                        self.tickets = result.0
                        
                        if title == "ATUALIZAÇÕES" {
                            self.totalCount = min(result.1, 9)
                        } else {
                            self.totalCount = result.1
                        }
                        
                        // ATUALIZAR O WIDGET COM O TICKET MAIS RECENTE
                        if title == "ATUALIZAÇÕES", let first = result.0.first {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm"
                            let timeStr = formatter.string(from: first.date)
                            
                            PreferenceManager.shared.updateWidgetData(
                                title: first.name,
                                desc: first.description,
                                id: first.id,
                                time: timeStr
                            )
                        }
                        
                        self.resolveNames()
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }
            }
        } else {
            // Outras categorias (Novos, Em progresso, Reciclagem, Geral)
            switch title.uppercased() {
            case "NOVOS":
                statusVal = 1
                currentStatusFilter = nil
            case "EM PROGRESSO":
                statusVal = nil
                currentStatusFilter = .assigned
            case "RECICLAGEM", "ELIMINAR":
                statusVal = nil
                currentStatusFilter = nil
            case "PRIORITÁRIOS":
                statusVal = 4
                currentStatusFilter = nil
            default:
                break
            }
            let queryIsDeleted = isDeleteMode || title.uppercased() == "RECICLAGEM" || title.uppercased() == "ELIMINAR"
            let queryFilter = (selectedStatusFilter != "Todos" && !queryIsDeleted) ? selectedStatusFilter : nil
            let querySearch = !searchText.isEmpty ? searchText : nil
            GLPIService.shared.fetchTickets(status: queryIsDeleted ? nil : currentStatusFilter, statusValue: queryIsDeleted ? nil : statusVal, statusQueryString: queryFilter, range: range, startDate: startDate, userId: userId, isRequesterOnly: isRequesterOnly, isAssignedOnly: isAssignedOnly, order: orderParam, searchQuery: querySearch, isDeleted: queryIsDeleted)
                .sink { completion in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                    }
                } receiveValue: { (fetchedTickets, total) in
                    self.tickets = fetchedTickets
                    self.totalCount = total
                    self.resolveNames()
                }
                .store(in: &cancellables)
        }
    }
    
    private func resolveNames() {
        let service = GLPIService.shared
        let resolver = UserNameResolver.shared
        
        for index in tickets.indices {
            let ticketId = tickets[index].id
            
            let reqRaw = tickets[index].requester
            Task {
                let parts = reqRaw.components(separatedBy: " & ")
                var resolvedParts: [String] = []
                for part in parts {
                    let name = await resolver.resolve(id: part, baseURL: service.baseURL, sessionToken: service.sessionToken, appToken: service.appToken)
                    resolvedParts.append(name)
                }
                let finalName = resolvedParts.joined(separator: " & ")
                await MainActor.run {
                    if let currentIdx = self.tickets.firstIndex(where: { $0.id == ticketId }) {
                        self.tickets[currentIdx].requester = finalName
                    }
                }
            }
            
            let assignedRaw = tickets[index].assignedTo
            Task {
                let parts = assignedRaw.components(separatedBy: " & ")
                var resolvedParts: [String] = []
                for part in parts {
                    let name = await resolver.resolve(id: part, baseURL: service.baseURL, sessionToken: service.sessionToken, appToken: service.appToken)
                    resolvedParts.append(name)
                }
                let finalName = resolvedParts.joined(separator: " & ")
                await MainActor.run {
                    if let currentIdx = self.tickets.firstIndex(where: { $0.id == ticketId }) {
                        self.tickets[currentIdx].assignedTo = finalName
                    }
                }
            }
            
            let authorRaw = tickets[index].author
            Task {
                let parts = authorRaw.components(separatedBy: " & ")
                var resolvedParts: [String] = []
                for part in parts {
                    let name = await resolver.resolve(id: part, baseURL: service.baseURL, sessionToken: service.sessionToken, appToken: service.appToken)
                    resolvedParts.append(name)
                }
                let finalName = resolvedParts.joined(separator: " & ")
                await MainActor.run {
                    if let currentIdx = self.tickets.firstIndex(where: { $0.id == ticketId }) {
                        self.tickets[currentIdx].author = finalName
                    }
                }
            }
        }
    }
    
    private func refreshDataAsync() async {
        let start = (currentPage - 1) * ticketsPerPage
        let end = start + ticketsPerPage - 1
        let range = "\(start)-\(end)"
        
        var statusVal: Int? = nil
        let startDate: String? = nil
        var currentStatusFilter: TicketStatus? = statusFilter
        
        var userId: Int? = nil
        var isRequesterOnly = false
        var isAssignedOnly = false
        
        if selectedScope == "Criados por mim" {
            userId = PreferenceManager.shared.userId
            isRequesterOnly = true
        } else if selectedScope == "Atribuídos a mim" {
            userId = PreferenceManager.shared.userId
            isAssignedOnly = true
        } else {
            if isPersonalView {
                userId = PreferenceManager.shared.userId
            }
        }
        
        let orderParam = isAscending ? "ASC" : "DESC"
        
        if title == "FINALIZADOS" || title == "PRIORITÁRIOS" || title == "ATUALIZAÇÕES" {
            do {
                let result: ([GLPITicket], Int)
                if title == "FINALIZADOS" {
                    result = try await GLPIClient.shared.getTicketsFinalizados(userId: userId, isRequesterOnly: isRequesterOnly, isAssignedOnly: isAssignedOnly, range: range, order: orderParam)
                } else if title == "PRIORITÁRIOS" {
                    result = try await GLPIClient.shared.getTicketsPrioritarios(userId: userId, isRequesterOnly: isRequesterOnly, isAssignedOnly: isAssignedOnly, range: range, order: orderParam)
                } else {
                    let response = try await GLPIClient.shared.searchTickets(userId: userId, isRequesterOnly: isRequesterOnly, isAssignedOnly: isAssignedOnly, range: range, sort: "19", order: orderParam)
                    result = (GLPIService.shared.mapToTickets(response.data ?? []), response.totalInt)
                }
                
                await MainActor.run {
                    self.tickets = result.0
                    if title == "ATUALIZAÇÕES" { self.totalCount = min(result.1, 9) } else { self.totalCount = result.1 }
                    self.resolveNames()
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
            }
        } else {
            switch title.uppercased() {
            case "NOVOS": statusVal = 1; currentStatusFilter = nil
            case "EM PROGRESSO": statusVal = nil; currentStatusFilter = .assigned
            case "RECICLAGEM", "ELIMINAR": statusVal = nil; currentStatusFilter = nil
            case "PRIORITÁRIOS": statusVal = 4; currentStatusFilter = nil
            default: break
            }
            let queryIsDeleted = isDeleteMode || title.uppercased() == "RECICLAGEM" || title.uppercased() == "ELIMINAR"
            let queryFilter = (selectedStatusFilter != "Todos" && !queryIsDeleted) ? selectedStatusFilter : nil
            let querySearch = !searchText.isEmpty ? searchText : nil
            
            await withCheckedContinuation { continuation in
                GLPIService.shared.fetchTickets(status: queryIsDeleted ? nil : currentStatusFilter, statusValue: queryIsDeleted ? nil : statusVal, statusQueryString: queryFilter, range: range, startDate: startDate, userId: userId, isRequesterOnly: isRequesterOnly, isAssignedOnly: isAssignedOnly, order: orderParam, searchQuery: querySearch, isDeleted: queryIsDeleted)
                    .sink { completion in
                        if case .failure(let error) = completion {
                            DispatchQueue.main.async {
                                self.errorMessage = error.localizedDescription
                                continuation.resume()
                            }
                        }
                    } receiveValue: { (fetchedTickets, total) in
                        DispatchQueue.main.async {
                            self.tickets = fetchedTickets
                            self.totalCount = total
                            self.resolveNames()
                            continuation.resume()
                        }
                    }
                    .store(in: &cancellables)
            }
        }
    }

    
    var filteredTickets: [GLPITicket] {
        let filtered = tickets.filter { ticket in
            searchText.isEmpty || 
            ticket.name.localizedCaseInsensitiveContains(searchText) || 
            ticket.id.localizedCaseInsensitiveContains(searchText)
        }
        
        if title == "ATUALIZAÇÕES" {
            // A API já devolve ordenado por modificação (sort=19), não devemos ordenar por data de criação.
            return isAscending ? filtered.reversed() : filtered
        }
        
        return filtered.sorted { t1, t2 in
            isAscending ? t1.date < t2.date : t1.date > t2.date
        }
    }
    
    private func ticketCard(ticket: GLPITicket, isPaged: Bool = false) -> some View {
        let isSelected = selectedTickets.contains(ticket.id)
        let isExpanded = expandedTicketId == ticket.id
        let selColor: Color = selectionType == .delete ? .red : GlpiColors.universalBlue
        let isDelMode = (isDeleteMode || selectionType != nil) && showSelectionIcons
        
        return TicketRowView(
            ticket: ticket,
            isSelected: isSelected,
            selectionColor: selColor,
            isExpanded: isExpanded,
            isDeleteMode: isDelMode,
            listCategory: title,
            onLongPress: { yPos in
                if !isPaged {
                    longPressedTicketY = yPos
                    withAnimation(.spring()) {
                        longPressedTicket = ticket
                    }
                }
            },
            onSelect: {
                if showSelectionIcons {
                    if isSelected {
                        selectedTickets.remove(ticket.id)
                    } else {
                        selectedTickets.insert(ticket.id)
                    }
                    
                    if selectedTickets.isEmpty {
                        withAnimation { 
                            showSelectionIcons = false
                            selectionType = nil
                        }
                    }
                } else {
                    let nextId = isExpanded ? nil : ticket.id
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        expandedTicketId = nextId
                    }
                    if let newId = nextId, let index = tickets.firstIndex(where: { $0.id == newId }) {
                        let t = tickets[index]
                        if t.responses.isEmpty {
                            fetchResponses(for: t)
                        }
                    }
                }
            },
            currentY: $currentY
        )
    }
    
    var body: some View {
        ZStack {
            (isLightMode ? Color.white : Color.black).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Navegação Superior (Seta de voltar - Universal)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(GlpiColors.universalBlue)
                    }
                    .padding(.leading, GlpiMetrics.padding + 5)
                    
                    Spacer()
                }
                .padding(.top, 5)
                .frame(height: GlpiMetrics.navAreaHeight - 5) // Ajuste para totalizar 60px
                
                // 2. Barra de Pesquisa (Posicionamento Intocável)
                GLPISearchHeader(
                    searchText: $searchText,
                    placeholder: isDeleteMode ? "Pesquisar na reciclagem..." : "Pesquisar em \(title.lowercased())...",
                    rightIcon: title == "ATUALIZAÇÕES" ? nil : "arrow.up.arrow.down",
                    isSystemIcon: true,
                    isRightIconSelected: isAscending,
                    rightIconAction: {
                        if title != "ATUALIZAÇÕES" {
                            withAnimation { isAscending.toggle() }
                        }
                    },
                    filterIcon: title == "VISTA GERAL" ? "line.3.horizontal.decrease.circle" : nil,
                    isFilterIconSelected: selectedStatusFilter != "Todos",
                    filterIconAction: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showStatusFilterMenu = true
                        }
                    }
                )
                .padding(.top, 0)
                .padding(.bottom, 15)
                
                if title == "ATUALIZAÇÕES" {
                    // MODO PÁGINA (Paginado de 3 em 3)
                    VStack(spacing: 0) {
                        TabView(selection: $currentPage) {
                            ForEach(1...max(1, totalPages), id: \.self) { pageNum in
                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 16) {
                                        ForEach(filteredTickets) { ticket in
                                            ticketCard(ticket: ticket, isPaged: true)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 5)
                                }
                                .scrollContentBackground(.hidden)
                                .scrollDismissesKeyboard(.immediately)
                                .refreshable {
                                    isManualRefresh = true
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    await refreshDataAsync()
                                    isManualRefresh = false
                                }
                                .tag(pageNum)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .background(Color.clear)
                        .frame(height: 580)
                        
                        // Barra de Navegação Universal para Páginas
                        paginationBar()
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                    }
                    .onChange(of: currentPage) { _ in
                        loadTickets()
                    }
                } else {
                    // MODO LISTA NORMAL (Scroll Contínuo com Paginação no fundo)
                    ScrollView(showsIndicators: false) {
                        ScrollViewReader { proxy in
                            VStack(spacing: 16) {
                                Color.clear.frame(height: 1).id("LIST_TOP")
                                
                                if tickets.isEmpty && !isLoading {
                                    VStack {
                                        Spacer(minLength: 250)
                                        Text("O servidor não devolveu nenhum ticket para esta categoria.")
                                            .font(.amiko(size: 16))
                                            .foregroundColor(.white.opacity(0.6))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 30)
                                        Spacer()
                                    }
                                } else {
                                    ForEach(filteredTickets) { ticket in
                                        ticketCard(ticket: ticket)
                                    }
                                    
                                    // PAGINAÇÃO (ESTILO UNIVERSAL)
                                    paginationBar()
                                        .padding(.top, 10)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 120)
                            .background(isLightMode ? Color.white : Color.black)
                            .onChange(of: currentPage) { _, _ in
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    proxy.scrollTo("LIST_TOP", anchor: .top)
                                }
                                loadTickets()
                            }
                        }
                    }
                    .background(isLightMode ? Color.white : Color.black)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.immediately)
                    .refreshable {
                        isManualRefresh = true
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        await refreshDataAsync()
                        isManualRefresh = false
                    }
                }
            }
            .blur(radius: (showFilterMenu || showStatusFilterMenu || longPressedTicket != nil) ? 8 : 0)
            .animation(.spring(), value: showFilterMenu || showStatusFilterMenu || longPressedTicket != nil)
            
            if showFilterMenu {
                TicketFilterOverlay(
                    isPresented: $showFilterMenu,
                    selectedScope: $selectedScope,
                    isEditMode: isEditMode,
                    isDeleteMode: isDeleteMode,
                    title: title
                )
            }
            
            if showStatusFilterMenu {
                TicketStatusFilterOverlay(
                    isPresented: $showStatusFilterMenu,
                    selectedStatus: $selectedStatusFilter
                )
            }
            
            if let ticket = longPressedTicket {
                TicketQuickActionsOverlay(
                    ticket: ticket,
                    isDeleteMode: isDeleteMode,
                    listCategory: title,
                    onDismiss: { withAnimation(.spring()) { longPressedTicket = nil } },
                    onEdit: {
                        selectedTicketForEdit = ticket
                        longPressedTicket = nil
                    },
                    onReply: {
                        selectedTicketForReply = ticket
                        longPressedTicket = nil
                    },
                    onDelete: {
                        singleActionTicketId = ticket.id
                        showDeleteAlert = true
                    },
                    onResolve: {
                        showResolveAlert = true
                    },
                    onPermanentDelete: {
                        withAnimation {
                            expandedTicketId = nil
                            selectionType = .delete
                            selectedTickets = [ticket.id]
                            showSelectionIcons = true
                        }
                        longPressedTicket = nil
                    },
                    onRecover: {
                        withAnimation {
                            expandedTicketId = nil
                            selectionType = .recover
                            selectedTickets = [ticket.id]
                            showSelectionIcons = true
                        }
                        longPressedTicket = nil
                    }
                )
            }
            
            if !selectedTickets.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        if selectionType == .recover {
                            // Botão Recuperar (AZUL UNIVERSAL)
                            Button(action: {
                                showRecoverAlert = true
                            }) {
                                Text("RECUPERAR SELECIONADOS")
                                    .font(.amiko(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(
                                        Capsule()
                                            .fill(GlpiColors.universalBlue)
                                            .shadow(color: GlpiColors.universalBlue.opacity(0.4), radius: 15)
                                    )
                            }
                        } else if selectionType == .delete {
                            // Botão Eliminar (VERMELHO)
                            Button(action: { showDeleteAlert = true }) {
                                Text(selectedScope == "Reciclagem" ? "ELIMINAR SELECIONADOS" : "ENVIAR SELECIONADOS PARA A RECICLAGEM")
                                    .font(.amiko(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(
                                        Capsule()
                                            .fill(Color.red)
                                            .shadow(color: .red.opacity(0.4), radius: 15)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if isLoading && !isManualRefresh {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                        .scaleEffect(1.5)
                }
            }
        }
        .alert("CONFIRMAÇÃO", isPresented: $showRecoverAlert) {
            Button("CANCELAR", role: .cancel) { 
                singleActionTicketId = nil
            }
            Button("RECUPERAR", role: .none) {
                let idsToRecover = singleActionTicketId != nil ? [singleActionTicketId!] : Array(selectedTickets)
                Task {
                    isLoading = true
                    do {
                        for id in idsToRecover {
                            _ = try await GLPIClient.shared.restoreTicket(id: id)
                        }
                        await MainActor.run {
                            withAnimation {
                                tickets.removeAll { idsToRecover.contains($0.id) }
                                if singleActionTicketId == nil {
                                    selectedTickets.removeAll()
                                    showSelectionIcons = false
                                    selectionType = nil
                                }
                                singleActionTicketId = nil
                                longPressedTicket = nil
                            }
                            loadTickets()
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            isLoading = false
                        }
                    }
                }
            }
        } message: {
            Text("Tem a certeza que pretende recuperar estes tickets?")
        }
        
        .alert("CONFIRMAÇÃO", isPresented: $showDeleteAlert) {
            Button("CANCELAR", role: .cancel) { 
                singleActionTicketId = nil
                if selectedTickets.isEmpty {
                    showSelectionIcons = false
                }
            }
            Button(selectedScope == "Reciclagem" ? "ELIMINAR" : "ELIMINAR", role: .destructive) {
                let idsToDelete = singleActionTicketId != nil ? [singleActionTicketId!] : Array(selectedTickets)
                Task {
                    isLoading = true
                    do {
                        if selectedScope == "Reciclagem" {
                            for id in idsToDelete {
                                _ = try await GLPIClient.shared.purgeTicket(id: id)
                            }
                        } else {
                            for id in idsToDelete {
                                _ = try await GLPIClient.shared.trashTicket(id: id)
                            }
                        }
                        await MainActor.run {
                            withAnimation {
                                tickets.removeAll { idsToDelete.contains($0.id) }
                                if singleActionTicketId == nil {
                                    selectedTickets.removeAll()
                                    showSelectionIcons = false
                                    selectionType = nil
                                }
                                singleActionTicketId = nil
                                longPressedTicket = nil
                            }
                            loadTickets()
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            isLoading = false
                        }
                    }
                }
            }
        } message: {
            Text(selectedScope == "Reciclagem" ? "Tem a certeza que quer eliminar permanentemente estes tickets?" : "Tem a certeza que quer enviar para a reciclagem?")
        }
        .alert("RESOLVER TICKET", isPresented: $showResolveAlert) {
            Button("CANCELAR", role: .cancel) { }
            Button("CONFIRMAR", role: .none) {
                if let ticketId = longPressedTicket?.id {
                    if let index = tickets.firstIndex(where: { $0.id == ticketId }) {
                        let original = tickets[index]
                        tickets[index] = GLPITicket(
                            id: original.id,
                            name: original.name,
                            requester: original.requester,
                            author: original.author,
                            assignedTo: original.assignedTo,
                            description: original.description,
                            date: original.date,
                            priority: original.priority,
                            status: .resolved,
                            rawStatus: "5",
                            isMine: original.isMine,
                            isAssignedToMe: original.isAssignedToMe,
                            responses: original.responses
                        )
                    }
                }
                longPressedTicket = nil
            }
        } message: {
            Text("Tem a certeza que pretende marcar este ticket como finalizado?")
        }
        .sheet(item: $selectedTicketForReply) { ticket in
            TicketReplyView(ticket: ticket)
        }
        .sheet(item: $selectedTicketForDetail) { ticket in
            TicketDetailView(ticket: ticket)
        }
        .sheet(item: $selectedTicketForEdit) { ticket in
            TicketEditView(ticket: ticket)
        }
        .navigationBarHidden(true)
        .onAppear {
            if isDeleteMode {
                selectedScope = "Reciclagem"
            }
            loadTickets()
        }
        .onChange(of: selectedScope) { _, _ in
            currentPage = 1
            loadTickets()
        }
        .onChange(of: isAscending) { _, _ in
            currentPage = 1
            loadTickets()
        }
        .onChange(of: selectedStatusFilter) { _, _ in
            currentPage = 1
            loadTickets()
        }
        .onChange(of: searchText) { _, _ in
            searchTask?.cancel()
            searchTask = Task {
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    await MainActor.run {
                        currentPage = 1
                        loadTickets()
                    }
                } catch {
                    // Ignore cancellation
                }
            }
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
    }
    
    // MARK: - Componentes Auxiliares
    
    private func paginationBar() -> some View {
        Group {
            if totalPages > 1 {
                HStack(spacing: 0) {
                    Button(action: {
                        if currentPage > 1 {
                            withAnimation(.spring()) { currentPage -= 1 }
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
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 24)
                    
                    Spacer()
                    
                    Button(action: {
                        if currentPage < totalPages {
                            withAnimation(.spring()) { currentPage += 1 }
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
                .glassStyle(cornerRadius: 15)
            }
        }
    }
    
    private func fetchResponses(for ticket: GLPITicket) {
        let service = GLPIService.shared
        let resolver = UserNameResolver.shared
        
        let ticketId = ticket.id
        
        Publishers.Zip(
            service.fetchTicketFollowups(ticketId: ticketId),
            service.fetchTicketSolutions(ticketId: ticketId)
        )
        .receive(on: DispatchQueue.global(qos: .userInitiated))
        .sink(receiveCompletion: { _ in }) { (followups, solutions) in
            
            var combined = followups.map { f -> TicketResponse in
                var res = f
                res.isSolution = false
                return res
            } + solutions.map { s -> TicketResponse in
                var res = s
                res.isSolution = true
                return res
            }
            
            combined.sort { $1.date < $0.date }
            
            Task {
                var resolvedResponses: [TicketResponse] = []
                for response in combined {
                    let authorId = response.author
                    let resolvedName = await resolver.resolve(id: authorId, baseURL: service.baseURL, sessionToken: service.sessionToken, appToken: service.appToken)
                    
                    let prefix = response.isSolution ? "SOLUÇÃO" : "RESPOSTA"
                    let updatedResponse = TicketResponse(
                        author: "\(prefix) - \(resolvedName)",
                        content: response.content,
                        date: response.date,
                        isInternal: response.isInternal,
                        isSolution: response.isSolution
                    )
                    resolvedResponses.append(updatedResponse)
                }
                
                await MainActor.run {
                    if let idx = self.tickets.firstIndex(where: { $0.id == ticketId }) {
                        self.tickets[idx].responses = resolvedResponses
                    }
                }
            }
        }
        .store(in: &cancellables)
    }
}
