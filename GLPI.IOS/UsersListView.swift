//
//  UsersListView.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 27/04/2026.
//

import SwiftUI

struct UsersListView: View {
    @Environment(\.dismiss) var dismiss
    @State var searchText = ""
    @State var selectedFilter: String? = nil
    @State var currentPage = 1
    @State var filterPageIndex = 0
    @State var isLoading = true
    
    @State var filters = ["Admin", "Hotliner", "Observer", "Read-Only", "Super-Admin", "Supervisor", "Technician"]
    
    private var pillWidth: CGFloat {
        let screenWidth = UIScreen.screenWidth
        let padding: CGFloat = 32 // 16 + 16
        let arrowButtonWidth: CGFloat = 72 + 12 // Container duplo + espaçamento
        let spacing: CGFloat = 12 // 1 gap entre 2 itens
        return (screenWidth - padding - arrowButtonWidth - spacing) / 2
    }
    
    private var currentFilters: [String] {
        if filters.isEmpty { return [] }
        let chunkSize = 2
        let start = filterPageIndex * chunkSize
        let end = min(start + chunkSize, filters.count)
        if start >= filters.count { return [] }
        return Array(filters[start..<end])
    }
    
    private var totalFilterPages: Int {
        max(1, Int(ceil(Double(filters.count) / 2.0)))
    }
    
    @State var users: [GLPIUser] = []
    
    private func userMatchesFilter(_ user: GLPIUser, filter: String) -> Bool {
        let currentName = PreferenceManager.shared.userName ?? ""
        let currentEmail = PreferenceManager.shared.userEmail ?? ""
        
        let isCurrentUser = (!currentName.isEmpty &&
            user.name.folding(options: .diacriticInsensitive, locale: .current).lowercased() ==
            currentName.folding(options: .diacriticInsensitive, locale: .current).lowercased()) ||
            (!currentEmail.isEmpty && 
             currentEmail.lowercased() != "nenhum e-mail associado" &&
             user.email.lowercased() != "nenhum e-mail associado" &&
             user.email.lowercased() == currentEmail.lowercased())
        
        let rawList = user.rawProfileList
        
        // Lógica idêntica ao Android:
        // Se filtro = "Admin", excluir Super-Admin (igual ao Android: !role.contains("Super-"))
        if filter.lowercased() == "admin" {
            return rawList.range(of: "admin", options: .caseInsensitive) != nil &&
                   rawList.range(of: "super-", options: .caseInsensitive) == nil &&
                   rawList.range(of: "super ", options: .caseInsensitive) == nil
        }
        
        // Para todos os outros filtros: contains simples
        return rawList.range(of: filter, options: .caseInsensitive) != nil
    }
    
    var filteredUsers: [GLPIUser] {
        let filtered = users.filter { user in
            let searchClean = searchText.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let nameClean = user.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let emailClean = user.email.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            
            let matchesSearch = searchText.isEmpty || nameClean.contains(searchClean) || emailClean.contains(searchClean)
            let matchesFilter = selectedFilter == nil || userMatchesFilter(user, filter: selectedFilter!)
            return matchesSearch && matchesFilter
        }
        
        let startIndex = (currentPage - 1) * 5
        let endIndex = min(startIndex + 5, filtered.count)
        
        if startIndex >= filtered.count { return [] }
        return Array(filtered[startIndex..<endIndex])
    }
    
    private var totalPages: Int {
        let filteredCount = users.filter { user in
            let matchesSearch = searchText.isEmpty || user.name.lowercased().contains(searchText.lowercased()) || user.email.lowercased().contains(searchText.lowercased())
            let matchesFilter = selectedFilter == nil || userMatchesFilter(user, filter: selectedFilter!)
            return matchesSearch && matchesFilter
        }.count
        return max(1, Int(ceil(Double(filteredCount) / 5.0)))
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. UNIVERSAL HEADER
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: GlpiMetrics.universalBackIcon)
                            .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                            .foregroundColor(GlpiColors.universalBlue)
                    }
                    .padding(.leading, GlpiMetrics.universalHeaderLeading)
                    
                    Spacer()
                    
                    Text("UTILIZADORES")
                        .font(.amiko(size: 18, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText)
                    
                    Spacer()
                    
                    // Compensação para centrar título
                    Color.clear.frame(width: 44, height: 44)
                        .padding(.trailing, GlpiMetrics.universalHeaderLeading)
                }
                .padding(.top, GlpiMetrics.topPadding + 5)
                .frame(height: GlpiMetrics.navAreaHeight)
                
                // 2. SEARCH BAR (Sincronizada)
                GLPISearchHeader(
                    searchText: $searchText,
                    placeholder: "Pesquisar utilizador..."
                )
                .padding(.top, GlpiMetrics.topPadding)
                .padding(.bottom, 10)
                
                // 3. FILTROS HORIZONTAIS (Premium com Setas)
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
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                    
                    // Controlos de Navegação dos Filtros
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
                .padding(.bottom, 15)
                
                // 4. LISTA DE UTILIZADORES
                ScrollViewReader { listProxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 15) {
                            Color.clear.frame(height: 1)
                                .id("LIST_TOP")
                        
                            if filteredUsers.isEmpty {
                                VStack(spacing: 15) {
                                    Image(systemName: "person.crop.circle.badge.questionmark")
                                        .font(.system(size: 40))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.2))
                                    Text("Nenhum utilizador encontrado")
                                        .font(.amiko(size: 14))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                }
                                .padding(.top, 100)
                            } else {
                                ForEach(filteredUsers) { user in
                                    UserRow(user: user)
                                }
                            }
                            
                            // Paginação Premium (Universal)
                            if totalPages > 1 {
                                HStack(spacing: 0) {
                                    Button(action: {
                                        if currentPage > 1 { 
                                            withAnimation { currentPage -= 1 }
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
                                            withAnimation { currentPage += 1 }
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
                                .glassStyle(cornerRadius: 15)
                                .padding(.vertical, 20)
                            }
                            
                            Spacer(minLength: 120)
                        }
                        .padding(.horizontal, GlpiMetrics.padding)
                        .padding(.top, 10)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: currentPage) { oldValue, newValue in
                        withAnimation(.easeInOut(duration: 0.6)) {
                            listProxy.scrollTo("LIST_TOP", anchor: .top)
                        }
                    }
                    .onChange(of: searchText) { oldValue, newValue in
                        currentPage = 1
                    }
                }
            }
            
            if isLoading {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                        .scaleEffect(1.5)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadUsers()
        }
    }
    
    private func loadUsers() {
        Task {
            do {
                let fetched = try await GLPIClient.shared.fetchAllUsers()
                await MainActor.run {
                    self.users = fetched
                    self.isLoading = false
                }
            } catch {
                print("Erro ao carregar utilizadores: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct UserRow: View {
    let user: GLPIUser
    
    private var isCurrentUser: Bool {
        let currentName = PreferenceManager.shared.userName ?? ""
        let currentEmail = PreferenceManager.shared.userEmail ?? ""
        
        let matchesName = !currentName.isEmpty && 
            user.name.folding(options: .diacriticInsensitive, locale: .current).lowercased() == 
            currentName.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            
        let matchesEmail = !currentEmail.isEmpty && 
            currentEmail.lowercased() != "nenhum e-mail associado" &&
            user.email.lowercased() != "nenhum e-mail associado" &&
            user.email.lowercased() == currentEmail.lowercased()
        
        return matchesName || matchesEmail
    }
    
    private var displayedProfile: String {
        if isCurrentUser, let sessionProfile = PreferenceManager.shared.userProfile, !sessionProfile.isEmpty, sessionProfile != "null" {
            return GLPIClient.shared.normalizeProfileString(sessionProfile)
        }
        return GLPIClient.shared.normalizeProfileString(user.profile)
    }
    
    private var profileColor: Color {
        switch displayedProfile.lowercased() {
        case "super-admin", "super-admins", "super-administrador": return GlpiColors.deleteRed
        case "admin", "admins", "administrador": return .orange
        case "technician", "técnico", "tecnico": return GlpiColors.universalBlue
        case "supervisor": return .purple
        default: return .green
        }
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // Avatar Circular Premium
            ZStack {
                Circle()
                    .fill(profileColor.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Text(String(user.name.prefix(1)))
                    .font(.amiko(size: 20, weight: .black))
                    .foregroundColor(profileColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.amiko(size: 16, weight: .black))
                    .foregroundColor(GlpiColors.dynamicText)
                
                Text(user.email.lowercased())
                    .font(.amiko(size: 12))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            // Perfil com Badge Estilizado
            Text(displayedProfile.uppercased())
                .font(.amiko(size: 9, weight: .black))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(profileColor.opacity(0.1))
                .foregroundColor(profileColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .frame(height: 90)
        .glassStyle(cornerRadius: 22)
    }
}

#Preview {
    UsersListView()
}
