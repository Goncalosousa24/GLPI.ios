//
//  TicketHistoryView.swift
//  GLPI.IOS
//
//  Created by Antigravity on 22/04/2026.
//

import SwiftUI

struct TicketHistoryView: View {
    struct HistoryTicket: Identifiable {
        let id = UUID()
        let title: String
        let desc: String
        let status: String
        let date: String
        let isPriority: Bool
    }
    
    @Environment(\.dismiss) var dismiss
    @State var searchText = ""
    @State var selectedFilter: String? = nil
    @State var currentPage = 1
    @State var filterPageIndex = 0
    @State var showFilterMenu = false
    
    private var pillWidth: CGFloat {
        let screenWidth = UIScreen.screenWidth
        let padding: CGFloat = 32 // 16 + 16
        let arrowButtonWidth: CGFloat = 72 + 12 // Container duplo + espaçamento
        let spacing: CGFloat = 12 // 1 gap entre 2 itens
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
    
    let fullHistory: [HistoryTicket] = [
        HistoryTicket(title: "Impressora Piso 1", desc: "Papel encravado na HP-LaserJet", status: "Novo", date: "22 Abr 2026", isPriority: false),
        HistoryTicket(title: "VPN Acesso", desc: "Utilizador RF bloqueado após 3 tentativas", status: "Atribuído", date: "21 Abr 2026", isPriority: true),
        HistoryTicket(title: "Monitor 4K", desc: "Novo pedido de periférico para Design", status: "Novo", date: "20 Abr 2026", isPriority: false),
        HistoryTicket(title: "LDAP Login", desc: "Erro 401 ao sincronizar utilizadores", status: "Resolvido", date: "15 Abr 2026", isPriority: false),
        HistoryTicket(title: "Switch Core", desc: "Atualização de firmware agendada", status: "Atribuído", date: "12 Abr 2026", isPriority: true),
        HistoryTicket(title: "Backup SVR04", desc: "Falha na verificação de integridade", status: "Novo", date: "10 Abr 2026", isPriority: true),
        HistoryTicket(title: "Teclado Mecânico", desc: "Substituição por falha na tecla Enter", status: "Resolvido", date: "05 Abr 2026", isPriority: false),
        HistoryTicket(title: "MacBook Pro 16", desc: "Instalação de software de segurança", status: "Resolvido", date: "01 Abr 2026", isPriority: false),
        HistoryTicket(title: "Email Outlook", desc: "Configuração de conta em novo dispositivo", status: "Resolvido", date: "28 Mar 2026", isPriority: false),
        HistoryTicket(title: "Wifi Guest", desc: "Criar credenciais para visita externa", status: "Resolvido", date: "25 Mar 2026", isPriority: false),
        HistoryTicket(title: "Server R740", desc: "Substituição de disco em RAID 5", status: "Resolvido", date: "20 Mar 2026", isPriority: true),
        HistoryTicket(title: "Licença Adobe", desc: "Renovação de subscrição anual", status: "Resolvido", date: "15 Mar 2026", isPriority: false)
    ]
    
    let filters = ["Criados", "Em Progresso", "Prioritários", "Resolvidos"]
    
    var filteredTickets: [HistoryTicket] {
        let filtered = fullHistory.filter { ticket in
            let matchesSearch = searchText.isEmpty || ticket.title.lowercased().contains(searchText.lowercased()) || ticket.desc.lowercased().contains(searchText.lowercased())
            let matchesFilter: Bool
            if let selected = selectedFilter {
                switch selected {
                case "Criados": matchesFilter = ticket.status == "Novo"
                case "Em Progresso": matchesFilter = ticket.status == "Atribuído"
                case "Prioritários": matchesFilter = ticket.isPriority
                case "Resolvidos": matchesFilter = ticket.status == "Resolvido"
                default: matchesFilter = true
                }
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
        let filteredCount = fullHistory.filter { ticket in
            let matchesSearch = searchText.isEmpty || ticket.title.lowercased().contains(searchText.lowercased()) || ticket.desc.lowercased().contains(searchText.lowercased())
            let matchesFilter: Bool
            if let selected = selectedFilter {
                switch selected {
                case "Criados": matchesFilter = ticket.status == "Novo"
                case "Em Progresso": matchesFilter = ticket.status == "Atribuído"
                case "Prioritários": matchesFilter = ticket.isPriority
                case "Resolvidos": matchesFilter = ticket.status == "Resolvido"
                default: matchesFilter = true
                }
            } else {
                matchesFilter = true
            }
            return matchesSearch && matchesFilter
        }.count
        return max(1, Int(ceil(Double(filteredCount) / 5.0)))
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header customizado
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .glassStyle(cornerRadius: 12)
                    }
                    
                    Spacer()
                    
                    Text("HISTÓRICO")
                        .font(.amiko(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 45, height: 45)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                // Search Bar Premium
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.4))
                        TextField("", text: $searchText, prompt: 
                            Text("Pesquisar no histórico...")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.amiko(size: 14))
                        )
                        .font(.amiko(size: 14))
                        .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 55)
                    .glassStyle(cornerRadius: 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // Horizontal Filters with Arrows
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
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
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 35, height: 44)
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 1, height: 18)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                filterPageIndex = (filterPageIndex + 1) % totalFilterPages
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 35, height: 44)
                        }
                    }
                    .glassStyle(cornerRadius: 12)
                }
                .frame(height: 50)
                .padding(.horizontal, 16)
                .padding(.top, 15)
                
                // List
                ScrollViewReader { listProxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 15) {
                            Color.clear.frame(height: 1)
                                .id("LIST_TOP")
                        
                            if filteredTickets.isEmpty {
                                VStack(spacing: 15) {
                                    Image(systemName: "clock.badge.exclamationmark")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.2))
                                    Text("Nenhum ticket encontrado")
                                        .font(.amiko(size: 14))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.top, 100)
                            } else {
                                ForEach(filteredTickets) { ticket in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text(ticket.date)
                                                .font(.amiko(size: 10, weight: .bold))
                                                .foregroundColor(.white.opacity(0.4))
                                            
                                            if ticket.isPriority {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 6, height: 6)
                                            }
                                            
                                            Spacer()
                                        }
                                        
                                        ActivityRow(activity: (title: ticket.title, desc: ticket.desc, status: ticket.status))
                                    }
                                    .padding(.horizontal, 18)
                                    .frame(height: 100)
                                    .glassStyle(cornerRadius: 22)
                                }
                            }
                            
                            // Pagination
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
                            .padding(.vertical, 20)
                            
                            Spacer(minLength: 120)
                        }
                        .padding(16)
                        .padding(.top, -5)
                    }
                    .onChange(of: currentPage) { oldValue, newValue in
                        withAnimation(.spring()) {
                            listProxy.scrollTo("LIST_TOP", anchor: .top)
                        }
                    }
                }
            }
            .blur(radius: showFilterMenu ? 20 : 0)
            
            if showFilterMenu {
                filterOverlayView
            }
        }
        .navigationBarHidden(true)
    }
    
    private var filterOverlayView: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.spring()) { showFilterMenu = false } }
            
            VStack(alignment: .leading, spacing: 0) {
                Text("FILTRAR POR")
                    .font(.amiko(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 16)
                    .padding(.top, 25)
                    .padding(.bottom, 12)
                
                ForEach(filters, id: \.self) { filter in
                    filterMenuItem(title: filter, isSelected: selectedFilter == filter) {
                        if selectedFilter == filter {
                            selectedFilter = nil
                        } else {
                            selectedFilter = filter
                        }
                        withAnimation(.spring()) { showFilterMenu = false }
                    }
                    
                    if filter != filters.last {
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 16)
                    }
                }
                
                Spacer().frame(height: 15)
            }
            .frame(maxWidth: .infinity)
            .glassStyle(cornerRadius: 30)
            .padding(.horizontal, 16)
            .shadow(color: .blue.opacity(0.2), radius: 40)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .zIndex(10)
    }
    
    private func filterMenuItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.amiko(size: 14, weight: isSelected ? .bold : .regular))
                Spacer()
                if isSelected { Image(systemName: "checkmark").foregroundColor(.blue) }
            }
            .foregroundColor(.white).padding(16)
        }
    }
}

#Preview {
    TicketHistoryView()
}
