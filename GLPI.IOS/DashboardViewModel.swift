//
//  DashboardViewModel.swift
//  GLPI.IOS
//
//  Created by Antigravity on 29/04/2026.
//

import Foundation
import Combine
import UIKit
import SwiftUI

class DashboardViewModel: ObservableObject {
    @Published var ticketCounts: [TicketStatus: Int] = [.new: 0, .assigned: 0, .resolved: 0, .deleted: 0]
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
        (title: "Pedido de software Adobe", desc: "Instalação do Photoshop solicitada.", status: "Resolvido"),
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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var resolvedGlobalMonth: Int = PreferenceManager.shared.isOfflineMode ? 48 : 0
    @Published var resolvedMyMonth: Int = 0
    @Published var priorityGlobal: Int = PreferenceManager.shared.isOfflineMode ? 7 : 0
    @Published var priorityMy: Int = 0
    @Published var refreshCount: Int = 0
    @Published var isPersonalView: Bool = false {
        didSet { 
            Task {
                await refreshData()
            }
        }
    }
    
    private var isFirstLoad = true
    private var cancellables = Set<AnyCancellable>()
    private let service = GLPIService.shared
    private let client = GLPIClient.shared
    
    @Published var isManualRefresh = false
    
    @MainActor
    func refreshData(isManual: Bool = false) async {
        if isManual {
            withAnimation(.spring()) {
                isManualRefresh = true
            }
        }
        
        refreshCount += 1
        isLoading = true
        errorMessage = nil
        
        // Simula um atraso de rede garantido para que a animação "prenda" e seja visível
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3.0 segundos
        
        if PreferenceManager.shared.isOfflineMode {
            self.countNew = 24
            self.countAssigned = 12
            self.countInProgress = 18
            self.ticketCounts = [.new: 24, .assigned: 12, .waiting: 18, .resolved: 45, .deleted: 0]
            self.resolvedGlobalMonth = 48
            self.priorityGlobal = 7
            
            // Mock de atividades recentes para o carrossel
            self.activities = [
                (title: "Falha na rede Wi-Fi", desc: "Não consigo conectar no 3º andar.", status: "Novo"),
                (title: "Configuração de novo iPhone", desc: "Migração de dados pendente.", status: "Em Progresso"),
                (title: "Teclado MacBook pro", desc: "Teclas A e S não respondem.", status: "Novo"),
                (title: "Pedido de software Adobe", desc: "Instalação do Photoshop solicitada.", status: "Resolvido"),
                (title: "Erro ao imprimir em PDF", desc: "O driver parece estar corrompido.", status: "Novo"),
                (title: "Monitor com riscas", desc: "Monitor LG parou de dar imagem.", status: "Prioritário"),
                (title: "Acesso VPN Falhou", desc: "Utilizador não consegue autenticar.", status: "Prioritário"),
                (title: "Substituição de Toner", desc: "Impressora do RH sem tinta.", status: "Em Progresso"),
                (title: "Atualização de Segurança", desc: "Patch de Maio necessário.", status: "Novo")
            ]
            
            self.performanceData = [
                PerformanceStat(month: "Jan", attributed: 5, resolved: 3),
                PerformanceStat(month: "Fev", attributed: 8, resolved: 6),
                PerformanceStat(month: "Mar", attributed: 4, resolved: 7),
                PerformanceStat(month: "Abr", attributed: 12, resolved: 9),
                PerformanceStat(month: "Mai", attributed: 7, resolved: 10),
                PerformanceStat(month: "Jun", attributed: 15, resolved: 12)
            ]
            
            self.categoryData = [
                (name: "Software", count: 45),
                (name: "Hardware", count: 32),
                (name: "Rede", count: 28),
                (name: "Impressão", count: 18),
                (name: "Acessos", count: 12)
            ]
            
            self.lastUpdateTrigger += 1
            
            // Pequeno atraso de "pose" para a animação não ser brusca e "prender" o espaço
            try? await Task.sleep(nanoseconds: 800_000_000) 
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                self.isManualRefresh = false
            }
            self.isLoading = false
            return
        }
        
        // 1. Fetch Counts Tradicionais (Combine) - Apenas se NÃO estiver em modo offline
        
        // Convertemos o Combine para async/await para maior consistência
        do {
            // Em Swift moderno, podemos converter Combine para Async se necessário, 
            // mas aqui usaremos a Task existente ou mudaremos para chamadas async diretas.
            // Para manter o código funcional, vamos apenas aguardar as tarefas principais.
            
            let userId = PreferenceManager.shared.userId
            async let globalCount = client.getCountResolvidosGlobalCurrentMonth()
            async let myCount = client.getCountResolvidosMyCurrentMonth(userId: userId)
            async let prioGlobal = client.getCountPrioritariosGlobal()
            async let prioMy = client.getCountPrioritariosMeus(userId: userId)
            
            let global = try await globalCount
            let personal = try await myCount
            let pGlobal = try await prioGlobal
            let pPersonal = try await prioMy
            
            self.resolvedGlobalMonth = isPersonalView ? personal : global
            self.priorityGlobal = isPersonalView ? pPersonal : pGlobal
            
            // As outras chamadas Combine continuam em background
            service.fetchTicketCounts(userId: isPersonalView ? userId : nil)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                }, receiveValue: { counts in
                    self.ticketCounts = counts
                    self.countNew = counts[.new] ?? 0
                    self.countAssigned = counts[.assigned] ?? 0
                    self.countInProgress = counts[.waiting] ?? 0
                })
                .store(in: &cancellables)
                
            service.fetchRecentActivities()
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { _ in }, receiveValue: { activities in
                    self.activities = activities
                    self.isLoading = false
                })
                .store(in: &cancellables)
                
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            // Fallback para dados de teste se o servidor falhar
            if self.countNew == 0 {
                self.countNew = 5
                self.countAssigned = 2
                self.ticketCounts = [.new: 5, .assigned: 2, .resolved: 10, .deleted: 0]
            }
        }
    }
}
