//
//  GLPIService.swift
//  GLPI.IOS
//
//  Created by Antigravity on 29/04/2026.
//

import Foundation
import Combine

class GLPIService {
    static let shared = GLPIService()
    private init() {}
    
    var baseURL: String { PreferenceManager.shared.baseURL }
    var appToken: String { PreferenceManager.shared.appToken }
    var sessionToken: String { PreferenceManager.shared.sessionToken }
    
    // --- Dashboard Data Fetching ---
    
    /// Obtém a contagem de tickets para os 4 cards principais
    func fetchTicketCounts(userId: Int? = nil) -> AnyPublisher<[TicketStatus: Int], Error> {
        let statuses: [TicketStatus: Int] = [.new: 1, .assigned: 2, .waiting: 4, .resolved: 5]
        let monthlyStart = Date().firstDayOfMonth()
        
        let publishers = statuses.map { (status, glpiValue) in
            self.searchCount(itemType: "Ticket", statusValue: glpiValue, startDate: status == .resolved ? monthlyStart : nil, userId: userId)
                .map { (status, $0) }
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { pairs in
                var dict: [TicketStatus: Int] = [:]
                var inProgressCount = 0
                
                for (status, count) in pairs {
                    if status == .assigned || status == .waiting {
                        inProgressCount += count
                        if status == .assigned { dict[.assigned] = count }
                        if status == .waiting { dict[.waiting] = count }
                    } else {
                        dict[status] = count
                    }
                }
                
                // O card "EM PROGRESSO" no dashboard usa o status .assigned
                dict[.assigned] = inProgressCount
                dict[.deleted] = 0
                return dict
            }
            .eraseToAnyPublisher()
    }
    
    /// Valida a sessão completa (necessário em alguns servidores)
    func getFullSession() -> AnyPublisher<Bool, Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: "\(cleanBaseURL)/apirest.php/getFullSession") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return sessionRequest(url: url)
            .map { (_: [String: AnyCodable]) -> Bool in
                return true
            }
            .eraseToAnyPublisher()
    }
    
    /// Procura tickets por status com paginação
    func fetchTickets(status: TicketStatus? = nil, statusValue: Int? = nil, range: String = "0-50", startDate: String? = nil, userId: Int? = nil) -> AnyPublisher<([GLPITicket], Int), Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var urlString = "\(cleanBaseURL)/apirest.php/search/Ticket?range=\(range)&expand_dropdowns=true"
        
        // Critérios de pesquisa
        var criteriaIndex = 0
        
        // 1. Filtro de Status
        if let sv = statusValue {
            urlString += "&criteria[\(criteriaIndex)][field]=12&criteria[\(criteriaIndex)][searchtype]=equals&criteria[\(criteriaIndex)][value]=\(sv)"
            criteriaIndex += 1
        } else if let s = status {
            if s == .assigned {
                urlString += "&criteria[\(criteriaIndex)][field]=12&criteria[\(criteriaIndex)][searchtype]=equals&criteria[\(criteriaIndex)][value]=2"
                urlString += "&criteria[\(criteriaIndex + 1)][link]=OR&criteria[\(criteriaIndex + 1)][field]=12&criteria[\(criteriaIndex + 1)][searchtype]=equals&criteria[\(criteriaIndex + 1)][value]=4"
                criteriaIndex += 2
            } else {
                let glpiValue: Int
                switch s {
                case .new: glpiValue = 1
                case .resolved: glpiValue = 5
                case .deleted: glpiValue = 6
                case .waiting: glpiValue = 4
                default: glpiValue = 2
                }
                urlString += "&criteria[\(criteriaIndex)][field]=12&criteria[\(criteriaIndex)][searchtype]=equals&criteria[\(criteriaIndex)][value]=\(glpiValue)"
                criteriaIndex += 1
            }
        }
        
        // 2. Filtro de Data (Se fornecido)
        if let sd = startDate {
            urlString += "&criteria[\(criteriaIndex)][field]=15&criteria[\(criteriaIndex)][searchtype]=morethan&criteria[\(criteriaIndex)][value]=\(sd)"
            criteriaIndex += 1
        }
        
        // 3. Filtro de Usuário (Se fornecido) - Requerente OU Técnico
        if let uid = userId {
            let link = criteriaIndex > 0 ? "&criteria[\(criteriaIndex)][link]=AND" : ""
            urlString += "\(link)&criteria[\(criteriaIndex)][criteria][0][field]=4&criteria[\(criteriaIndex)][criteria][0][searchtype]=equals&criteria[\(criteriaIndex)][criteria][0][value]=\(uid)"
            urlString += "&criteria[\(criteriaIndex)][criteria][1][link]=OR&criteria[\(criteriaIndex)][criteria][1][field]=5&criteria[\(criteriaIndex)][criteria][1][searchtype]=equals&criteria[\(criteriaIndex)][criteria][1][value]=\(uid)"
            criteriaIndex += 1
        }
        
        // 3. Garantir que temos pelo menos um critério se nada for passado
        if criteriaIndex == 0 {
            urlString += "&criteria[0][field]=2&criteria[0][searchtype]=morethan&criteria[0][value]=0"
            criteriaIndex += 1
        }
        
        // Campos forçados (Essenciais + Requerente + Prioridade)
        urlString += "&forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=12&forcedisplay[3]=15&forcedisplay[4]=19&forcedisplay[5]=4&forcedisplay[8]=3"
        
        // Adicionar Técnico apenas se não for pesquisa de NOVOS (Status 1) para evitar quebra do servidor
        if status != .new && statusValue != 1 {
            urlString += "&forcedisplay[6]=5"
        }
        
        // Sorting
        urlString += "&sort=19&order=DESC"
        
        // Codificação segura apenas dos caracteres necessários
        let safeURLString = urlString.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")
        
        guard let url = URL(string: safeURLString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return sessionRequest(url: url)
            .map { (response: TicketListResponse) -> ([GLPITicket], Int) in
                let rawData = response.data ?? []
                let mapped = self.mapToTickets(rawData)
                return (mapped, response.totalInt)
            }
            .eraseToAnyPublisher()
    }
    
    func mapToTickets(_ data: [[String: AnyCodable]]) -> [GLPITicket] {
        return data.compactMap { dict in
            let idValue = dict["2"]?.value ?? dict["id"]?.value ?? "0"
            let idStr = String(describing: idValue).replacingOccurrences(of: ".0", with: "")
            
            let title = dict["1"]?.value as? String ?? "Ticket #\(idStr)"
            let desc = dict["21"]?.value as? String ?? ""
            let date = dict["17"]?.value as? String ?? dict["19"]?.value as? String ?? dict["15"]?.value as? String ?? ""
            
            // Função auxiliar de extração de nome (Suporta Listas/Múltiplos)
            func formatarNome(fieldId: String) -> String? {
                let val = dict[fieldId]?.value
                
                // Se for uma Lista (Múltiplos Técnicos/Requerentes)
                if let list = val as? [AnyCodable] {
                    let results = list.compactMap { item -> String? in
                        if let map = item.value as? [String: AnyCodable] {
                            return map["completename"]?.value as? String ?? 
                                   map["realname"]?.value as? String ?? 
                                   map["name"]?.value as? String
                        }
                        let s = String(describing: item.value).trimmingCharacters(in: .whitespaces)
                        return (s.isEmpty || s == "null" || s == "0") ? nil : s.replacingOccurrences(of: ".0", with: "")
                    }
                    return results.isEmpty ? nil : results.joined(separator: " & ")
                }
                
                // Se for um Mapa/Dicionário individual
                if let map = val as? [String: AnyCodable] {
                    let name = map["completename"]?.value as? String ?? 
                               map["realname"]?.value as? String ?? 
                               map["name"]?.value as? String
                    return name
                }
                
                // Se for um valor simples
                let s = String(describing: val ?? "").trimmingCharacters(in: .whitespaces)
                if s.isEmpty || s == "null" || s == "0" { return nil }
                return s.replacingOccurrences(of: ".0", with: "")
            }
            
            // Requerente: Tenta 4 (ID) primeiro para o resolver encontrar o nome real, depois 22
            let requester = formatarNome(fieldId: "4") ?? formatarNome(fieldId: "22") ?? "Desconhecido"
            
            // Técnico: Tenta 5, 70, 71 (Paridade Android)
            let assigned = formatarNome(fieldId: "5") ?? formatarNome(fieldId: "70") ?? formatarNome(fieldId: "71") ?? "Pendente"
            
            let statusRaw = String(describing: dict["12"]?.value ?? "1").replacingOccurrences(of: ".0", with: "")
            let status: TicketStatus
            switch statusRaw {
            case "1": status = .new
            case "2", "3": status = .assigned
            case "4": status = .waiting
            case "5": status = .resolved
            case "6": status = .deleted
            default: status = .new
            }
            
            let priorityRaw = String(describing: dict["3"]?.value ?? "3").replacingOccurrences(of: ".0", with: "")
            let priority: TicketPriority
            switch priorityRaw {
            case "1": priority = .veryLow
            case "2": priority = .low
            case "3": priority = .medium
            case "4": priority = .high
            case "5": priority = .veryHigh
            case "6": priority = .major
            default: priority = .medium
            }

            return GLPITicket(
                id: "#\(idStr)",
                name: title,
                requester: requester,
                assignedTo: assigned,
                description: desc,
                date: date.toDate() ?? Date(),
                priority: priority,
                status: status,
                isMine: false,
                isAssignedToMe: false
            )
        }
    }
    
    /// Obtém as últimas atualizações para o carrossel
    func fetchRecentActivities() -> AnyPublisher<[(title: String, desc: String, status: String)], Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/search/Ticket?range=0-6&sort=19&order=DESC"
        
        let safeURLString = urlString.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")
        
        guard let url = URL(string: safeURLString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return sessionRequest(url: url)
            .map { (data: TicketListResponse) -> [(title: String, desc: String, status: String)] in
                guard let rows = data.data else { return [] }
                return rows.compactMap { row in
                    let title = row["1"]?.value as? String ?? "Sem título"
                    let desc = row["21"]?.value as? String ?? ""
                    let statusID = row["12"]?.value as? String ?? "1"
                    let statusStr = self.mapStatus(statusID)
                    return (title: title, desc: desc, status: statusStr)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // --- Auxiliares de API ---
    
    func searchCount(itemType: String, statusValue: Int, startDate: String? = nil, userId: Int? = nil) -> AnyPublisher<Int, Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var urlString = "\(cleanBaseURL)/apirest.php/search/\(itemType)?range=0-0&criteria[0][field]=12&criteria[0][searchtype]=equals&criteria[0][value]=\(statusValue)"
        
        if let sd = startDate {
            urlString += "&criteria[1][field]=15&criteria[1][searchtype]=morethan&criteria[1][value]=\(sd)"
        }
        
        if let uid = userId {
            urlString += "&criteria[2][link]=AND&criteria[2][criteria][0][field]=4&criteria[2][criteria][0][searchtype]=equals&criteria[2][criteria][0][value]=\(uid)"
            urlString += "&criteria[2][criteria][1][link]=OR&criteria[2][criteria][1][field]=5&criteria[2][criteria][1][searchtype]=equals&criteria[2][criteria][1][value]=\(uid)"
        }
        
        let safeURLString = urlString.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")
        
        guard let url = URL(string: safeURLString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return sessionRequest(url: url)
            .map { (data: TicketListResponse) -> Int in
                return data.totalInt
            }
            .eraseToAnyPublisher()
    }
    
    // --- Legacy Functions ---
    // Note: Use UserNameResolver for name resolution now.

    private func sessionRequest<T: Codable>(url: URL) -> AnyPublisher<T, Error> {
        if PreferenceManager.shared.isOfflineMode {
            let mockData: Data
            if T.self == TicketListResponse.self {
                // Mock inteligente para contagens variadas
                var count = 15
                if url.absoluteString.contains("value=1") { count = 24 } // Novos
                else if url.absoluteString.contains("value=2") { count = 12 } // Atribuídos
                else if url.absoluteString.contains("value=4") { count = 5 } // Espera
                else if url.absoluteString.contains("value=5") { count = 48 } // Resolvidos
                
                let mockJSON = """
                {
                    "totalcount": \(count),
                    "count": 5,
                    "data": [
                        {"2": "101", "1": "Falha na rede Wi-Fi", "12": "1", "3": "5", "19": "2026-04-30 09:30:00", "4": "Gonçalo Sousa", "21": "Não consigo conectar no 3º andar."},
                        {"2": "102", "1": "Configuração de novo iPhone", "12": "2", "3": "3", "19": "2026-04-30 10:15:00", "4": "Beatriz Silva", "5": "Suporte Técnico", "21": "Migração de dados pendente."},
                        {"2": "103", "1": "Teclado MacBook pro com teclas presas", "12": "4", "3": "2", "19": "2026-04-30 11:00:00", "4": "Carlos Mendes", "5": "Manutenção", "21": "Teclas A e S não respondem."},
                        {"2": "104", "1": "Pedido de software Adobe", "12": "5", "3": "4", "19": "2026-04-29 16:45:00", "4": "Diana Rose", "5": "Admin", "21": "Instalação do Photoshop solicitada."},
                        {"2": "105", "1": "Erro ao imprimir em PDF", "12": "1", "3": "3", "19": "2026-04-30 12:00:00", "4": "Eduardo Lima", "21": "O driver parece estar corrompido."}
                    ]
                }
                """
                mockData = mockJSON.data(using: .utf8)!
            } else {
                mockData = "{}".data(using: .utf8)!
            }
            
            return Just(mockData)
                .decode(type: T.self, decoder: JSONDecoder())
                .mapError { error in
                    NSError(domain: "OfflineMock", code: 0, userInfo: [NSLocalizedDescriptionKey: "Erro de Mock: \(error.localizedDescription)"])
                }
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.setValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.setValue(appToken, forHTTPHeaderField: "App-Token")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                let validStatuses = [200, 206]
                if !validStatuses.contains(httpResponse.statusCode) {
                    let rawStr = String(data: output.data, encoding: .utf8) ?? "Sem dados"
                    throw NSError(domain: "HTTP \(httpResponse.statusCode)", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erro \(httpResponse.statusCode): \(rawStr.prefix(100))"])
                }
                return output.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if let decodingError = error as? DecodingError {
                    return NSError(domain: "Decoding", code: 0, userInfo: [NSLocalizedDescriptionKey: "Erro de Formato: \(decodingError.localizedDescription)"])
                }
                return error
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func mapStatus(_ id: String) -> String {
        switch id {
        case "1": return "Novo"
        case "2": return "Atribuído"
        case "5": return "Resolvido"
        default: return "Pendente"
        }
    }
}
