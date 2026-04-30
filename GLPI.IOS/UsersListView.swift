//
//  UsersListView.swift
//  GLPI.IOS
//
//  Created by Antigravity on 27/04/2026.
//

import SwiftUI

struct UsersListView: View {
    @Environment(\.dismiss) var dismiss
    @State var searchText = ""
    @State var selectedFilter: String? = nil
    @State var currentPage = 1
    @State var filterPageIndex = 0
    @State var showFilterMenu = false
    
    let filters = ["Admin", "Hotliner", "Observer", "Read-Only", "Super-Admin", "Supervisor", "Technician"]
    
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
    
    @State var users: [GLPIUser] = [
        GLPIUser(name: "Gonçalo Sousa", email: "goncalo@glpi.com", profile: "Super-Admin"),
        GLPIUser(name: "Ana Martins", email: "ana.martins@glpi.com", profile: "Admin"),
        GLPIUser(name: "Ricardo Silva", email: "ricardo@glpi.com", profile: "Technician"),
        GLPIUser(name: "Maria Oliveira", email: "maria@glpi.com", profile: "Hotliner"),
        GLPIUser(name: "João Pereira", email: "joao@glpi.com", profile: "Observer"),
        GLPIUser(name: "Carla Santos", email: "carla@glpi.com", profile: "Supervisor"),
        GLPIUser(name: "Nuno Costa", email: "nuno@glpi.com", profile: "Read-Only"),
        GLPIUser(name: "Sofia Vieira", email: "sofia@glpi.com", profile: "Technician"),
        GLPIUser(name: "Pedro Alves", email: "pedro@glpi.com", profile: "Admin"),
        GLPIUser(name: "Marta Silva", email: "marta@glpi.com", profile: "Technician"),
        GLPIUser(name: "Luís Costa", email: "luis@glpi.com", profile: "Hotliner"),
        GLPIUser(name: "Beatriz Santos", email: "beatriz@glpi.com", profile: "Observer")
    ]
    
    var filteredUsers: [GLPIUser] {
        let filtered = users.filter { user in
            let matchesSearch = searchText.isEmpty || user.name.lowercased().contains(searchText.lowercased()) || user.email.lowercased().contains(searchText.lowercased())
            let matchesFilter = selectedFilter == nil || user.profile == selectedFilter
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
            let matchesFilter = selectedFilter == nil || user.profile == selectedFilter
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
                    
                    Text("UTILIZADORES")
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
                            Text("Pesquisar utilizador...")
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
                        
                            if filteredUsers.isEmpty {
                                VStack(spacing: 15) {
                                    Image(systemName: "person.crop.circle.badge.questionmark")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.2))
                                    Text("Nenhum utilizador encontrado")
                                        .font(.amiko(size: 14))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.top, 100)
                            } else {
                                ForEach(filteredUsers) { user in
                                    UserRow(user: user)
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

struct UserRow: View {
    let user: GLPIUser
    
    private var profileColor: Color {
        switch user.profile {
        case "Super-Admin": return .red
        case "Admin": return .orange
        case "Technician": return .blue
        case "Supervisor": return .purple
        default: return .green
        }
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // Avatar
            ZStack {
                Circle()
                    .fill(profileColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(String(user.name.prefix(1)))
                    .font(.amiko(size: 20, weight: .bold))
                    .foregroundColor(profileColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.amiko(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(user.email)
                    .font(.amiko(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Profile Badge
            Text(user.profile.uppercased())
                .font(.amiko(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(profileColor.opacity(0.2))
                .foregroundColor(profileColor)
                .cornerRadius(6)
        }
        .padding(.horizontal, 15)
    }
}

#Preview {
    UsersListView()
}
