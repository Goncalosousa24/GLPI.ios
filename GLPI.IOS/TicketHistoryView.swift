//
//  TicketHistoryView.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 22/04/2026.
//

import SwiftUI
import Combine

struct TicketHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLightMode_V2") var isLightMode = true
    @State var searchText = ""
    @State var selectedFilter: String? = nil
    @State var currentPage = 1
    @State var filterPageIndex = 0
    @State private var resolvedUserName = ""
    
    // Novas variáveis de estado para API real
    @State private var tickets: [GLPITicket] = []
    @State private var isLoading = true
    @State private var expandedTicketId: String? = nil
    @State private var currentY: CGFloat = 0
    @State private var cancellables = Set<AnyCancellable>()
    
    private var pillWidth: CGFloat {
        let screenWidth = UIScreen.screenWidth
        let padding: CGFloat = 32
        let arrowButtonWidth: CGFloat = 72 + 12
        let spacing: CGFloat = 12
        return (screenWidth - padding - arrowButtonWidth - spacing) / 2
    }
    
    private var currentFilters: [String] {
        let chunkSize = 2
        let start = filterPageIndex * chunkSize
        let end = min(start + chunkSize, filters.count)
        return Array(filters[start..<end])
    }
    
    private var totalFilterPages: Int {
        Int(ceil(Double(filters.count) / 2.0))
    }
    
    let allowedTypes = ["Computer", "Monitor", "Printer", "NetworkEquipment"]
    let filters = ["Criados", "Requerente", "Atribuído", "Observador"]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: "pt_PT")
        return formatter
    }
    
    private func mapStatusToString(_ status: TicketStatus) -> String {
        switch status {
        case .new: return "Novo"
        case .assigned: return "Atribuído"
        case .planned: return "Planeado"
        case .waiting: return "Aguardando"
        case .resolved: return "Finalizado"
        case .deleted: return "Cancelado"
        }
    }
    
    // Retorna todos os tickets para o histórico geral do perfil (removido o filtro de tipos de equipamentos restritos)
    var deviceTickets: [GLPITicket] {
        tickets
    }
    
    private func compareNames(_ name1: String, _ name2: String) -> Bool {
        let n1 = name1.lowercased().folding(options: .diacriticInsensitive, locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
        let n2 = name2.lowercased().folding(options: .diacriticInsensitive, locale: .current).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if n1.isEmpty || n2.isEmpty { return false }
        if n1 == n2 { return true }
        
        if n1.contains(n2) || n2.contains(n1) { return true }
        
        let words1 = n1.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 1 }
        let words2 = n2.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 1 }
        
        let ignoreList: Set<String> = ["de", "do", "da", "dos", "das", "e"]
        let cleanWords1 = words1.filter { !ignoreList.contains($0) }
        let cleanWords2 = words2.filter { !ignoreList.contains($0) }
        
        let set1 = Set(cleanWords1)
        let set2 = Set(cleanWords2)
        
        let intersection = set1.intersection(set2)
        
        if intersection.count >= 2 {
            return true
        }
        if (cleanWords1.count == 1 || cleanWords2.count == 1) && intersection.count >= 1 {
            return true
        }
        
        return false
    }
    
    private func ticketMatchesFilter(_ ticket: GLPITicket, filter: String) -> Bool {
        let userLower = resolvedUserName
        if userLower.isEmpty { return true }
        
        switch filter {
        case "Criados":
            return compareNames(ticket.author, userLower)
        case "Requerente":
            return compareNames(ticket.requester, userLower)
        case "Atribuído":
            return compareNames(ticket.assignedTo, userLower) || ticket.assignedTo.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "eu"
        case "Observador":
            return compareNames(ticket.observer, userLower)
        default:
            return true
        }
    }
    
    var filteredTickets: [GLPITicket] {
        let filtered = deviceTickets.filter { ticket in
            let matchesSearch = searchText.isEmpty || ticket.name.lowercased().contains(searchText.lowercased()) || ticket.description.lowercased().contains(searchText.lowercased())
            let matchesFilter: Bool
            if let selected = selectedFilter {
                matchesFilter = ticketMatchesFilter(ticket, filter: selected)
            } else {
                matchesFilter = true
            }
            return matchesSearch && matchesFilter
        }
        
        let startIndex = (currentPage - 1) * 5
        let endIndex = min(startIndex + 5, filtered.count)
        
        if startIndex >= filtered.count { return [] }
        return Array(filtered[startIndex..<endIndex])
    }
    
    private var totalPages: Int {
        let filteredCount = deviceTickets.filter { ticket in
            let matchesSearch = searchText.isEmpty || ticket.name.lowercased().contains(searchText.lowercased()) || ticket.description.lowercased().contains(searchText.lowercased())
            let matchesFilter: Bool
            if let selected = selectedFilter {
                matchesFilter = ticketMatchesFilter(ticket, filter: selected)
            } else {
                matchesFilter = true
            }
            return matchesSearch && matchesFilter
        }.count
        return max(1, Int(ceil(Double(filteredCount) / 5.0)))
    }
    
    func loadTickets() {
        isLoading = true
        let userId = PreferenceManager.shared.userId
        let isOffline = PreferenceManager.shared.isOfflineMode
        let nameToResolve = isOffline ? (PreferenceManager.shared.userName ?? "Utilizador") : String(userId)
        
        Task {
            do {
                // Primeiro resolve o nome do utilizador ativo
                let resolved = await UserNameResolver.shared.resolve(
                    id: nameToResolve,
                    baseURL: PreferenceManager.shared.baseURL,
                    sessionToken: PreferenceManager.shared.sessionToken,
                    appToken: PreferenceManager.shared.appToken
                )
                
                // Obter os últimos 150 tickets do utilizador
                let response = try await GLPIClient.shared.searchTickets(userId: userId, range: "0-150")
                let mapped = GLPIService.shared.mapToTickets(response.data ?? [])
                
                await MainActor.run {
                    self.resolvedUserName = resolved
                    self.tickets = mapped
                    self.resolveNames()
                    self.isLoading = false
                }
            } catch {
                print("Erro ao carregar histórico de tickets: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            (isLightMode ? Color.white : Color.black).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Cabeçalho Universal (Seta de Voltar)
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
                .frame(height: GlpiMetrics.navAreaHeight)
                
                ScrollViewReader { listProxy in
                    VStack(spacing: 0) {
                        // Barra de Pesquisa - FIXA fora do ScrollView
                        GLPISearchHeader(
                            searchText: $searchText,
                            placeholder: "Pesquisar no histórico..."
                        )
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        
                        // Filtros Horizontais - FIXOS fora do ScrollView
                        HStack(spacing: 12) {
                            HStack(spacing: 12) {
                                ForEach(currentFilters, id: \.self) { filter in
                                    FilterPill(title: filter, isSelected: selectedFilter == filter, width: pillWidth) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if selectedFilter == filter {
                                                selectedFilter = nil
                                            } else {
                                                selectedFilter = filter
                                            }
                                            currentPage = 1
                                        }
                                    }
                                    .id(filter)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("FilterPage_\(filterPageIndex)")
                            
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
                            .overlay(Capsule().stroke(isLightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.15), lineWidth: 0.5))
                        }
                        .frame(height: 50)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 15)
                        
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 25) {
                                Color.clear.frame(height: 1).id("LIST_TOP")
                                
                                if isLoading {
                                    VStack(spacing: 15) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                                            .scaleEffect(1.2)
                                        Text("A carregar histórico...")
                                            .font(.amiko(size: 14))
                                            .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
                                    }
                                    .padding(.top, 100)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                } else if filteredTickets.isEmpty {
                                    VStack(spacing: 15) {
                                        Image(systemName: "clock.badge.exclamationmark")
                                            .font(.system(size: 40))
                                            .foregroundColor(GlpiColors.dynamicText.opacity(0.2))
                                        Text("Nenhum ticket encontrado")
                                            .font(.amiko(size: 14))
                                            .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                    }
                                    .padding(.top, 100)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    VStack(spacing: 20) {
                                        ForEach(filteredTickets) { ticket in
                                            let isExpanded = expandedTicketId == ticket.id
                                            
                                            TicketRowView(
                                                ticket: ticket,
                                                isSelected: false,
                                                selectionColor: GlpiColors.universalBlue,
                                                isExpanded: isExpanded,
                                                isDeleteMode: false,
                                                listCategory: "",
                                                onLongPress: { _ in },
                                                onSelect: {
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
                                                },
                                                currentY: $currentY
                                            )
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                    
                                    // Paginação
                                    HStack(spacing: 0) {
                                        Button(action: {
                                            if currentPage > 1 { withAnimation { currentPage -= 1 } }
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
                                            .fill(GlpiColors.dynamicText.opacity(0.05))
                                            .frame(width: 1, height: 24)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            if currentPage < totalPages { withAnimation { currentPage += 1 } }
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
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .strokeBorder(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.15), lineWidth: GlpiMetrics.inactiveBorderWidth)
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                }
                                
                                Spacer(minLength: 120)
                            }
                            .padding(.top, 10)
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .refreshable {
                            loadTickets()
                        }
                    }
                    .background(isLightMode ? Color.white : Color.black)
                    .scrollContentBackground(.hidden)
                    .onChange(of: currentPage) { _, _ in
                        withAnimation(.easeInOut(duration: 0.6)) {
                            listProxy.scrollTo("LIST_TOP", anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadTickets()
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
    

}

#Preview {
    TicketHistoryView()
}
