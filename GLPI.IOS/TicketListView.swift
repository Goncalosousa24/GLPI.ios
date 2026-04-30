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
    
    init(title: String, statusFilter: TicketStatus? = nil, priorityFilter: TicketPriority? = nil, isEditMode: Bool = false, isDeleteMode: Bool = false, isPersonalView: Bool = false) {
        self.title = title
        self.statusFilter = statusFilter
        self.priorityFilter = priorityFilter
        self.isEditMode = isEditMode
        self.isDeleteMode = isDeleteMode
        self.isPersonalView = isPersonalView
    }
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isAscending = false
    @State private var selectedScope: String = "Geral"
    @State private var showFilterMenu = false
    @State private var selectedTicketForEdit: GLPITicket?
    @State private var selectedTicketForReply: GLPITicket?
    @State private var longPressedTicket: GLPITicket?
    @State private var longPressedTicketY: CGFloat = 0
    @State private var selectedTickets = Set<String>()
    @State private var showDeleteAlert = false
    
    @State private var tickets: [GLPITicket] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var cancellables = Set<AnyCancellable>()
    
    // Paginação
    @State private var currentPage = 1
    @State private var totalCount = 0
    private let ticketsPerPage = 5
    
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
        
        if title == "RESOLVIDOS" || title == "PRIORITÁRIOS" {
            Task {
                do {
                    let result: ([GLPITicket], Int)
                    if title == "RESOLVIDOS" {
                        result = try await GLPIClient.shared.getTicketsResolvidos(userId: userId, range: range)
                    } else {
                        result = try await GLPIClient.shared.getTicketsPrioritarios(userId: userId, range: range)
                    }
                    
                    await MainActor.run {
                        self.tickets = result.0
                        self.totalCount = result.1
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
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .glassStyle(cornerRadius: 12)
                    }
                    Spacer()
                    Text(title)
                        .font(.inconsolata(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                // Search & Tools
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.4))
                        TextField("", text: $searchText, prompt: Text("Pesquisar...").foregroundColor(.white.opacity(0.3)))
                            .foregroundColor(.white)
                            .font(.amiko(size: 16))
                    }
                    .padding()
                    .glassStyle(cornerRadius: 15)
                    
                    Button(action: { withAnimation { showFilterMenu.toggle() } }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(selectedScope == "Geral" ? .white : .blue)
                            .frame(width: 54, height: 54)
                            .glassStyle(cornerRadius: 15, isSelection: selectedScope != "Geral")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 25)
                
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
                                    TicketRowView(
                                        ticket: ticket,
                                        isSelected: selectedTickets.contains(ticket.id),
                                        isDeleteMode: isDeleteMode,
                                        onLongPress: { yPos in
                                            longPressedTicketY = yPos
                                            withAnimation(.spring()) {
                                                longPressedTicket = ticket
                                            }
                                        },
                                        onSelect: {
                                            if isDeleteMode {
                                                if selectedTickets.contains(ticket.id) {
                                                    selectedTickets.remove(ticket.id)
                                                } else {
                                                    selectedTickets.insert(ticket.id)
                                                }
                                            } else {
                                                selectedTicketForEdit = ticket
                                            }
                                        },
                                        currentY: $currentY
                                    )
                                }
                                
                                // PAGINAÇÃO (ESTILO ORIGINAL)
                                if totalPages > 1 {
                                    HStack(spacing: 0) {
                                        Button(action: {
                                            if currentPage > 1 { withAnimation { currentPage -= 1 } }
                                        }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
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
                                            if currentPage < totalPages { withAnimation { currentPage += 1 } }
                                        }) {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                                .opacity(currentPage == totalPages ? 0.2 : 1.0)
                                                .frame(width: 50, height: 50)
                                        }
                                        .disabled(currentPage == totalPages)
                                    }
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .glassStyle(cornerRadius: 15)
                                    .padding(.top, 10)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                        .onChange(of: currentPage) { oldValue, newValue in
                            withAnimation { proxy.scrollTo("LIST_TOP", anchor: .top) }
                            loadTickets()
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
                        showDeleteAlert = true
                    },
                    isReciclagem: selectedScope == "Reciclagem"
                )
            }
            
            if isDeleteMode && !selectedTickets.isEmpty {
                VStack {
                    Spacer()
                    Button(action: { showDeleteAlert = true }) {
                        Text(selectedScope == "Reciclagem" ? "ELIMINAR PERMANENTEMENTE (\(selectedTickets.count))" : "ENVIAR PARA A RECICLAGEM (\(selectedTickets.count))")
                            .font(.amiko(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                                    .shadow(color: .red.opacity(0.4), radius: 15)
                            )
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 120)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("CONFIRMAÇÃO", isPresented: $showDeleteAlert) {
            Button("CANCELAR", role: .cancel) { longPressedTicket = nil }
            Button(selectedScope == "Reciclagem" ? "ELIMINAR PARA SEMPRE" : "ELIMINAR", role: .destructive) {
                if selectedScope == "Reciclagem" {
                    tickets.removeAll { selectedTickets.contains($0.id) }
                } else {
                    for id in selectedTickets {
                        if let index = tickets.firstIndex(where: { t in t.id == id }) {
                            let original = tickets[index]
                            tickets[index] = GLPITicket(id: original.id, name: original.name, requester: original.requester, assignedTo: original.assignedTo, description: original.description, date: original.date, priority: original.priority, status: .deleted, isMine: original.isMine, isAssignedToMe: original.isAssignedToMe)
                        }
                    }
                }
                selectedTickets.removeAll()
                longPressedTicket = nil
            }
        } message: {
            Text(selectedScope == "Reciclagem" ? "Tem a certeza que quer eliminar permanentemente estes tickets?" : "Tem a certeza que quer enviar para a reciclagem?")
        }
        .sheet(item: $selectedTicketForEdit) { ticket in
            TicketEditView(ticket: ticket)
        }
        .sheet(item: $selectedTicketForReply) { ticket in
            TicketReplyView(ticket: ticket)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadTickets()
        }
    }
}
