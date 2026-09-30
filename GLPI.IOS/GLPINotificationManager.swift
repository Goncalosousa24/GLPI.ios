import Foundation
import UserNotifications
import Combine

class GLPINotificationManager {
    static let shared = GLPINotificationManager()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Executa a verificação diferencial de novos tickets e envia notificações locais unificadas
    func checkForNewTickets(userId: Int) {
        let isNotifEnabled = UserDefaults.standard.bool(forKey: "allowNotifications")
        guard isNotifEnabled else { return }
        
        let notifyRequester = UserDefaults.standard.bool(forKey: "notifyRequester")
        let notifyAssigned = UserDefaults.standard.bool(forKey: "notifyAssigned")
        let notifyObserver = UserDefaults.standard.bool(forKey: "notifyObserver")
        let notifyResolved = UserDefaults.standard.bool(forKey: "notifyResolved")
        
        guard notifyRequester || notifyAssigned || notifyObserver || notifyResolved else { return }
        
        // 1. Procurar tickets ativos onde o utilizador tenha pelo menos um dos papéis selecionados
        GLPIService.shared.fetchActiveUserTickets(
            userId: userId,
            notifyRequester: notifyRequester,
            notifyAssigned: notifyAssigned,
            notifyObserver: notifyObserver
        )
        .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] tickets in
            guard let self = self else { return }
            self.processActiveTickets(tickets)
        })
        .store(in: &cancellables)
        
        // 2. Se a notificação de finalizados estiver ativa, procurar por concluídos recentes
        if notifyResolved {
            let dataLimite = Date().firstDayOfMonth() // Paridade Android/iOS de mês corrente
            GLPIService.shared.fetchTickets(
                status: .resolved,
                startDate: dataLimite,
                userId: userId,
                order: "DESC"
            )
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] tickets, _ in
                guard let self = self else { return }
                self.processResolvedTickets(tickets)
            })
            .store(in: &cancellables)
        }
    }
    
    private func processActiveTickets(_ tickets: [GLPITicket]) {
        let defaults = UserDefaults.standard
        let savedActiveIds = defaults.stringArray(forKey: "notified_active_ticket_ids") ?? []
        let activeSet = Set(savedActiveIds)
        
        var newTickets: [GLPITicket] = []
        var currentIds: [String] = []
        
        for ticket in tickets {
            currentIds.append(ticket.id)
            if !activeSet.contains(ticket.id) {
                newTickets.append(ticket)
            }
        }
        
        // Atualizar lista guardada para o futuro
        defaults.set(currentIds, forKey: "notified_active_ticket_ids")
        
        // Se a lista anterior estava vazia, significa que é o primeiro carregamento ou reset, logo não disparamos notificações massivas
        guard !savedActiveIds.isEmpty else { return }
        
        // Enviar notificações para os novos tickets detetados (um alerta por ticket, sem duplicação de papéis)
        for ticket in newTickets {
            let title = "Novo Ticket Ativo (#\(ticket.id))"
            let body = "\(ticket.name)\nRequerente: \(ticket.requester.isEmpty ? "Não especificado" : ticket.requester)"
            sendNotification(title: title, body: body)
        }
    }
    
    private func processResolvedTickets(_ tickets: [GLPITicket]) {
        let defaults = UserDefaults.standard
        let savedResolvedIds = defaults.stringArray(forKey: "notified_resolved_ticket_ids") ?? []
        let resolvedSet = Set(savedResolvedIds)
        
        var newResolved: [GLPITicket] = []
        var currentIds: [String] = []
        
        for ticket in tickets {
            currentIds.append(ticket.id)
            if !resolvedSet.contains(ticket.id) {
                newResolved.append(ticket)
            }
        }
        
        defaults.set(currentIds, forKey: "notified_resolved_ticket_ids")
        
        guard !savedResolvedIds.isEmpty else { return }
        
        for ticket in newResolved {
            let title = "Ticket Finalizado (#\(ticket.id))"
            let body = "\(ticket.name)\nConcluído com sucesso."
            sendNotification(title: title, body: body)
        }
    }
}
