//
//  DashboardViewModel.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 29/04/2026.
//

import Foundation
import Combine
import UIKit
import SwiftUI

struct CachedActivity: Codable {
    let title: String
    let desc: String
    let status: String
}

struct CachedCategory: Codable {
    let name: String
    let count: Int
}

struct DashboardDataSet: Codable {
    var countNew: Int = 0
    var countAssigned: Int = 0
    var countInProgress: Int = 0
    var resolvedMonth: Int = 0
    var priority: Int = 0
    var ticketCounts: [String: Int] = [:]
    var activities: [CachedActivity] = []
    var performanceData: [PerformanceStat] = []
    var categoryData: [CachedCategory] = []
}

struct DashboardCache: Codable {
    let general: DashboardDataSet
    let personal: DashboardDataSet
}

class DashboardViewModel: ObservableObject {
    @Published var ticketCounts: [TicketStatus: Int] = [.new: 0, .assigned: 0, .planned: 0, .waiting: 0, .resolved: 0, .deleted: 0]
    @Published var countNew: Int = PreferenceManager.shared.isOfflineMode ? 24 : 0
    @Published var countAssigned: Int = PreferenceManager.shared.isOfflineMode ? 12 : 0
    @Published var countInProgress: Int = PreferenceManager.shared.isOfflineMode ? 18 : 0
    
    // Aliases para compatibilidade com a nova DashboardView
    var newTicketsCount: Int { countNew }
    var assignedTicketsCount: Int { countAssigned }
    var inProgressTicketsCount: Int { countInProgress }
    var resolvedTicketsCount: Int { ticketCounts[.resolved] ?? 0 }
    @Published var lastUpdateTrigger: Int = 0
    @Published var activities: [(title: String, desc: String, status: String)] = PreferenceManager.shared.isOfflineMode ? [
        (title: "Falha na rede Wi-Fi", desc: "Não consigo conectar no 3º andar.", status: "Novo"),
        (title: "Configuração de novo iPhone", desc: "Migração de dados pendente.", status: "Em Progresso"),
        (title: "Teclado MacBook pro", desc: "Teclas A e S não respondem.", status: "Novo"),
        (title: "Pedido de software Adobe", desc: "Instalação do Photoshop solicitada.", status: "Finalizado"),
        (title: "Erro ao imprimir em PDF", desc: "O driver parece estar corrompido.", status: "Novo"),
        (title: "Monitor com riscas", desc: "Monitor LG parou de dar imagem.", status: "Prioritário"),
        (title: "Acesso VPN Falhou", desc: "Utilizador não consegue autenticar.", status: "Prioritário"),
        (title: "Substituição de Toner", desc: "Impressora do RH sem tinta.", status: "Em Progresso"),
        (title: "Atualização de Segurança", desc: "Patch de Maio necessário.", status: "Novo")
    ] : []
    @Published var performanceData: [PerformanceStat] = PreferenceManager.shared.isOfflineMode ? [
        PerformanceStat(month: "Jan", attributed: 5, resolved: 3),
        PerformanceStat(month: "Fev", attributed: 8, resolved: 6),
        PerformanceStat(month: "Mar", attributed: 4, resolved: 7),
        PerformanceStat(month: "Abr", attributed: 12, resolved: 9),
        PerformanceStat(month: "Mai", attributed: 7, resolved: 10),
        PerformanceStat(month: "Jun", attributed: 15, resolved: 12)
    ] : []
    @Published var categoryData: [(name: String, count: Int)] = PreferenceManager.shared.isOfflineMode ? [
        (name: "Software", count: 45),
        (name: "Hardware", count: 32),
        (name: "Rede", count: 28),
        (name: "Impressão", count: 18),
        (name: "Acessos", count: 12)
    ] : []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var resolvedGlobalMonth: Int = PreferenceManager.shared.isOfflineMode ? 48 : 0
    @Published var resolvedMyMonth: Int = 0
    @Published var priorityGlobal: Int = PreferenceManager.shared.isOfflineMode ? 7 : 0
    @Published var priorityMy: Int = 0
    @Published var refreshCount: Int = 0
    
    @Published var generalData = DashboardDataSet()
    @Published var personalData = DashboardDataSet()
    private var didFetchOnLogin = false
    
    @Published var isPersonalView: Bool = false {
        didSet { 
            updateActiveData()
        }
    }
    
    private var hasLoaded = false
    private var cancellables = Set<AnyCancellable>()
    private let service = GLPIService.shared
    private let client = GLPIClient.shared
    
    @Published var isManualRefresh = false
    
    init() {
        loadFromCache()
    }
    
    private func saveToCache() {
        let cache = DashboardCache(general: generalData, personal: personalData)
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: "cached_dashboard_data")
        }
    }
    
    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: "cached_dashboard_data"),
              let cache = try? JSONDecoder().decode(DashboardCache.self, from: data) else {
            return
        }
        self.generalData = cache.general
        self.personalData = cache.personal
        self.hasLoaded = true
        updateActiveData()
    }
    
    private func updateActiveData() {
        let active = isPersonalView ? personalData : generalData
        self.countNew = active.countNew
        self.countAssigned = active.countAssigned
        self.countInProgress = active.countInProgress
        self.resolvedGlobalMonth = active.resolvedMonth
        self.priorityGlobal = active.priority
        
        var counts: [TicketStatus: Int] = [:]
        for (key, val) in active.ticketCounts {
            if let status = TicketStatus(rawValue: key) {
                counts[status] = val
            }
        }
        self.ticketCounts = counts
        self.activities = active.activities.map { ($0.title, $0.desc, $0.status) }
        self.performanceData = active.performanceData
        self.categoryData = active.categoryData.map { ($0.name, $0.count) }
        self.lastUpdateTrigger += 1
    }
    
    @MainActor
    func refreshData(isManual: Bool = false) async {
        // Só recarrega se for manual, ou se ainda não tiver dados na memória/cache, ou se for a primeira vez depois do login.
        guard isManual || !hasLoaded || !didFetchOnLogin else { return }
        
        if !isManual {
            isLoading = true
            refreshCount += 1
        }
        if errorMessage != nil {
            errorMessage = nil
        }
        
        // Simula um atraso de rede garantido para que a animação "prenda" e seja visível
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3.0 segundos
        
        if PreferenceManager.shared.isOfflineMode {
            // Mock de dados para a vista geral
            var gen = DashboardDataSet()
            gen.countNew = 24
            gen.countAssigned = 12
            gen.countInProgress = 18
            gen.resolvedMonth = 48
            gen.priority = 7
            gen.ticketCounts = ["NOVO": 24, "ATRIBUÍDO": 12, "AGUARDANDO": 18, "FINALIZADO": 45, "RECICLAGEM": 0]
            gen.activities = [
                CachedActivity(title: "Falha na rede Wi-Fi", desc: "Não consigo conectar no 3º andar.", status: "Novo"),
                CachedActivity(title: "Configuração de novo iPhone", desc: "Migração de dados pendente.", status: "Em Progresso"),
                CachedActivity(title: "Teclado MacBook pro", desc: "Teclas A e S não respondem.", status: "Novo"),
                CachedActivity(title: "Pedido de software Adobe", desc: "Instalação do Photoshop solicitada.", status: "Finalizado"),
                CachedActivity(title: "Erro ao imprimir em PDF", desc: "O driver parece estar corrompido.", status: "Novo"),
                CachedActivity(title: "Monitor com riscas", desc: "Monitor LG parou de dar imagem.", status: "Prioritário"),
                CachedActivity(title: "Acesso VPN Falhou", desc: "Utilizador não consegue autenticar.", status: "Prioritário"),
                CachedActivity(title: "Substituição de Toner", desc: "Impressora do RH sem tinta.", status: "Em Progresso"),
                CachedActivity(title: "Atualização de Segurança", desc: "Patch de Maio necessário.", status: "Novo")
            ]
            gen.performanceData = [
                PerformanceStat(month: "Jan", attributed: 5, resolved: 3),
                PerformanceStat(month: "Fev", attributed: 8, resolved: 6),
                PerformanceStat(month: "Mar", attributed: 4, resolved: 7),
                PerformanceStat(month: "Abr", attributed: 12, resolved: 9),
                PerformanceStat(month: "Mai", attributed: 7, resolved: 10),
                PerformanceStat(month: "Jun", attributed: 15, resolved: 12)
            ]
            gen.categoryData = [
                CachedCategory(name: "Software", count: 45),
                CachedCategory(name: "Hardware", count: 32),
                CachedCategory(name: "Rede", count: 28),
                CachedCategory(name: "Impressão", count: 18),
                CachedCategory(name: "Acessos", count: 12)
            ]
            self.generalData = gen
            
            // Mock de dados para a vista pessoal
            var pers = DashboardDataSet()
            pers.countNew = 5
            pers.countAssigned = 3
            pers.countInProgress = 4
            pers.resolvedMonth = 10
            pers.priority = 1
            pers.ticketCounts = ["NOVO": 5, "ATRIBUÍDO": 3, "AGUARDANDO": 4, "FINALIZADO": 10, "RECICLAGEM": 0]
            pers.activities = [
                CachedActivity(title: "Monitor com riscas", desc: "Monitor LG parou de dar imagem.", status: "Prioritário"),
                CachedActivity(title: "Acesso VPN Falhou", desc: "Utilizador não consegue autenticar.", status: "Prioritário"),
                CachedActivity(title: "Substituição de Toner", desc: "Impressora do RH sem tinta.", status: "Em Progresso")
            ]
            pers.performanceData = [
                PerformanceStat(month: "Jan", attributed: 1, resolved: 1),
                PerformanceStat(month: "Fev", attributed: 2, resolved: 2),
                PerformanceStat(month: "Mar", attributed: 1, resolved: 2),
                PerformanceStat(month: "Abr", attributed: 3, resolved: 2),
                PerformanceStat(month: "Mai", attributed: 2, resolved: 3),
                PerformanceStat(month: "Jun", attributed: 4, resolved: 3)
            ]
            pers.categoryData = [
                CachedCategory(name: "Software", count: 10),
                CachedCategory(name: "Hardware", count: 15),
                CachedCategory(name: "Rede", count: 5)
            ]
            self.personalData = pers
            
            updateActiveData()
            saveToCache()
            
            GLPINotificationManager.shared.checkForNewTickets(userId: PreferenceManager.shared.userId)
            
            if isManual {
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isManualRefresh = false
            }
            self.isLoading = false
            self.hasLoaded = true
            self.didFetchOnLogin = true
            return
        }
        
        // Modo Online
        do {
            let userId = PreferenceManager.shared.userId
            
            // 1. Contagens rápidas de finalizados e prioritários
            async let globalResolved = client.getCountFinalizadosGlobalCurrentMonth()
            async let personalResolved = client.getCountFinalizadosMyCurrentMonth(userId: userId)
            async let globalPrio = client.getCountPrioritariosGlobal()
            async let personalPrio = client.getCountPrioritariosMeus(userId: userId)
            
            let gResolved = try await globalResolved
            let mResolved = try await personalResolved
            let gPrio = try await globalPrio
            let mPrio = try await personalPrio
            
            // 2. Gráficos de Performance
            async let gStats = fetchGeneralPerformanceStats()
            async let mStats = fetchPersonalPerformanceStats(userId: userId)
            
            let generalStatsList = try await gStats
            let personalStatsList = try await mStats
            
            // 3. Contagens de Tickets e Atividades (Combine -> Async/Await)
            async let generalTicketData = fetchTicketCountsAndActivities(userId: nil)
            async let personalTicketData = fetchTicketCountsAndActivities(userId: userId)
            
            let (gCounts, gActivities) = try await generalTicketData
            let (mCounts, mActivities) = try await personalTicketData
            
            // Montar Dataset Geral
            var gen = DashboardDataSet()
            gen.countNew = gCounts[.new] ?? 0
            gen.countAssigned = gCounts[.assigned] ?? 0
            gen.countInProgress = gCounts[.assigned] ?? 0
            gen.resolvedMonth = gResolved
            gen.priority = gPrio
            gen.ticketCounts = Dictionary(uniqueKeysWithValues: gCounts.map { ($0.key.rawValue, $0.value) })
            gen.activities = gActivities.map { CachedActivity(title: $0.title, desc: $0.desc, status: $0.status) }
            gen.performanceData = generalStatsList
            self.generalData = gen
            
            // Montar Dataset Pessoal
            var pers = DashboardDataSet()
            pers.countNew = mCounts[.new] ?? 0
            pers.countAssigned = mCounts[.assigned] ?? 0
            pers.countInProgress = mCounts[.assigned] ?? 0
            pers.resolvedMonth = mResolved
            pers.priority = mPrio
            pers.ticketCounts = Dictionary(uniqueKeysWithValues: mCounts.map { ($0.key.rawValue, $0.value) })
            pers.activities = mActivities.map { CachedActivity(title: $0.title, desc: $0.desc, status: $0.status) }
            pers.performanceData = personalStatsList
            self.personalData = pers
            
            updateActiveData()
            saveToCache()
            
            GLPINotificationManager.shared.checkForNewTickets(userId: userId)
            
            // Atualizar o Widget com o ticket real mais recente do sistema
            Task {
                do {
                    let response = try await client.searchTickets(userId: nil, isRequesterOnly: false, isAssignedOnly: false, range: "0-0", sort: "19", order: "DESC")
                    if let firstRaw = response.data?.first {
                        let mapped = service.mapToTickets([firstRaw])
                        if let first = mapped.first {
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
                    }
                } catch {
                    print("Erro ao atualizar widget no DashboardViewModel: \(error)")
                }
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isManualRefresh = false
            }
            self.isLoading = false
            self.hasLoaded = true
            self.didFetchOnLogin = true
            
        } catch {
            if error is CancellationError {
                return
            }
            self.errorMessage = error.localizedDescription
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isManualRefresh = false
            }
            self.isLoading = false
        }
    }
    
    // --- Métodos Auxiliares de Busca ---
    
    private func fetchTicketCountsAndActivities(userId: Int?) async throws -> ([TicketStatus: Int], [(title: String, desc: String, status: String)]) {
        try await withCheckedThrowingContinuation { continuation in
            Publishers.Zip(
                service.fetchTicketCounts(userId: userId),
                service.fetchRecentActivities(userId: userId)
            )
            .first()
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    continuation.resume(throwing: error)
                }
            }, receiveValue: { counts, activities in
                continuation.resume(returning: (counts, activities))
            })
            .store(in: &self.cancellables)
        }
    }
    
    private func fetchGeneralPerformanceStats() async throws -> [PerformanceStat] {
        var stats: [PerformanceStat] = []
        let calendar = Calendar.current
        let ptLocale = Locale(identifier: "pt_PT")
        let formatApi = DateFormatter()
        formatApi.dateFormat = "yyyy-MM"
        formatApi.locale = Locale(identifier: "en_US_POSIX")
        let formatMesCurto = DateFormatter()
        formatMesCurto.dateFormat = "MMM"
        formatMesCurto.locale = ptLocale
        
        for mesesAtras in (1...6).reversed() {
            if let date = calendar.date(byAdding: .month, value: -mesesAtras, to: Date()) {
                let yearMonth = formatApi.string(from: date)
                let monthLabel = formatMesCurto.string(from: date).capitalized
                
                let attributed = try await client.getEstatisticasMensais(fieldDate: 15, yearMonth: yearMonth)
                let resolved = try await client.getEstatisticasMensais(fieldDate: 17, yearMonth: yearMonth)
                
                stats.append(PerformanceStat(month: monthLabel, attributed: attributed, resolved: resolved))
            }
        }
        return stats
    }
    
    private func fetchPersonalPerformanceStats(userId: Int) async throws -> [PerformanceStat] {
        var stats: [PerformanceStat] = []
        let calendar = Calendar.current
        let ptLocale = Locale(identifier: "pt_PT")
        let formatApi = DateFormatter()
        formatApi.dateFormat = "yyyy-MM"
        formatApi.locale = Locale(identifier: "en_US_POSIX")
        let formatMesCurto = DateFormatter()
        formatMesCurto.dateFormat = "MMM"
        formatMesCurto.locale = ptLocale
        
        let response = try await client.getTodosMeusTicketsStats(userId: userId)
        let allTickets = response.data ?? []
        
        for mesesAtras in (1...6).reversed() {
            if let date = calendar.date(byAdding: .month, value: -mesesAtras, to: Date()) {
                let monthLabel = formatMesCurto.string(from: date).capitalized
                let mesChave = formatApi.string(from: date)
                
                var contCriados = 0
                var contFinalizados = 0
                
                for ticket in allTickets {
                    let dateCreated = ticket["15"]?.value as? String ?? ""
                    let dateUpdate = ticket["19"]?.value as? String ?? ""
                    let statusStr = ticket["12"]?.value as? String ?? ""
                    let status = Int(statusStr) ?? 0
                    
                    if dateCreated.hasPrefix(mesChave) {
                        contCriados += 1
                    }
                    if (status == 5 || status == 6) && dateUpdate.hasPrefix(mesChave) {
                        contFinalizados += 1
                    }
                }
                stats.append(PerformanceStat(month: monthLabel, attributed: contCriados, resolved: contFinalizados))
            }
        }
        return stats
    }
}
