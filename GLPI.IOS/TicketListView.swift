//
//  TicketListView.swift
//  GLPI.IOS
//
//  Created by Antigravity on 22/04/2026.
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
    @State private var isAscending = false
    @State private var selectedScope: String = "Geral"
    @State private var showFilterMenu = false
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
    
    @State private var tickets: [GLPITicket] = []
    @State private var isLoading = false
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
        let userId = isPersonalView ? PreferenceManager.shared.userId : nil
        
        if title == "RESOLVIDOS" || title == "PRIORITÁRIOS" || title == "ATUALIZAÇÕES" {
            Task {
                do {
                    let result: ([GLPITicket], Int)
                    if title == "RESOLVIDOS" {
                        result = try await GLPIClient.shared.getTicketsResolvidos(userId: userId, range: range)
                    } else if title == "PRIORITÁRIOS" {
                        result = try await GLPIClient.shared.getTicketsPrioritarios(userId: userId, range: range)
                    } else {
                        // Para ATUALIZAÇÕES, usamos a mesma lógica de busca recente mas com paginação
                        let response = try await GLPIClient.shared.searchTickets(range: range, sort: "19", order: "DESC")
                        result = (GLPIService.shared.mapToTickets(response.data ?? []), response.totalInt)
                    }
                    
                    await MainActor.run {
                        self.tickets = result.0
                        self.totalCount = result.1
                        
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
            switch selectedScope {
            case "Novos":
                statusVal = 1
                currentStatusFilter = nil
            case "Em progresso":
                statusVal = nil
                currentStatusFilter = .assigned
            case "Reciclagem":
                statusVal = 6
                currentStatusFilter = nil
            case "Prioritários":
                statusVal = 4
                currentStatusFilter = nil
            default:
                break
            }
            
            GLPIService.shared.fetchTickets(status: currentStatusFilter, statusValue: statusVal, range: range, startDate: startDate, userId: userId)
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
        }
    }
    
    var filteredTickets: [GLPITicket] {
        let filtered = tickets.filter { ticket in
            searchText.isEmpty || 
            ticket.name.localizedCaseInsensitiveContains(searchText) || 
            ticket.id.localizedCaseInsensitiveContains(searchText)
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        expandedTicketId = isExpanded ? nil : ticket.id
                    }
                }
            },
            currentY: $currentY
        )
    }
    
    var body: some View {
        ZStack {
            GlpiColors.background.ignoresSafeArea()
            
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
                    }
                )
                .padding(.top, 0)
                .padding(.bottom, 15)
                
                if title == "ATUALIZAÇÕES" {
                    // MODO PÁGINA (Paginado de 3 em 3)
                    ZStack {
                        if isLoading && tickets.isEmpty {
                            VStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                                    .scaleEffect(1.5)
                                Spacer()
                            }
                        } else {
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
                                        .tag(pageNum)
                                    }
                                }
                                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                .frame(height: 580)
                                
                                // Barra de Navegação Universal para Páginas
                                paginationBar()
                                    .padding(.horizontal, 16)
                                    .padding(.top, 10)
                                    .padding(.bottom, 20)
                            }
                        }
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
                            .onChange(of: currentPage) { _, _ in
                                withAnimation { proxy.scrollTo("LIST_TOP", anchor: .top) }
                                loadTickets()
                            }
                        }
                    }
                }
            }
            .blur(radius: (showFilterMenu || longPressedTicket != nil) ? 20 : 0)
            .animation(.spring(), value: showFilterMenu || longPressedTicket != nil)
            
            if showFilterMenu {
                TicketFilterOverlay(
                    isPresented: $showFilterMenu,
                    selectedScope: $selectedScope,
                    isEditMode: isEditMode,
                    isDeleteMode: isDeleteMode,
                    title: title
                )
            }
            
            if let ticket = longPressedTicket {
                TicketQuickActionsOverlay(
                    ticket: ticket,
                    isDeleteMode: isDeleteMode,
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
        }
        .alert("CONFIRMAÇÃO", isPresented: $showRecoverAlert) {
            Button("CANCELAR", role: .cancel) { 
                singleActionTicketId = nil
            }
            Button("RECUPERAR", role: .none) {
                withAnimation {
                    let idsToRecover = singleActionTicketId != nil ? [singleActionTicketId!] : Array(selectedTickets)
                    
                    for id in idsToRecover {
                        if let index = tickets.firstIndex(where: { $0.id == id }) {
                            let original = tickets[index]
                            let recovered = GLPITicket(
                                id: original.id,
                                name: original.name,
                                requester: original.requester,
                                author: original.author,
                                assignedTo: original.assignedTo,
                                description: original.description,
                                date: original.date,
                                priority: original.priority,
                                status: .new,
                                isMine: original.isMine,
                                isAssignedToMe: original.isAssignedToMe,
                                responses: original.responses
                            )
                            tickets.remove(at: index)
                        }
                    }
                    
                    if singleActionTicketId == nil {
                        selectedTickets.removeAll()
                        showSelectionIcons = false
                        selectionType = nil
                    }
                    singleActionTicketId = nil
                    longPressedTicket = nil
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
                
                if selectedScope == "Reciclagem" {
                    tickets.removeAll { idsToDelete.contains($0.id) }
                } else {
                    for id in idsToDelete {
                        if let index = tickets.firstIndex(where: { t in t.id == id }) {
                            let original = tickets[index]
                            tickets[index] = GLPITicket(id: original.id, name: original.name, requester: original.requester, author: original.author, assignedTo: original.assignedTo, description: original.description, date: original.date, priority: original.priority, status: .deleted, isMine: original.isMine, isAssignedToMe: original.isAssignedToMe)
                        }
                    }
                }
                
                if singleActionTicketId == nil {
                    selectedTickets.removeAll()
                    showSelectionIcons = false
                    selectionType = nil
                }
                singleActionTicketId = nil
                longPressedTicket = nil
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
                            isMine: original.isMine,
                            isAssignedToMe: original.isAssignedToMe,
                            responses: original.responses
                        )
                    }
                }
                longPressedTicket = nil
            }
        } message: {
            Text("Tem a certeza que pretende marcar este ticket como resolvido?")
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
}
