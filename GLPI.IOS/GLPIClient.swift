//
//  GLPIClient.swift
//  GLPI.IOS
//

@preconcurrency import Foundation

struct GLPISearchResponse: Decodable, Sendable {
    let totalcount: Int?
    let count: Int?
    
    var total: Int {
        totalcount ?? count ?? 0
    }
}

class GLPIClient {
    static let shared = GLPIClient()
    private init() {}
    
    private var baseURL: String { PreferenceManager.shared.baseURL }
    private var appToken: String { PreferenceManager.shared.appToken }
    private var sessionToken: String { PreferenceManager.shared.sessionToken }
    
    func getStartOfMonth() -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: date) + " 00:00:00"
        }
        return ""
    }
    
    private func performSearch(query: String) async throws -> Int {
        if PreferenceManager.shared.isOfflineMode {
            if query.contains("value=4") || query.contains("value=5") || query.contains("value=6") {
                return 7 // Prioritários
            }
            return 32 // Outros (ex: Finalizados no Mês)
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        // Codificação manual para manter paridade total com OkHttp/Android
        let encodedQuery = query
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
            .replacingOccurrences(of: " ", with: "%20")
        
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(encodedQuery)&range=0-1"
        
        print("DEBUG GLPI ANDROID PARITY QUERY: \(fullURLString)")
        
        guard let url = URL(string: fullURLString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.timeoutInterval = 10
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let total = json["totalcount"] as? Int {
            return total
        }
        
        let decoded = try? JSONDecoder().decode(GLPISearchResponse.self, from: data)
        return decoded?.total ?? 0
    }
    
        func getCountFinalizadosGlobalCurrentMonth() async throws -> Int {
        let dataLimite = getStartOfMonth()
        
        // Replica exata da estrutura de sub-critérios do Android
        let query = [
            "criteria[0][criteria][0][field]=12&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=5",
            "criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=12&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=6",
            "criteria[1][link]=AND&criteria[1][field]=19&criteria[1][searchtype]=morethan&criteria[1][value]=\(dataLimite)"
        ].joined(separator: "&")
        
        return try await performSearch(query: query)
    }
    
    func getCountFinalizadosMyCurrentMonth(userId: Int) async throws -> Int {
        let dataLimite = getStartOfMonth()
        
        // Replica exata da estrutura de sub-critérios do Android (Vista Pessoal)
        let query = [
            "criteria[0][criteria][0][field]=4&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(userId)",
            "criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=5&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=\(userId)",
            "criteria[0][criteria][2][link]=OR&criteria[0][criteria][2][field]=22&criteria[0][criteria][2][searchtype]=equals&criteria[0][criteria][2][value]=\(userId)",
            "criteria[0][criteria][3][link]=OR&criteria[0][criteria][3][field]=6&criteria[0][criteria][3][searchtype]=equals&criteria[0][criteria][3][value]=\(userId)",
            "criteria[1][link]=AND&criteria[1][criteria][0][field]=12&criteria[1][criteria][0][value]=5",
            "criteria[1][criteria][1][link]=OR&criteria[1][criteria][1][field]=12&criteria[1][criteria][1][value]=6",
            "criteria[2][link]=AND&criteria[2][field]=19&criteria[2][searchtype]=morethan&criteria[2][value]=\(dataLimite)"
        ].joined(separator: "&")
        
        return try await performSearch(query: query)
    }
    
    /// Conta tickets únicos do mês atual em que o utilizador participou (criador, requerente, atribuído ou observador).
    /// O GLPI retorna cada ticket apenas uma vez mesmo que o utilizador tenha vários papéis — sem contagem duplicada.
    func getCountTicketsMeusCurrentMonth(userId: Int) async throws -> Int {
        if PreferenceManager.shared.isOfflineMode { return 3 }
        
        let dataLimite = getStartOfMonth()
        
        // Filtra pelo envolvimento do utilizador (OR entre todos os papéis)
        // + criados a partir do início do mês corrente
        let query = [
            "criteria[0][criteria][0][field]=4&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(userId)",
            "criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=5&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=\(userId)",
            "criteria[0][criteria][2][link]=OR&criteria[0][criteria][2][field]=22&criteria[0][criteria][2][searchtype]=equals&criteria[0][criteria][2][value]=\(userId)",
            "criteria[0][criteria][3][link]=OR&criteria[0][criteria][3][field]=6&criteria[0][criteria][3][searchtype]=equals&criteria[0][criteria][3][value]=\(userId)",
            // Data de criação >= início do mês (campo 15 = date)
            "criteria[1][link]=AND&criteria[1][field]=15&criteria[1][searchtype]=morethan&criteria[1][value]=\(dataLimite)"
        ].joined(separator: "&")
        
        return try await performSearch(query: query)
    }
    
    /// Obtém a LISTA de tickets finalizados (Paridade Android - Ficheiro Separado)
    func getTicketsFinalizados(userId: Int? = nil, isRequesterOnly: Bool = false, isAssignedOnly: Bool = false, range: String, order: String = "DESC") async throws -> ([GLPITicket], Int) {
        let dataLimite = getStartOfMonth()
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var queryParts: [String] = []
        
        if let uid = userId {
            // Vista Pessoal
            if isRequesterOnly {
                queryParts.append("criteria[0][criteria][0][field]=4&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(uid)")
            } else if isAssignedOnly {
                queryParts.append("criteria[0][criteria][0][field]=5&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(uid)")
            } else {
                queryParts.append("criteria[0][criteria][0][field]=4&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(uid)")
                queryParts.append("criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=5&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=\(uid)")
                queryParts.append("criteria[0][criteria][2][link]=OR&criteria[0][criteria][2][field]=22&criteria[0][criteria][2][searchtype]=equals&criteria[0][criteria][2][value]=\(uid)")
                queryParts.append("criteria[0][criteria][3][link]=OR&criteria[0][criteria][3][field]=6&criteria[0][criteria][3][searchtype]=equals&criteria[0][criteria][3][value]=\(uid)")
            }
            
            queryParts.append("criteria[1][link]=AND&criteria[1][criteria][0][field]=12&criteria[1][criteria][0][value]=5")
            queryParts.append("criteria[1][criteria][1][link]=OR&criteria[1][criteria][1][field]=12&criteria[1][criteria][1][value]=6")
            
            queryParts.append("criteria[2][link]=AND&criteria[2][field]=19&criteria[2][searchtype]=morethan&criteria[2][value]=\(dataLimite)")
        } else {
            // Vista Geral
            queryParts.append("criteria[0][criteria][0][field]=12&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=5")
            queryParts.append("criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=12&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=6")
            queryParts.append("criteria[1][link]=AND&criteria[1][field]=19&criteria[1][searchtype]=morethan&criteria[1][value]=\(dataLimite)")
        }
        
        let query = queryParts.joined(separator: "&") +
            "&forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=12&forcedisplay[3]=15&forcedisplay[4]=19&forcedisplay[5]=4&forcedisplay[6]=5&forcedisplay[7]=17&forcedisplay[8]=3&forcedisplay[9]=21&forcedisplay[10]=22&forcedisplay[11]=70&forcedisplay[12]=71&forcedisplay[13]=6" +
            "&sort=19&order=\(order)&expand_dropdowns=true&range=\(range)"
        
        let encodedQuery = query
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
            .replacingOccurrences(of: " ", with: "%20")
        
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(encodedQuery)"
        
        guard let url = URL(string: fullURLString) else { throw URLError(.badURL) }
        
        if PreferenceManager.shared.isOfflineMode {
            // Mock de tickets finalizados
            let mockTickets = [
                GLPITicket(id: "201", name: "Monitor substituído", requester: "Alice", author: "Admin", assignedTo: "Eu", description: "Feito", date: Date(), priority: .medium, status: .resolved, rawStatus: "5", isMine: true, isAssignedToMe: true),
                GLPITicket(id: "202", name: "Teclado trocado", requester: "Bob", author: "Admin", assignedTo: "Eu", description: "Feito", date: Date(), priority: .low, status: .resolved, rawStatus: "5", isMine: true, isAssignedToMe: true)
            ]
            return (mockTickets, mockTickets.count)
        }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Reutilizamos a lógica de mapeamento do Service para manter consistência de UI
        let response = try JSONDecoder().decode(TicketListResponse.self, from: data)
        let rawData = response.data ?? []
        let mapped = GLPIService.shared.mapToTickets(rawData)
        
        return (mapped, response.totalInt)
    }
    
    // --- Prioritários (Paridade Android) ---
    
    private func getPrioritariosQuery(userId: Int? = nil, isRequesterOnly: Bool = false, isAssignedOnly: Bool = false) -> String {
        var queryParts: [String] = []
        
        if let uid = userId {
            // Vista Pessoal: USER é criteria[0] (Sempre aninhado)
            if isRequesterOnly {
                queryParts.append("criteria[0][criteria][0][field]=4&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(uid)")
            } else if isAssignedOnly {
                queryParts.append("criteria[0][criteria][0][field]=5&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(uid)")
            } else {
                queryParts.append("criteria[0][criteria][0][field]=4&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(uid)")
                queryParts.append("criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=5&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=\(uid)")
                queryParts.append("criteria[0][criteria][2][link]=OR&criteria[0][criteria][2][field]=22&criteria[0][criteria][2][searchtype]=equals&criteria[0][criteria][2][value]=\(uid)")
                queryParts.append("criteria[0][criteria][3][link]=OR&criteria[0][criteria][3][field]=6&criteria[0][criteria][3][searchtype]=equals&criteria[0][criteria][3][value]=\(uid)")
            }
            
            // PRIORITY é criteria[1]
            queryParts.append("criteria[1][link]=AND&criteria[1][criteria][0][field]=3&criteria[1][criteria][0][searchtype]=equals&criteria[1][criteria][0][value]=4")
            queryParts.append("criteria[1][criteria][1][link]=OR&criteria[1][criteria][1][field]=3&criteria[1][criteria][1][searchtype]=equals&criteria[1][criteria][1][value]=5")
            queryParts.append("criteria[1][criteria][2][link]=OR&criteria[1][criteria][2][field]=3&criteria[1][criteria][2][searchtype]=equals&criteria[1][criteria][2][value]=6")
            
            // STATUS é criteria[2]
            queryParts.append("criteria[2][link]=AND&criteria[2][criteria][0][field]=12&criteria[2][criteria][0][value]=1")
            queryParts.append("criteria[2][criteria][1][link]=OR&criteria[2][criteria][1][field]=12&criteria[2][criteria][1][value]=2")
            queryParts.append("criteria[2][criteria][2][link]=OR&criteria[2][criteria][2][field]=12&criteria[2][criteria][2][value]=3")
            queryParts.append("criteria[2][criteria][3][link]=OR&criteria[2][criteria][3][field]=12&criteria[2][criteria][3][value]=4")
        } else {
            // Vista Geral
            queryParts.append("criteria[0][criteria][0][field]=12&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=1")
            queryParts.append("criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=12&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=2")
            queryParts.append("criteria[0][criteria][2][link]=OR&criteria[0][criteria][2][field]=12&criteria[0][criteria][2][searchtype]=equals&criteria[0][criteria][2][value]=3")
            queryParts.append("criteria[0][criteria][3][link]=OR&criteria[0][criteria][3][field]=12&criteria[0][criteria][3][searchtype]=equals&criteria[0][criteria][3][value]=4")
            
            queryParts.append("criteria[1][link]=AND&criteria[1][criteria][0][field]=3&criteria[1][criteria][0][searchtype]=equals&criteria[1][criteria][0][value]=4")
            queryParts.append("criteria[1][criteria][1][link]=OR&criteria[1][criteria][1][field]=3&criteria[1][criteria][1][searchtype]=equals&criteria[1][criteria][1][value]=5")
            queryParts.append("criteria[1][criteria][2][link]=OR&criteria[1][criteria][2][field]=3&criteria[1][criteria][2][searchtype]=equals&criteria[1][criteria][2][value]=6")
        }
        
        return queryParts.joined(separator: "&")
    }
    
    func getCountPrioritariosGlobal() async throws -> Int {
        return try await performSearch(query: getPrioritariosQuery())
    }
    
    func getCountPrioritariosMeus(userId: Int) async throws -> Int {
        return try await performSearch(query: getPrioritariosQuery(userId: userId))
    }
    
    func getTicketsPrioritarios(userId: Int? = nil, isRequesterOnly: Bool = false, isAssignedOnly: Bool = false, range: String, order: String = "DESC") async throws -> ([GLPITicket], Int) {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let query = getPrioritariosQuery(userId: userId, isRequesterOnly: isRequesterOnly, isAssignedOnly: isAssignedOnly) + "&range=\(range)&expand_dropdowns=true&forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=12&forcedisplay[3]=15&forcedisplay[4]=19&forcedisplay[5]=4&forcedisplay[6]=5&forcedisplay[7]=17&forcedisplay[8]=3&forcedisplay[9]=21&forcedisplay[10]=22&forcedisplay[11]=70&forcedisplay[12]=71&forcedisplay[13]=6&sort=19&order=\(order)"
        
        let encodedQuery = query.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D").replacingOccurrences(of: " ", with: "%20")
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(encodedQuery)"
        
        guard let url = URL(string: fullURLString) else { throw URLError(.badURL) }
        if PreferenceManager.shared.isOfflineMode {
            // Mock de tickets prioritários
            let mockTickets = [
                GLPITicket(id: "301", name: "Servidor Down", requester: "Admin", author: "Admin", assignedTo: "Pendente", description: "Urgente", date: Date(), priority: .major, status: .new, rawStatus: "1", isMine: false, isAssignedToMe: false)
            ]
            return (mockTickets, mockTickets.count)
        }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TicketListResponse.self, from: data)
        let mapped = GLPIService.shared.mapToTickets(response.data ?? [])
        return (mapped, response.totalInt)
    }
    
    /// Pesquisa genérica para ATUALIZAÇÕES e outros fins
    func searchTickets(userId: Int? = nil, isRequesterOnly: Bool = false, isAssignedOnly: Bool = false, range: String, sort: String = "19", order: String = "DESC") async throws -> TicketListResponse {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var queryParts: [String] = []
        if let uid = userId {
            if isRequesterOnly {
                queryParts.append("criteria[0][field]=4&criteria[0][searchtype]=equals&criteria[0][value]=\(uid)")
            } else if isAssignedOnly {
                queryParts.append("criteria[0][field]=5&criteria[0][searchtype]=equals&criteria[0][value]=\(uid)")
            } else {
                queryParts.append("criteria[0][criteria][0][field]=4&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(uid)")
                queryParts.append("criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=5&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=\(uid)")
                queryParts.append("criteria[0][criteria][2][link]=OR&criteria[0][criteria][2][field]=22&criteria[0][criteria][2][searchtype]=equals&criteria[0][criteria][2][value]=\(uid)")
                queryParts.append("criteria[0][criteria][3][link]=OR&criteria[0][criteria][3][field]=6&criteria[0][criteria][3][searchtype]=equals&criteria[0][criteria][3][value]=\(uid)")
            }
        }
        
        let criteriaQuery = queryParts.isEmpty ? "" : queryParts.joined(separator: "&") + "&"
        let query = "\(criteriaQuery)forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=12&forcedisplay[3]=15&forcedisplay[4]=19&forcedisplay[5]=4&forcedisplay[6]=5&forcedisplay[7]=17&forcedisplay[8]=3&forcedisplay[9]=21&forcedisplay[10]=22&forcedisplay[11]=70&forcedisplay[12]=71&forcedisplay[13]=6&sort=\(sort)&order=\(order)&expand_dropdowns=true&range=\(range)"
        
        let encodedQuery = query.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D").replacingOccurrences(of: " ", with: "%20")
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(encodedQuery)"
        
        guard let url = URL(string: fullURLString) else { throw URLError(.badURL) }
        
        if PreferenceManager.shared.isOfflineMode {
            // Mock de tickets para ATUALIZAÇÕES (Sincronizado com DashboardViewModel)
            let page1: [[String: AnyCodable]] = [
                ["2": AnyCodable("101"), "1": AnyCodable("Falha na rede Wi-Fi"), "4": AnyCodable("Gonçalo Sousa"), "22": AnyCodable("Admin"), "5": AnyCodable("Suporte Técnico"), "6": AnyCodable("Maria Silva"), "15": AnyCodable("2026-05-15 10:00:00"), "19": AnyCodable("2026-05-15 10:00:00"), "12": AnyCodable(1), "3": AnyCodable(4), "21": AnyCodable("Não consigo conectar no 3º andar."), "70": AnyCodable("NetworkEquipment")],
                ["2": AnyCodable("102"), "1": AnyCodable("Configuração de novo iPhone"), "4": AnyCodable("Maria Silva"), "22": AnyCodable("Suporte"), "5": AnyCodable("Redes"), "6": AnyCodable("Gonçalo Sousa"), "15": AnyCodable("2026-05-15 09:30:00"), "19": AnyCodable("2026-05-15 09:30:00"), "12": AnyCodable(2), "3": AnyCodable(3), "21": AnyCodable("Migração de dados pendente."), "70": AnyCodable("Computer")],
                ["2": AnyCodable("103"), "1": AnyCodable("Teclado MacBook pro"), "4": AnyCodable("João Mendes"), "22": AnyCodable("Admin"), "5": AnyCodable("Manutenção"), "6": AnyCodable("Admin"), "15": AnyCodable("2026-05-15 09:00:00"), "19": AnyCodable("2026-05-15 09:00:00"), "12": AnyCodable(1), "3": AnyCodable(2), "21": AnyCodable("Teclas A e S não respondem."), "70": AnyCodable("Computer")]
            ]
            
            let page2: [[String: AnyCodable]] = [
                ["2": AnyCodable("104"), "1": AnyCodable("Pedido de software Adobe"), "4": AnyCodable("Ana Costa"), "22": AnyCodable("Admin"), "5": AnyCodable("Admin"), "6": AnyCodable("Gonçalo Sousa"), "15": AnyCodable("2026-05-14 16:00:00"), "19": AnyCodable("2026-05-14 16:00:00"), "12": AnyCodable(5), "3": AnyCodable(3), "21": AnyCodable("Instalação do Photoshop solicitada.")],
                ["2": AnyCodable("105"), "1": AnyCodable("Erro ao imprimir em PDF"), "4": AnyCodable("Pedro Alves"), "22": AnyCodable("Eduardo Lima"), "5": AnyCodable("Suporte"), "6": AnyCodable("Maria Silva"), "15": AnyCodable("2026-05-14 15:30:00"), "19": AnyCodable("2026-05-14 15:30:00"), "12": AnyCodable(1), "3": AnyCodable(2), "21": AnyCodable("O driver parece estar corrompido."), "70": AnyCodable("Printer")],
                ["2": AnyCodable("106"), "1": AnyCodable("Monitor com riscas"), "4": AnyCodable("Sónia Luz"), "22": AnyCodable("Suporte"), "5": AnyCodable("Logística"), "6": AnyCodable("Admin"), "15": AnyCodable("2026-05-14 14:00:00"), "19": AnyCodable("2026-05-14 14:00:00"), "12": AnyCodable(1), "3": AnyCodable(5), "21": AnyCodable("Monitor LG parou de dar imagem."), "70": AnyCodable("Monitor")]
            ]
            
            let page3: [[String: AnyCodable]] = [
                ["2": AnyCodable("107"), "1": AnyCodable("Acesso VPN Falhou"), "4": AnyCodable("Rui Santos"), "5": AnyCodable("Redes"), "6": AnyCodable("Gonçalo Sousa"), "15": AnyCodable("2026-05-14 11:00:00"), "19": AnyCodable("2026-05-14 11:00:00"), "12": AnyCodable(1), "3": AnyCodable(5), "21": AnyCodable("Utilizador não consegue autenticar.")],
                ["2": AnyCodable("108"), "1": AnyCodable("Substituição de Toner"), "4": AnyCodable("Carla Dias"), "5": AnyCodable("Admin"), "6": AnyCodable("Suporte"), "15": AnyCodable("2026-05-14 10:30:00"), "19": AnyCodable("2026-05-14 10:30:00"), "12": AnyCodable(2), "3": AnyCodable(2), "21": AnyCodable("Impressora do RH sem tinta."), "70": AnyCodable("Printer")],
                ["2": AnyCodable("109"), "1": AnyCodable("Atualização de Segurança"), "4": AnyCodable("Nuno Lima"), "5": AnyCodable("Segurança"), "6": AnyCodable("Admin"), "15": AnyCodable("2026-05-14 09:00:00"), "19": AnyCodable("2026-05-14 09:00:00"), "12": AnyCodable(1), "3": AnyCodable(4), "21": AnyCodable("Patch de Maio necessário.")]
            ]
            
            let selectedData: [[String: AnyCodable]]
            if range.starts(with: "0-") { selectedData = page1 }
            else if range.starts(with: "3-") { selectedData = page2 }
            else if range.starts(with: "6-") { selectedData = page3 }
            else { selectedData = page1 }
            
            return TicketListResponse(totalcount: 9, count: 3, data: selectedData)
        }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TicketListResponse.self, from: data)
    }
    
    /// Pesquisa para o Calendário / Agenda (Tickets Ativos)
    func getAgendaTickets(userId: Int? = nil) async throws -> [GLPITicket] {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var queryParts: [String] = []
        var nextCriteriaIndex = 0
        
        if let uid = userId {
            // Apenas ativos (1, 2, 3, 4)
            queryParts.append("criteria[\(nextCriteriaIndex)][criteria][0][field]=12&criteria[\(nextCriteriaIndex)][criteria][0][searchtype]=equals&criteria[\(nextCriteriaIndex)][criteria][0][value]=1")
            queryParts.append("criteria[\(nextCriteriaIndex)][criteria][1][link]=OR&criteria[\(nextCriteriaIndex)][criteria][1][field]=12&criteria[\(nextCriteriaIndex)][criteria][1][searchtype]=equals&criteria[\(nextCriteriaIndex)][criteria][1][value]=2")
            queryParts.append("criteria[\(nextCriteriaIndex)][criteria][2][link]=OR&criteria[\(nextCriteriaIndex)][criteria][2][field]=12&criteria[\(nextCriteriaIndex)][criteria][2][searchtype]=equals&criteria[\(nextCriteriaIndex)][criteria][2][value]=3")
            queryParts.append("criteria[\(nextCriteriaIndex)][criteria][3][link]=OR&criteria[\(nextCriteriaIndex)][criteria][3][field]=12&criteria[\(nextCriteriaIndex)][criteria][3][searchtype]=equals&criteria[\(nextCriteriaIndex)][criteria][3][value]=4")
            
            nextCriteriaIndex += 1
            
            // Para o Utilizador (requester, assignee, observer)
            queryParts.append("criteria[\(nextCriteriaIndex)][link]=AND&criteria[\(nextCriteriaIndex)][criteria][0][field]=4&criteria[\(nextCriteriaIndex)][criteria][0][searchtype]=equals&criteria[\(nextCriteriaIndex)][criteria][0][value]=\(uid)")
            queryParts.append("criteria[\(nextCriteriaIndex)][criteria][1][link]=OR&criteria[\(nextCriteriaIndex)][criteria][1][field]=5&criteria[\(nextCriteriaIndex)][criteria][1][searchtype]=equals&criteria[\(nextCriteriaIndex)][criteria][1][value]=\(uid)")
            queryParts.append("criteria[\(nextCriteriaIndex)][criteria][2][link]=OR&criteria[\(nextCriteriaIndex)][criteria][2][field]=22&criteria[\(nextCriteriaIndex)][criteria][2][searchtype]=equals&criteria[\(nextCriteriaIndex)][criteria][2][value]=\(uid)")
        } else {
            // Geral - apenas não apagados (is_deleted=0)
            queryParts.append("is_deleted=0")
        }
        
        let criteriaQuery = queryParts.isEmpty ? "" : queryParts.joined(separator: "&") + "&"
        // Adicionados campos para datas: 15=Data Criação, 18=Data Limite, 151=TTR, 158=TTO
        let query = "\(criteriaQuery)forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=12&forcedisplay[3]=15&forcedisplay[4]=19&forcedisplay[5]=4&forcedisplay[6]=5&forcedisplay[7]=17&forcedisplay[8]=3&forcedisplay[9]=21&forcedisplay[10]=22&forcedisplay[11]=18&forcedisplay[12]=14&forcedisplay[13]=70&forcedisplay[14]=71&forcedisplay[15]=151&forcedisplay[16]=158&sort=19&order=DESC&expand_dropdowns=true&range=0-500"
        
        let encodedQuery = query.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D").replacingOccurrences(of: " ", with: "%20")
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(encodedQuery)"
        
        guard let url = URL(string: fullURLString) else { throw URLError(.badURL) }
        
        if PreferenceManager.shared.isOfflineMode {
            return []
        }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TicketListResponse.self, from: data)
        
        // Se for vista geral, filtar finalizados(5) e fechados(6)
        var filteredData = response.data ?? []
        let mappedTickets = GLPIService.shared.mapToTickets(filteredData)
        
        return mappedTickets.filter { ticket in
            let isNotResolvedOrClosed = ticket.status != .resolved && ticket.status != .deleted
            return isNotResolvedOrClosed
        }
    }
    
    private func extractId(from value: Any?) -> String {
        guard let value = value else { return "" }
        if let dict = value as? [String: Any], let id = dict["id"] {
            return "\(id)"
        }
        if let array = value as? [[String: Any]], let first = array.first, let id = first["id"] {
            return "\(id)"
        }
        return "\(value)"
    }
    
    /// Obtém um ticket detalhado pelo ID
    func getTicketById(id: String) async throws -> [String: Any] {
        if PreferenceManager.shared.isOfflineMode {
            return [:]
        }
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket/\(id)?expand_dropdowns=true"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }
    
    /// Obtém a lista de categorias do GLPI
    func getITILCategories() async throws -> [[String: Any]] {
        if PreferenceManager.shared.isOfflineMode {
            return []
        }
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/ITILCategory?range=0-200"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return jsonArray
        }
        return []
    }
    
    /// Atualiza os dados de um ticket no GLPI
    func updateTicket(id: String, input: [String: Any]) async throws -> Bool {
        if PreferenceManager.shared.isOfflineMode {
            return true
        }
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket/\(id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = ["input": input]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200 || httpResponse.statusCode == 201
        }
        return false
    }
    
    /// Cria um novo ticket no GLPI e devolve o ID do ticket criado
    func createTicket(input: [String: Any]) async throws -> String? {
        if PreferenceManager.shared.isOfflineMode {
            return "mock_new_id"
        }
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = ["input": input]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
            if let json = try? JSONSerialization.jsonObject(with: data) {
                if let dict = json as? [String: Any], let idVal = dict["id"] {
                    return String(describing: idVal)
                } else if let array = json as? [[String: Any]], let first = array.first, let idVal = first["id"] {
                    return String(describing: idVal)
                }
            }
        }
        return nil
    }
    
    /// Obtém os atores de um ticket
    func getTicketActors(ticketId: String) async throws -> [[String: Any]] {
        if PreferenceManager.shared.isOfflineMode {
            return []
        }
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket/\(ticketId)/Ticket_User?expand_dropdowns=true"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return jsonArray
        }
        return []
    }
    
    /// Remove um ator de um ticket pelo ID da relação Ticket_User
    func deleteTicketActor(relationshipId: Int) async throws -> Bool {
        if PreferenceManager.shared.isOfflineMode {
            return true
        }
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket_User/\(relationshipId)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200 || httpResponse.statusCode == 204
        }
        return false
    }
    
    /// Associa um ator a um ticket (type: 1 = Requester, 2 = Technician, 3 = Observer)
    func addTicketActor(ticketId: String, userId: String, type: Int) async throws -> Bool {
        if PreferenceManager.shared.isOfflineMode {
            return true
        }
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket_User"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "input": [
                "tickets_id": ticketId,
                "users_id": userId,
                "type": type
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200 || httpResponse.statusCode == 201
        }
        return false
    }
    
    /// Pesquisa utilizadores no GLPI com base numa query de texto
    func searchUsers(query: String) async throws -> [(id: String, name: String)] {
        if PreferenceManager.shared.isOfflineMode {
            return [
                ("1", "Gonçalo Sousa"),
                ("2", "Maria Silva"),
                ("3", "João Mendes"),
                ("4", "Ana Costa"),
                ("5", "Pedro Alves")
            ].filter { $0.1.localizedCaseInsensitiveContains(query) }
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let qEncoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "\(cleanBaseURL)/apirest.php/search/User?" +
            "forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=34&forcedisplay[3]=9" +
            "&criteria[0][field]=1&criteria[0][searchtype]=contains&criteria[0][value]=\(qEncoded)" +
            "&criteria[1][link]=OR&criteria[1][field]=9&criteria[1][searchtype]=contains&criteria[1][value]=\(qEncoded)" +
            "&criteria[2][link]=OR&criteria[2][field]=34&criteria[2][searchtype]=contains&criteria[2][value]=\(qEncoded)" +
            "&range=0-50"
            
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        var results: [(id: String, name: String)] = []
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataArray = json["data"] as? [[String: Any]] {
            for item in dataArray {
                let id = String(describing: item["2"] ?? "")
                let fname = item["34"] as? String ?? ""
                let rname = item["9"] as? String ?? ""
                let uname = item["1"] as? String ?? ""
                
                let fullName = fname.isEmpty && rname.isEmpty ? uname : "\(fname) \(rname)".trimmingCharacters(in: .whitespaces)
                if !id.isEmpty && !fullName.isEmpty {
                    results.append((id: id, name: fullName))
                }
            }
        }
        return results
    }
    
    /// Move um ticket para a reciclagem
    func trashTicket(id: String) async throws -> Bool {
        if PreferenceManager.shared.isOfflineMode {
            return true
        }
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket/\(id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200 || httpResponse.statusCode == 204
        }
        return false
    }
    
    /// Elimina permanentemente um ticket (purge)
    func purgeTicket(id: String) async throws -> Bool {
        if PreferenceManager.shared.isOfflineMode {
            return true
        }
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket/\(id)?force_purge=true"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200 || httpResponse.statusCode == 204
        }
        return false
    }
    
    /// Restaura um ticket da reciclagem
    func restoreTicket(id: String) async throws -> Bool {
        return try await updateTicket(id: id, input: ["id": id, "is_deleted": 0])
    }
    
    /// Obtém estatísticas mensais (totalcount de tickets criados ou finalizados num mês específico)
    func getEstatisticasMensais(fieldDate: Int, yearMonth: String) async throws -> Int {
        if PreferenceManager.shared.isOfflineMode {
            if fieldDate == 15 {
                // Atribuídos mock
                return Int.random(in: 30...65)
            } else {
                // Finalizados mock
                return Int.random(in: 25...60)
            }
        }
        
        let query = "criteria[0][field]=\(fieldDate)&criteria[0][searchtype]=contains&criteria[0][value]=\(yearMonth)&is_deleted=0"
        return try await performSearch(query: query)
    }
    
    /// Obtém a lista de categorias para as estatísticas
    func getCategoriasEstatisticas(dataLimite: String) async throws -> TicketListResponse {
        if PreferenceManager.shared.isOfflineMode {
            let mockData: [[String: AnyCodable]] = [
                ["7": AnyCodable("SOFTWARE"), "2": AnyCodable("1")],
                ["7": AnyCodable("SOFTWARE"), "2": AnyCodable("2")],
                ["7": AnyCodable("HARDWARE"), "2": AnyCodable("3")],
                ["7": AnyCodable("REDE"), "2": AnyCodable("4")],
                ["7": AnyCodable("REDE"), "2": AnyCodable("5")],
                ["7": AnyCodable("OUTROS"), "2": AnyCodable("6")]
            ]
            return TicketListResponse(totalcount: mockData.count, count: mockData.count, data: mockData)
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let query = "criteria[0][field]=15&criteria[0][searchtype]=morethan&criteria[0][value]=\(dataLimite)&forcedisplay[0]=7&range=0-3000&expand_dropdowns=true"
        
        let encodedQuery = query
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
            .replacingOccurrences(of: " ", with: "%20")
            
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(encodedQuery)"
        
        guard let url = URL(string: fullURLString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TicketListResponse.self, from: data)
    }
    
    // MARK: - Modelo de Ticket Associado a Ativo
    struct AssetLinkedTicket: Identifiable {
        let id: String           // ID do ticket
        let ticketName: String   // Título do ticket
        let deviceName: String   // Nome do dispositivo (se conhecido)
        let deviceType: String   // "Computer", "Monitor", "Printer", "NetworkEquipment"
        let requester: String
        let assignedTo: String
        let rawStatus: String
        let date: Date
        let priority: Int
        
        var statusLabel: String {
            switch rawStatus {
            case "1": return "Novo"
            case "2": return "Atribuído"
            case "3": return "Planeado"
            case "4": return "Aguardando"
            case "5": return "Finalizado"
            case "6": return "Encerrado"
            default: return "Novo"
            }
        }
        
        var statusColor: String {
            switch rawStatus {
            case "1": return "cyan"
            case "2": return "yellow"
            case "3": return "purple"
            case "4": return "orange"
            case "5": return "green"
            case "6": return "gray"
            default: return "cyan"
            }
        }
        
        var deviceIcon: String {
            switch deviceType {
            case "Computer": return "laptopcomputer"
            case "Monitor": return "display"
            case "Printer": return "printer"
            case "NetworkEquipment": return "network"
            default: return "desktopcomputer"
            }
        }
        
        var deviceTypeLabel: String {
            switch deviceType {
            case "Computer": return "Computador"
            case "Monitor": return "Monitor"
            case "Printer": return "Impressora"
            case "NetworkEquipment": return "Rede"
            default: return deviceType
            }
        }
    }
    
    struct AssetHistoryItem: Identifiable {
        var id: String { "\(asset.type.rawValue)-\(asset.realId)" }
        let asset: Asset
        let ticketCount: Int
    }
    
    struct TicketWithAsset: Identifiable {
        var id: String { ticket.id }
        let ticket: GLPITicket
        let asset: Asset
    }
    
    func getAssetsWithTickets() async throws -> [TicketWithAsset] {
        if PreferenceManager.shared.isOfflineMode {
            // Mock data for TICKETS with ASSETS
            return [
                TicketWithAsset(
                    ticket: GLPITicket(id: "101", name: "Problema grave detetado: O ecrã do monitor principal não liga após atualização do sistema e está a piscar de forma intermitente com uma luz vermelha", requester: "Gonçalo Sousa", author: "Gonçalo Sousa", assignedTo: "Suporte IT", observer: "", description: "O monitor externo deixou de dar imagem de repente.", date: Date().addingTimeInterval(-86400), priority: .medium, status: .new, rawStatus: "1", isMine: true, isAssignedToMe: false),
                    asset: Asset(realId: 2, name: "Monitor Dell UltraSharp", tag: "TAG-042", icon: "display", type: .monitor, status: "Ativo", owner: "Gonçalo Sousa", department: "DSI", serialNumber: "DL293041")
                ),
                TicketWithAsset(
                    ticket: GLPITicket(id: "102", name: "Teclado com teclas presas", requester: "Gonçalo Sousa", author: "Gonçalo Sousa", assignedTo: "Suporte IT", observer: "", description: "As teclas 'A' e 'S' não registam o clique.", date: Date().addingTimeInterval(-172800), priority: .low, status: .assigned, rawStatus: "2", isMine: true, isAssignedToMe: false),
                    asset: Asset(realId: 1, name: "MacBook Pro M3 - GS", tag: "TAG-001", icon: "desktopcomputer", type: .computer, status: "Ativo", owner: "Gonçalo Sousa", department: "DSI", serialNumber: "8HX9J2L1")
                ),
                TicketWithAsset(
                    ticket: GLPITicket(id: "103", name: "Papel encravado", requester: "Geral", author: "Geral", assignedTo: "Helpdesk", observer: "", description: "A impressora está a encravar o papel sistematicamente.", date: Date().addingTimeInterval(-259200), priority: .high, status: .resolved, rawStatus: "5", isMine: false, isAssignedToMe: false),
                    asset: Asset(realId: 3, name: "Impressora HP Enterprise", tag: "TAG-015", icon: "printer", type: .printer, status: "Inativo", owner: "Geral", department: "Administração", serialNumber: "VNB3K02948")
                ),
                TicketWithAsset(
                    ticket: GLPITicket(id: "104", name: "Bateria viciada", requester: "Ana Silva", author: "Ana Silva", assignedTo: "Suporte IT", observer: "", description: "O portátil desliga-se após 10 minutos fora da corrente.", date: Date().addingTimeInterval(-345600), priority: .medium, status: .resolved, rawStatus: "6", isMine: false, isAssignedToMe: false),
                    asset: Asset(realId: 4, name: "MacBook Air M2", tag: "TAG-008", icon: "desktopcomputer", type: .computer, status: "Ativo", owner: "Ana Silva", department: "Marketing", serialNumber: "SN-MBA-7731")
                ),
                TicketWithAsset(
                    ticket: GLPITicket(id: "105", name: "Cores distorcidas", requester: "João Paulo", author: "João Paulo", assignedTo: "Suporte IT", observer: "", description: "O monitor apresenta tons de rosa em vez de branco.", date: Date().addingTimeInterval(-432000), priority: .high, status: .new, rawStatus: "1", isMine: false, isAssignedToMe: false),
                    asset: Asset(realId: 5, name: "Monitor Dell 27\"", tag: "TAG-050", icon: "display", type: .monitor, status: "Ativo", owner: "João Paulo", department: "Design", serialNumber: "CN-0F9XJ8-74261")
                ),
                TicketWithAsset(
                    ticket: GLPITicket(id: "106", name: "Porta de rede avariada", requester: "Infraestrutura", author: "Infraestrutura", assignedTo: "Redes", observer: "", description: "A porta 12 não tem link.", date: Date().addingTimeInterval(-518400), priority: .veryHigh, status: .assigned, rawStatus: "2", isMine: false, isAssignedToMe: true),
                    asset: Asset(realId: 6, name: "Switch Cisco Catalyst", tag: "TAG-099", icon: "network", type: .network, status: "Ativo", owner: "Infraestrutura", department: "IT", serialNumber: "FOC2349U3M2")
                )
            ]
        }
        
        let types = ["Computer", "Monitor", "NetworkEquipment", "Printer"]
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var results: [TicketWithAsset] = []
        
        for type in types {
            // Filtra por itens que têm tickets (campo 60 notcontains 0)
            let urlString = "\(cleanBaseURL)/apirest.php/search/\(type)?range=0-99&criteria[0][field]=60&criteria[0][searchtype]=notcontains&criteria[0][value]=0&forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=5&forcedisplay[3]=70&forcedisplay[4]=3&forcedisplay[5]=31&forcedisplay[6]=60&expand_dropdowns=true"
            
            let encodedQuery = urlString
                .replacingOccurrences(of: "[", with: "%5B")
                .replacingOccurrences(of: "]", with: "%5D")
                
            guard let url = URL(string: encodedQuery) else { continue }
            
            var request = URLRequest(url: url)
            request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
            request.addValue(appToken, forHTTPHeaderField: "App-Token")
            request.timeoutInterval = 15
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let decoded = try JSONDecoder().decode(TicketListResponse.self, from: data)
                if let dataArray = decoded.data {
                    for item in dataArray {
                        let name = item["1"]?.value as? String ?? "Equipamento"
                        let realId = Int(String(describing: item["2"]?.value ?? "0")) ?? 0
                        let serial = parseAssetFieldForDevice(item["5"]?.value) ?? ""
                        let owner = parseAssetFieldForDevice(item["70"]?.value)
                        let department = parseAssetFieldForDevice(item["3"]?.value)
                        let status = parseAssetFieldForDevice(item["31"]?.value) ?? "Nenhum"
                        let ticketCountStr = String(describing: item["60"]?.value ?? "0")
                        let ticketCount = Int(ticketCountStr) ?? 0
                        
                        let assetType: AssetType
                        switch type {
                        case "Computer": assetType = .computer
                        case "Monitor": assetType = .monitor
                        case "Printer": assetType = .printer
                        case "NetworkEquipment": assetType = .network
                        default: assetType = .network
                        }
                        
                        let asset = Asset(
                            realId: realId,
                            name: name,
                            tag: "TAG-\(realId)",
                            icon: assetType.rawValue,
                            type: assetType,
                            status: status,
                            owner: owner,
                            department: department,
                            serialNumber: serial
                        )
                        
                        if ticketCount > 0 {
                            for i in 0..<ticketCount {
                                let ticket = GLPITicket(
                                    id: "\(realId)-\(i)",
                                    name: "Ticket \(i + 1) de \(name)",
                                    requester: owner ?? "Utilizador",
                                    author: owner ?? "Utilizador",
                                    assignedTo: "",
                                    observer: "",
                                    description: "",
                                    date: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                                    priority: .medium,
                                    status: .new,
                                    rawStatus: "1",
                                    isMine: true,
                                    isAssignedToMe: false
                                )
                                results.append(TicketWithAsset(ticket: ticket, asset: asset))
                            }
                        }
                    }
                }
            } catch {
                print("Erro ao obter dispositivos com histórico para \(type): \(error)")
            }
        }
        
        return results
    }
    
    func getTicketsForAsset(assetType: String, assetId: Int) async throws -> [AssetLinkedTicket] {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        // 1. Fetch Item_Ticket relationships for this specific asset
        var linkReq = URLRequest(url: URL(string: "\(cleanBaseURL)/apirest.php/\(assetType)/\(assetId)/Item_Ticket")!)
        linkReq.httpMethod = "GET"
        linkReq.addValue(appToken, forHTTPHeaderField: "App-Token")
        linkReq.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        
        let (linkData, linkResp) = try await URLSession.shared.data(for: linkReq)
        guard let linkHttp = linkResp as? HTTPURLResponse, linkHttp.statusCode == 200 else {
            return []
        }
        
        var validTicketIDs: [String] = []
        if let linkArray = try? JSONSerialization.jsonObject(with: linkData) as? [[String: Any]] {
            for link in linkArray {
                if let tId = link["tickets_id"] {
                    validTicketIDs.append(String(describing: tId))
                }
            }
        }
        
        if validTicketIDs.isEmpty { return [] }
        
        var results: [AssetLinkedTicket] = []
        var seen: Set<String> = []
        
        let dateParser = DateFormatter()
        dateParser.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateParser.timeZone = TimeZone(secondsFromGMT: 0)
        dateParser.locale = Locale(identifier: "en_US_POSIX")
        
        for ticketId in validTicketIDs {
            if seen.contains(ticketId) { continue }
            seen.insert(ticketId)
            
            let queryParts = [
                "criteria[0][field]=2",
                "criteria[0][searchtype]=equals",
                "criteria[0][value]=\(ticketId)",
                "forcedisplay[0]=1",
                "forcedisplay[1]=2",
                "forcedisplay[2]=4",
                "forcedisplay[3]=5",
                "forcedisplay[4]=12",
                "forcedisplay[5]=15",
                "forcedisplay[6]=3",
                "expand_dropdowns=true",
                "range=0-1"
            ].joined(separator: "&")
            
            var request = URLRequest(url: URL(string: "\(cleanBaseURL)/apirest.php/search/Ticket?\(queryParts)")!)
            request.httpMethod = "GET"
            request.addValue(appToken, forHTTPHeaderField: "App-Token")
            request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    let decoded = try JSONDecoder().decode(TicketListResponse.self, from: data)
                    if let item = decoded.data?.first {
                        let ticketName = String(describing: item["1"]?.value ?? "Sem título")
                        let rawRequester = String(describing: item["4"]?.value ?? "Desconhecido")
                        let rawTech = String(describing: item["5"]?.value ?? "Não atribuído")
                        
                        let requester = (rawRequester.isEmpty || rawRequester == "null" || rawRequester == "[]") ? "Desconhecido" : rawRequester
                        let tech = (rawTech.isEmpty || rawTech == "null" || rawTech == "[]") ? "Não atribuído" : rawTech
                        
                        let statusRaw = String(describing: item["12"]?.value ?? "1").replacingOccurrences(of: ".0", with: "")
                        let priorityRaw = Int(String(describing: item["3"]?.value ?? "3").replacingOccurrences(of: ".0", with: "")) ?? 3
                        
                        let dateStr = String(describing: item["15"]?.value ?? "")
                        let parsedDate = dateParser.date(from: dateStr) ?? Date()
                        
                        results.append(AssetLinkedTicket(
                            id: ticketId,
                            ticketName: ticketName,
                            deviceName: "", // We don't need it because DeviceTicketHistoryView already knows the device name!
                            deviceType: assetType,
                            requester: requester,
                            assignedTo: tech,
                            rawStatus: statusRaw,
                            date: parsedDate,
                            priority: priorityRaw
                        ))
                    }
                }
            } catch {
                print("Erro ao buscar detalhes do ticket \(ticketId): \(error)")
            }
        }
        
        return results.sorted { $0.id > $1.id }
    }
    
    /// Obtém todos os tickets do utilizador para estatísticas pessoais
    func getTodosMeusTicketsStats(userId: Int) async throws -> TicketListResponse {
        if PreferenceManager.shared.isOfflineMode {
            // Retorna dados de mock para offline
            let mockData: [[String: AnyCodable]] = [
                ["15": AnyCodable("2026-05-10 10:00:00"), "19": AnyCodable("2026-05-12 11:00:00"), "12": AnyCodable("5"), "3": AnyCodable("4")],
                ["15": AnyCodable("2026-05-15 12:00:00"), "19": AnyCodable("2026-05-15 14:00:00"), "12": AnyCodable("6"), "3": AnyCodable("2")],
                ["15": AnyCodable("2026-05-18 09:00:00"), "19": AnyCodable("2026-05-18 09:00:00"), "12": AnyCodable("1"), "3": AnyCodable("5")],
                ["15": AnyCodable("2026-04-10 10:00:00"), "19": AnyCodable("2026-04-12 11:00:00"), "12": AnyCodable("5"), "3": AnyCodable("2")],
                ["15": AnyCodable("2026-04-20 10:00:00"), "19": AnyCodable("2026-04-22 11:00:00"), "12": AnyCodable("2"), "3": AnyCodable("3")],
                ["15": AnyCodable("2026-03-05 10:00:00"), "19": AnyCodable("2026-03-06 11:00:00"), "12": AnyCodable("5"), "3": AnyCodable("4")],
                ["15": AnyCodable("2026-02-15 10:00:00"), "19": AnyCodable("2026-02-28 11:00:00"), "12": AnyCodable("5"), "3": AnyCodable("1")],
                ["15": AnyCodable("2026-01-12 10:00:00"), "19": AnyCodable("2026-01-14 11:00:00"), "12": AnyCodable("6"), "3": AnyCodable("5")],
                ["15": AnyCodable("2025-12-01 10:00:00"), "19": AnyCodable("2025-12-05 11:00:00"), "12": AnyCodable("5"), "3": AnyCodable("3")]
            ]
            return TicketListResponse(totalcount: mockData.count, count: mockData.count, data: mockData)
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let query = [
            "criteria[0][field]=4&criteria[0][searchtype]=equals&criteria[0][value]=\(userId)",
            "criteria[1][link]=OR&criteria[1][field]=5&criteria[1][searchtype]=equals&criteria[1][value]=\(userId)",
            "criteria[2][link]=OR&criteria[2][field]=22&criteria[2][searchtype]=equals&criteria[2][value]=\(userId)",
            "criteria[3][link]=OR&criteria[3][field]=6&criteria[3][searchtype]=equals&criteria[3][value]=\(userId)",
            "expand_dropdowns=true",
            "forcedisplay[0]=2&forcedisplay[1]=1&forcedisplay[2]=15&forcedisplay[3]=151&forcedisplay[4]=158&forcedisplay[5]=19&forcedisplay[6]=12&forcedisplay[7]=3&forcedisplay[8]=6",
            "range=0-999"
        ].joined(separator: "&")
        
        let encodedQuery = query
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
            .replacingOccurrences(of: " ", with: "%20")
            
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(encodedQuery)"
        
        guard let url = URL(string: fullURLString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TicketListResponse.self, from: data)
    }
    
    /// Pesquisa inventário com base no itemtype, range e texto de pesquisa
    func searchInventory(itemtype: String, range: String, searchText: String) async throws -> TicketListResponse {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var queryParts: [String] = []
        // Campos forcedisplay (Nome, ID, Localização, Serial, Utilizador, Estado)
        queryParts.append("forcedisplay[0]=1") // Nome
        queryParts.append("forcedisplay[1]=2") // ID
        queryParts.append("forcedisplay[2]=3") // Localização
        queryParts.append("forcedisplay[3]=5") // Serial
        queryParts.append("forcedisplay[4]=70") // Utilizador
        queryParts.append("forcedisplay[5]=8") // Técnico Responsável
        queryParts.append("forcedisplay[6]=24")
        queryParts.append("forcedisplay[7]=14")
        queryParts.append("forcedisplay[8]=15")
        queryParts.append("forcedisplay[9]=31") // Estado
        
        if !searchText.isEmpty {
            queryParts.append("criteria[0][link]=AND")
            queryParts.append("criteria[0][criteria][0][field]=1")
            queryParts.append("criteria[0][criteria][0][searchtype]=contains")
            queryParts.append("criteria[0][criteria][0][value]=\(searchText)")
            queryParts.append("criteria[0][criteria][1][link]=OR")
            queryParts.append("criteria[0][criteria][1][field]=5")
            queryParts.append("criteria[0][criteria][1][searchtype]=contains")
            queryParts.append("criteria[0][criteria][1][value]=\(searchText)")
        }
        
        let query = queryParts.joined(separator: "&") + "&expand_dropdowns=true&range=\(range)"
        let encodedQuery = query
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
            .replacingOccurrences(of: " ", with: "%20")
            
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/\(itemtype)?\(encodedQuery)"
        
        guard let url = URL(string: fullURLString) else { throw URLError(.badURL) }
        
        if PreferenceManager.shared.isOfflineMode {
            // Mock robusto de dados para modo offline
            let mockData: [[String: AnyCodable]] = [
                ["2": AnyCodable("1"), "1": AnyCodable("MacBook Pro 16\""), "3": AnyCodable("Tecnologia"), "5": AnyCodable("C02F9XJ8MD6M"), "70": AnyCodable("João Silva"), "31": AnyCodable("Vigor")],
                ["2": AnyCodable("2"), "1": AnyCodable("Monitor Dell 27\""), "3": AnyCodable("Design"), "5": AnyCodable("CN-0F9XJ8-74261"), "70": AnyCodable("Maria Santos"), "31": AnyCodable("Vigor")],
                ["2": AnyCodable("3"), "1": AnyCodable("Teclado Magic Keyboard"), "3": AnyCodable("Stock"), "5": AnyCodable("SN-KEY-990"), "70": AnyCodable("N/A"), "31": AnyCodable("Novo")],
                ["2": AnyCodable("4"), "1": AnyCodable("Impressora HP Enterprise"), "3": AnyCodable("Administração"), "5": AnyCodable("VNB3K02948"), "70": AnyCodable("Piso 1"), "31": AnyCodable("Avariado")],
                ["2": AnyCodable("5"), "1": AnyCodable("Switch Cisco 24 Portas"), "3": AnyCodable("Sala Bastidores"), "5": AnyCodable("SN-CISCO-8827"), "70": AnyCodable("DSI"), "31": AnyCodable("Vigor")],
                ["2": AnyCodable("6"), "1": AnyCodable("MacBook Air M2"), "3": AnyCodable("Tecnologia"), "5": AnyCodable("SN-MBA-7731"), "70": AnyCodable("Gonçalo Sousa"), "31": AnyCodable("Vigor")],
                ["2": AnyCodable("7"), "1": AnyCodable("Monitor LG UltraFine"), "3": AnyCodable("Design"), "5": AnyCodable("SN-LG-5542"), "70": AnyCodable("Ana Martins"), "31": AnyCodable("Vigor")],
                ["2": AnyCodable("8"), "1": AnyCodable("Switch Aruba 48 Portas"), "3": AnyCodable("Sala Bastidores"), "5": AnyCodable("SN-ARUBA-112"), "70": AnyCodable("DSI"), "31": AnyCodable("Vigor")]
            ]
            
            var filteredMock = mockData
            
            // Filtrar por tipo
            if itemtype == "Computer" {
                filteredMock = filteredMock.filter { ($0["1"]?.value as? String ?? "").contains("MacBook") }
            } else if itemtype == "Monitor" {
                filteredMock = filteredMock.filter { ($0["1"]?.value as? String ?? "").contains("Monitor") }
            } else if itemtype == "Printer" {
                filteredMock = filteredMock.filter { ($0["1"]?.value as? String ?? "").contains("Impressora") }
            } else if itemtype == "NetworkEquipment" {
                filteredMock = filteredMock.filter { ($0["1"]?.value as? String ?? "").contains("Switch") }
            }
            
            // Filtrar por texto de pesquisa
            if !searchText.isEmpty {
                filteredMock = filteredMock.filter { item in
                    let name = item["1"]?.value as? String ?? ""
                    let serial = item["5"]?.value as? String ?? ""
                    return name.lowercased().contains(searchText.lowercased()) || serial.lowercased().contains(searchText.lowercased())
                }
            }
            
            // Paginar
            let rangeParts = range.split(separator: "-")
            if rangeParts.count == 2, let start = Int(rangeParts[0]), let end = Int(rangeParts[1]) {
                let startIndex = min(start, filteredMock.count)
                let endIndex = min(end + 1, filteredMock.count)
                let sliced = Array(filteredMock[startIndex..<endIndex])
                return TicketListResponse(totalcount: filteredMock.count, count: sliced.count, data: sliced)
            }
            return TicketListResponse(totalcount: filteredMock.count, count: filteredMock.count, data: filteredMock)
        }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw URLError(.userAuthenticationRequired)
        }
        
        return try JSONDecoder().decode(TicketListResponse.self, from: data)
    }
    
    /// Obtém a contagem de dispositivos onde o utilizador é utilizador/proprietário (campo 70) ou técnico responsável (campo 24)
    func getMyDevicesCount(userId: Int) async throws -> Int {
        if PreferenceManager.shared.isOfflineMode {
            return 3
        }
        
        let types = ["Computer", "Monitor", "NetworkEquipment", "Printer"]
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var total = 0
        for type in types {
            let urlString = "\(cleanBaseURL)/apirest.php/search/\(type)?range=0-0&criteria[0][field]=70&criteria[0][searchtype]=equals&criteria[0][value]=\(userId)&criteria[1][link]=OR&criteria[1][field]=24&criteria[1][searchtype]=equals&criteria[1][value]=\(userId)"
            
            let encodedQuery = urlString
                .replacingOccurrences(of: "[", with: "%5B")
                .replacingOccurrences(of: "]", with: "%5D")
                
            guard let url = URL(string: encodedQuery) else { continue }
            
            var request = URLRequest(url: url)
            request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
            request.addValue(appToken, forHTTPHeaderField: "App-Token")
            request.timeoutInterval = 10
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let decoded = try JSONDecoder().decode(TicketListResponse.self, from: data)
                total += decoded.totalInt
            } catch {
                print("Erro ao obter contagem para \(type): \(error)")
            }
        }
        return total
    }
    
    /// Obtém os dispositivos onde o utilizador é utilizador/proprietário (campo 70) ou técnico responsável (campo 24)
    func getMyDevices(userId: Int) async throws -> [Asset] {
        if PreferenceManager.shared.isOfflineMode {
            // Mock de dados para modo offline do utilizador logado
            let mockData: [Asset] = [
                Asset(realId: 1, name: "MacBook Pro M3 - GS", tag: "TAG-001", icon: "desktopcomputer", type: .computer, status: "Ativo", owner: PreferenceManager.shared.userName ?? "Gonçalo Sousa", department: "DSI", serialNumber: "8HX9J2L1"),
                Asset(realId: 2, name: "Monitor Dell UltraSharp", tag: "TAG-042", icon: "display", type: .monitor, status: "Ativo", owner: PreferenceManager.shared.userName ?? "Gonçalo Sousa", department: "DSI", serialNumber: "DL293041"),
                Asset(realId: 3, name: "Teclado Magic Keyboard", tag: "TAG-990", icon: "keyboard", type: .network, status: "Ativo", owner: PreferenceManager.shared.userName ?? "Gonçalo Sousa", department: "DSI", serialNumber: "SN-KEY-990")
            ]
            return Array(mockData.prefix(3))
        }
        
        let types = ["Computer", "Monitor", "NetworkEquipment", "Printer"]
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var allAssets: [Asset] = []
        
        for type in types {
            let urlString = "\(cleanBaseURL)/apirest.php/search/\(type)?range=0-999&criteria[0][field]=70&criteria[0][searchtype]=equals&criteria[0][value]=\(userId)&criteria[1][link]=OR&criteria[1][field]=24&criteria[1][searchtype]=equals&criteria[1][value]=\(userId)&forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=3&forcedisplay[3]=5&forcedisplay[4]=70&forcedisplay[5]=24&forcedisplay[6]=14&forcedisplay[7]=15&forcedisplay[8]=31&expand_dropdowns=true"
            
            let encodedQuery = urlString
                .replacingOccurrences(of: "[", with: "%5B")
                .replacingOccurrences(of: "]", with: "%5D")
                
            guard let url = URL(string: encodedQuery) else { continue }
            
            var request = URLRequest(url: url)
            request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
            request.addValue(appToken, forHTTPHeaderField: "App-Token")
            request.timeoutInterval = 15
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let decoded = try JSONDecoder().decode(TicketListResponse.self, from: data)
                if let dataArray = decoded.data {
                    let mapped = dataArray.compactMap { item -> Asset? in
                        let name = item["1"]?.value as? String ?? "Equipamento"
                        let tag = item["2"]?.value as? String ?? "TAG-\(item["2"]?.value ?? "")"
                        
                        let assetType: AssetType
                        switch type {
                        case "Computer": assetType = .computer
                        case "Monitor": assetType = .monitor
                        case "Printer": assetType = .printer
                        case "NetworkEquipment": assetType = .network
                        default: assetType = .network
                        }
                        
                        // Parse status, owner, department, serial
                        let status = parseAssetFieldForDevice(item["31"]?.value) ?? "Nenhum"
                        let rawOwner = parseAssetFieldForDevice(item["70"]?.value)
                        let owner = rawOwner?.replacingOccurrences(of: ".", with: " ")
                        let department = parseAssetFieldForDevice(item["3"]?.value)
                        let serial = parseAssetFieldForDevice(item["5"]?.value) ?? ""
                        let realId = Int(String(describing: item["2"]?.value ?? "0")) ?? 0
                        
                        return Asset(realId: realId, name: name, tag: tag, icon: assetType.rawValue, type: assetType, status: status, owner: owner, department: department, serialNumber: serial)
                    }
                    allAssets.append(contentsOf: mapped)
                }
            } catch {
                print("Erro ao obter dispositivos para \(type): \(error)")
            }
        }
        return allAssets
    }
    
    private func parseAssetFieldForDevice(_ value: Sendable?) -> String? {
        guard let value = value else { return nil }
        if let str = value as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.lowercased() == "null" || trimmed == "0" {
                return nil
            }
            return trimmed
        }
        if let dict = value as? [String: AnyCodable] {
            return dict["name"]?.value as? String
        }
        if let intVal = value as? Int {
            if intVal == 0 { return nil }
            return String(intVal)
        }
        return nil
    }
    
    /// Obtém o email e o perfil ativo do utilizador a partir da API do GLPI
    func fetchUserProfileDetails(userId: Int) async throws -> (email: String, profile: String) {
        if PreferenceManager.shared.isOfflineMode {
            return ("goncalo@glpi.com", "ADMINISTRADOR")
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let query = "criteria[0][field]=2&criteria[0][searchtype]=equals&criteria[0][value]=\(userId)&forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=5&forcedisplay[3]=20&forcedisplay[4]=80&expand_dropdowns=true"
        let encodedQuery = query.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D").replacingOccurrences(of: " ", with: "%20")
        let urlString = "\(cleanBaseURL)/apirest.php/search/User?\(encodedQuery)"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw URLError(.userAuthenticationRequired)
        }
        
        let searchResponse = try JSONDecoder().decode(TicketListResponse.self, from: data)
        if let firstUser = searchResponse.data?.first {
            let emailRaw = firstUser["5"]?.stringValue ?? ""
            let email = (emailRaw.isEmpty || emailRaw == "sem@email.pt" || emailRaw == "null") ? "Nenhum e-mail associado" : emailRaw
            
            // Perfil
            let rawProfile = firstUser["20"]?.stringValue ?? ""
            let cleanProfile = formatListString(rawProfile)
            let normalizedProfile = normalizeProfileString(cleanProfile)
            
            return (email, normalizedProfile)
        }
        
        throw NSError(domain: "UserNotFound", code: 404, userInfo: nil)
    }
    
    // Cache local do mapa de perfis (ID -> Nome)
    private var cachedProfileMap: [String: String] = [:]
    
    /// Obtém o mapa de perfis do GLPI (ID numérico -> nome real)
    /// Idêntico ao que o Android faz via glpiprofiles na sessão
    func fetchProfileMap() async -> [String: String] {
        if !cachedProfileMap.isEmpty { return cachedProfileMap }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Profile?range=0-100"
        
        guard let url = URL(string: urlString) else { return [:] }
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.timeoutInterval = 10
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var map: [String: String] = [:]
                for item in json {
                    if let id = item["id"] as? Int,
                       let name = item["name"] as? String,
                       !name.isEmpty {
                        map[String(id)] = name
                    }
                }
                if !map.isEmpty {
                    cachedProfileMap = map
                    return map
                }
            }
        } catch {
            print("[GLPIClient] Erro ao carregar mapa de perfis: \(error)")
        }
        return [:]
    }
    
    func fetchAllUsers() async throws -> [GLPIUser] {
        if PreferenceManager.shared.isOfflineMode {
            return [
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
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        // Idêntico ao Android:
        // forcedisplay[0]=1 (nome), forcedisplay[1]=2 (ID), forcedisplay[2]=20 (perfil), forcedisplay[3]=5 (email)
        // expand_dropdowns=true -> campo 20 devolve o nome do perfil em texto, não o ID numérico
        let query = "forcedisplay%5B0%5D=1&forcedisplay%5B1%5D=2&forcedisplay%5B2%5D=20&forcedisplay%5B3%5D=5&expand_dropdowns=true&range=0-9999"
        let urlString = "\(cleanBaseURL)/apirest.php/search/User?\(query)"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.timeoutInterval = 20
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw URLError(.userAuthenticationRequired)
        }
        
        // Parse manual do JSON para máxima robustez (evitar falhas de AnyCodable)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            // Fallback: tentar com o decoder normal
            let searchResponse = try JSONDecoder().decode(TicketListResponse.self, from: data)
            return processUserData(searchResponse.data ?? [])
        }
        
        // Nomes de utilizadores sistema a excluir (igual ao Android)
        let systemUsers: Set<String> = ["glpi", "tech", "normal", "post-only"]
        
        var fetchedUsers: [GLPIUser] = []
        
        for item in dataArray {
            // Extrair nome (campo 1) - robusto para qualquer tipo JSON
            let nameRaw = extractString(from: item["1"])
            guard !nameRaw.isEmpty else { continue }
            
            // Filtrar utilizadores do sistema (igual ao Android)
            let nameLower = nameRaw.lowercased()
            if systemUsers.contains(nameLower) { continue }
            
            // Formatar nome: "joao.silva" -> "Joao Silva"
            let formattedName = nameRaw.split(separator: ".")
                .map { word -> String in
                    let w = String(word)
                    return w.prefix(1).uppercased() + w.dropFirst().lowercased()
                }
                .joined(separator: " ")
            
            // Extrair email (campo 5)
            let emailRaw = extractString(from: item["5"])
            let email = (emailRaw.isEmpty || emailRaw.lowercased() == "null" || emailRaw == "sem@email.pt")
                ? "Nenhum e-mail associado"
                : emailRaw
            
            // Extrair perfil (campo 20) - com expand_dropdowns=true já é texto
            // GLPI pode devolver lista de perfis: "Super-Admin, Admin, Observer"
            let profileRaw = extractString(from: item["20"])
            let profileListCleaned = cleanBrackets(profileRaw) // Lista completa sem colchetes
            
            // Perfil principal = primeiro da lista (para exibição)
            let firstProfile = profileListCleaned.contains(",")
                ? (profileListCleaned.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? profileListCleaned)
                : profileListCleaned
            let normalizedProfile = normalizeProfileString(
                firstProfile.isEmpty || firstProfile == "null" ? "Observer" : firstProfile
            )
            
            fetchedUsers.append(GLPIUser(
                name: formattedName,
                email: email,
                profile: normalizedProfile,
                rawProfileList: profileListCleaned // lista bruta para filtros (igual ao Android)
            ))
        }
        
        return fetchedUsers
    }
    
    /// Extrai String de qualquer valor JSON (String, Int, Double, Bool, null, Array)
    private func extractString(from value: Any?) -> String {
        guard let value = value else { return "" }
        if let str = value as? String { return str == "null" ? "" : str }
        if let num = value as? Int { return String(num) }
        if let num = value as? Double { return String(Int(num)) }
        if let dict = value as? [String: Any] {
            // Algumas versões do GLPI devolvem {"rendered": "texto"}
            return extractString(from: dict["rendered"] ?? dict["name"] ?? dict["completename"])
        }
        if let array = value as? [Any] {
            // Se for uma lista de perfis, juntar com vírgula
            let mapped = array.map { extractString(from: $0) }.filter { !$0.isEmpty }
            return mapped.joined(separator: ", ")
        }
        return ""
    }
    
    /// Processa dados usando o decoder AnyCodable (fallback)
    private func processUserData(_ rawData: [[String: AnyCodable]]) -> [GLPIUser] {
        let systemUsers: Set<String> = ["glpi", "tech", "normal", "post-only"]
        var result: [GLPIUser] = []
        for item in rawData {
            let nameRaw = item["1"]?.value as? String ?? ""
            guard !nameRaw.isEmpty, !systemUsers.contains(nameRaw.lowercased()) else { continue }
            let formattedName = nameRaw.split(separator: ".")
                .map { String($0).prefix(1).uppercased() + String($0).dropFirst().lowercased() }
                .joined(separator: " ")
            let emailRaw = extractString(from: item["5"]?.value)
            let email = (emailRaw.isEmpty || emailRaw == "null") ? "Nenhum e-mail associado" : emailRaw
            let profileRawFull = cleanBrackets(extractString(from: item["20"]?.value))
            let firstProfile = profileRawFull.contains(",")
                ? (profileRawFull.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? profileRawFull)
                : profileRawFull
            let profile = normalizeProfileString(firstProfile.isEmpty ? "Observer" : firstProfile)
            result.append(GLPIUser(name: formattedName, email: email, profile: profile, rawProfileList: profileRawFull))
        }
        return result
    }
    
    /// Remove apenas os colchetes, mantendo a lista completa de perfis
    private func cleanBrackets(_ input: String) -> String {
        var clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("[") && clean.hasSuffix("]") {
            clean = String(clean.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return clean
    }
    
    private func formatListString(_ input: String) -> String {
        var clean = cleanBrackets(input)
        if clean.contains(",") {
            clean = clean.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? clean
        }
        return clean
    }
    
    func normalizeProfileString(_ profile: String) -> String {
        let trimmed = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        // Mapeamento por correspondência de texto (sem IDs hardcoded)
        if lower.contains("super-admin") || lower.contains("super admin") || lower.contains("superadmin") ||
           lower.contains("super-administrador") || lower.contains("super-administrateur") {
            return "Super-Admin"
        }
        if lower.contains("admin") || lower.contains("administrador") || lower.contains("administrateur") {
            return "Admin"
        }
        if lower.contains("tecnic") || lower.contains("técnic") || lower.contains("technic") {
            return "Technician"
        }
        if lower.contains("supervis") {
            return "Supervisor"
        }
        if lower.contains("hotlin") {
            return "Hotliner"
        }
        if lower.contains("observ") {
            return "Observer"
        }
        if lower.contains("leitura") || lower.contains("read") || lower.contains("only") || lower.contains("lecture") {
            return "Read-Only"
        }
        // Se for número puro (ID não finalizado), retornar como está para exibir o que vier
        // O profileMap deve ter finalizado antes de chegar aqui
        return trimmed
    }
    
    /// Obtém a lista de localizações do GLPI
    func getLocations() async throws -> [(id: String, name: String)] {
        if PreferenceManager.shared.isOfflineMode {
            return [
                ("1", "Biblioteca"),
                ("2", "Casa do Conhecimento"),
                ("3", "DAEF"),
                ("4", "DAF"),
                ("5", "DAO"),
                ("6", "DAS"),
                ("7", "DE"),
                ("8", "DJ"),
                ("9", "DOT"),
                ("10", "DPO"),
                ("11", "DPS"),
                ("12", "  ↳ Ação Social"),
                ("13", "  ↳ Complexo Lazer V. Verde"),
                ("14", "  ↳ CPCJ"),
                ("15", "  ↳ GIF"),
                ("16", "  ↳ Loja Social"),
                ("17", "  ↳ Piscinas de Prado"),
                ("18", "  ↳ SQIP"),
                ("19", "DRH"),
                ("20", "DSI"),
                ("21", "  ↳ Arquivo"),
                ("22", "  ↳ Sala Bastidores"),
                ("23", "  ↳ Arrumos Informática"),
                ("24", "DUE"),
                ("25", "EC Prado"),
                ("26", "EXE"),
                ("27", "  ↳ GRP"),
                ("28", "Stock"),
                ("29", "  ↳ Red Tagged"),
                ("30", "UCP"),
                ("31", "UCT"),
                ("32", "UIC"),
                ("33", "  ↳ Casa do Conhecimento"),
                ("34", "UMAQ")
            ]
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Location?range=0-300"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        var results: [(id: String, name: String)] = []
        if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for item in jsonArray {
                let id = String(describing: item["id"] ?? "")
                let name = item["name"] as? String ?? ""
                if !id.isEmpty && !name.isEmpty {
                    results.append((id: id, name: name))
                }
            }
        }
        return results
    }

    /// Obtém a lista de estados do GLPI
    func getStates() async throws -> [(id: String, name: String)] {
        if PreferenceManager.shared.isOfflineMode {
            return [
                ("1", "Avariado"),
                ("2", "Informado"),
                ("3", "Novo"),
                ("4", "Usado"),
                ("5", "Vigor")
            ]
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/State?range=0-100"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        var results: [(id: String, name: String)] = []
        if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for item in jsonArray {
                let id = String(describing: item["id"] ?? "")
                let name = item["name"] as? String ?? ""
                if !id.isEmpty && !name.isEmpty {
                    results.append((id: id, name: name))
                }
            }
        }
        return results
    }

    /// Verifica se um valor (nome ou SN) já existe no inventário do GLPI
    func checkDuplicateGlobal(value: String, field: Int) async throws -> Bool {
        if PreferenceManager.shared.isOfflineMode {
            let mocks = ["MacBook Pro M3", "Monitor LG UltraFine", "Switch Aruba 48 Portas", "SN-MAC-001", "SN-LG-5542", "SN-ARUBA-112"]
            return mocks.contains { $0.localizedCaseInsensitiveContains(value) }
        }
        
        let types = ["Computer", "Monitor", "NetworkEquipment", "Printer", "Peripheral"]
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let valEncoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        for type in types {
            let urlString = "\(cleanBaseURL)/apirest.php/search/\(type)?" +
                "criteria[0][field]=\(field)&criteria[0][searchtype]=equals&criteria[0][value]=\(valEncoded)" +
                "&range=0-1"
                
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
            request.addValue(appToken, forHTTPHeaderField: "App-Token")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let totalCount = json["totalcount"] as? Int {
                    if totalCount > 0 {
                        return true
                    }
                }
            } catch {
                continue
            }
        }
        return false
    }

    /// Cria um novo dispositivo no GLPI
    func addDevice(itemtype: String, input: [String: Any]) async throws -> Int? {
        if PreferenceManager.shared.isOfflineMode {
            return Int.random(in: 1000...9999)
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/\(itemtype)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body = ["input": input]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = jsonArray.first,
               let id = first["id"] as? Int {
                return id
            } else if let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let id = jsonDict["id"] as? Int {
                return id
            }
        }
        return nil
    }

    /// Atualiza um dispositivo existente no GLPI
    func updateDevice(itemtype: String, id: Int, input: [String: Any]) async throws -> Bool {
        if PreferenceManager.shared.isOfflineMode {
            return true
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/\(itemtype)/\(id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let body = ["input": input]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        return false
    }

    /// Pesquisa um item por número de série e retorna seus dados (Nome, Localização, etc.)
    func searchBySerialWithLocation(itemtype: String, serial: String) async throws -> [String: Any]? {
        if PreferenceManager.shared.isOfflineMode {
            let mockData: [[String: AnyCodable]] = [
                ["2": AnyCodable("1"), "1": AnyCodable("MacBook Pro M3"), "3": AnyCodable("DSI"), "5": AnyCodable("SN-MAC-001"), "70": AnyCodable("Gonçalo Sousa"), "31": AnyCodable("Novo")],
                ["2": AnyCodable("2"), "1": AnyCodable("Monitor LG UltraFine"), "3": AnyCodable("UCP"), "5": AnyCodable("SN-LG-5542"), "70": AnyCodable("Maria Silva"), "31": AnyCodable("Vigor")],
                ["2": AnyCodable("3"), "1": AnyCodable("Impressora HP Laser"), "3": AnyCodable("DAF"), "5": AnyCodable("SN-HP-9921"), "70": AnyCodable("João Mendes"), "31": AnyCodable("Avariado")],
                ["2": AnyCodable("4"), "1": AnyCodable("Switch Aruba 48 Portas"), "3": AnyCodable("Sala Bastidores"), "5": AnyCodable("SN-ARUBA-112"), "70": AnyCodable("Pedro Alves"), "31": AnyCodable("Vigor")],
                ["2": AnyCodable("5"), "1": AnyCodable("MacBook Air M2"), "3": AnyCodable("Biblioteca"), "5": AnyCodable("SN-MAC-002"), "70": AnyCodable("Ana Martins"), "31": AnyCodable("Usado")],
                ["2": AnyCodable("6"), "1": AnyCodable("Impressora Brother L5"), "3": AnyCodable("DAO"), "5": AnyCodable("SN-BROTHER-332"), "70": AnyCodable("Sofia Martins"), "31": AnyCodable("Vigor")],
                ["2": AnyCodable("7"), "1": AnyCodable("Monitor LG UltraFine"), "3": AnyCodable("Design"), "5": AnyCodable("SN-LG-5543"), "70": AnyCodable("Ana Martins"), "31": AnyCodable("Vigor")],
                ["2": AnyCodable("8"), "1": AnyCodable("Switch Aruba 48 Portas"), "3": AnyCodable("Sala Bastidores"), "5": AnyCodable("SN-ARUBA-113"), "70": AnyCodable("DSI"), "31": AnyCodable("Vigor")]
            ]
            
            if let matched = mockData.first(where: { ($0["5"]?.value as? String ?? "").localizedCaseInsensitiveCompare(serial) == .orderedSame }) {
                var result: [String: Any] = [:]
                for (key, val) in matched {
                    result[key] = val.value
                }
                return result
            }
            return nil
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let serEncoded = serial.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(cleanBaseURL)/apirest.php/search/\(itemtype)?" +
            "criteria[0][field]=5&criteria[0][searchtype]=equals&criteria[0][value]=\(serEncoded)" +
            "&forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=3&forcedisplay[3]=4" +
            "&forcedisplay[4]=5&forcedisplay[5]=31&forcedisplay[6]=80" +
            "&range=0-1"
            
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataArray = json["data"] as? [[String: Any]],
           let firstItem = dataArray.first {
            return firstItem
        }
        return nil
    }

    /// Obtém todos os números de série válidos no sistema de inventário
    func loadAllSerialNumbers() async throws -> [String] {
        if PreferenceManager.shared.isOfflineMode {
            return ["SN-MAC-001", "SN-LG-5542", "SN-HP-9921", "SN-ARUBA-112", "SN-MAC-002", "SN-BROTHER-332", "SN-LG-5543", "SN-ARUBA-113"]
        }
        
        let types = ["Computer", "Monitor", "NetworkEquipment", "Printer"]
        var serials: Set<String> = []
        
        await withThrowingTaskGroup(of: [String].self) { group in
            for type in types {
                group.addTask {
                    let response = try await self.searchInventory(itemtype: type, range: "0-200", searchText: "")
                    var res: [String] = []
                    if let data = response.data {
                        for item in data {
                            if let serialAny = item["5"]?.value,
                               let serialStr = serialAny as? String {
                                let trimmed = serialStr.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty && trimmed.lowercased() != "null" {
                                    res.append(trimmed)
                                }
                            }
                        }
                    }
                    return res
                }
            }
            
            do {
                for try await list in group {
                    for s in list {
                        serials.insert(s)
                    }
                }
            } catch {
                print("Erro ao carregar seriais: \(error)")
            }
        }
        
        return Array(serials).sorted()
    }
    
    // MARK: - Métodos de Reservas
    
    func getAllReservationItems(range: String) async throws -> [[String: Any]] {
        if PreferenceManager.shared.isOfflineMode {
            // Mock items representing reservation items
            return [
                ["id": 1, "itemtype": "Computer", "items_id": 1, "is_active": true],
                ["id": 2, "itemtype": "NetworkEquipment", "items_id": 5, "is_active": true],
                ["id": 3, "itemtype": "Computer", "items_id": 6, "is_active": true],
                ["id": 4, "itemtype": "Monitor", "items_id": 2, "is_active": true],
                ["id": 5, "itemtype": "Printer", "items_id": 4, "is_active": true]
            ]
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/ReservationItem?range=\(range)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return jsonArray
        }
        return []
    }
    
    func getGenericItem(itemtype: String, id: Int) async throws -> [String: Any] {
        if PreferenceManager.shared.isOfflineMode {
            // Return mock device info based on id/itemtype
            switch itemtype {
            case "Computer":
                if id == 1 {
                    return ["id": 1, "name": "MacBook Air M2", "serial": "MBA-9102", "is_deleted": false]
                } else {
                    return ["id": id, "name": "MacBook Air M2 (V2)", "serial": "MBA-9103", "is_deleted": false]
                }
            case "NetworkEquipment":
                return ["id": id, "name": "Projector Epson X41", "serial": "EP-4412", "is_deleted": false]
            case "Monitor":
                return ["id": id, "name": "Monitor Portátil ASUS", "serial": "AS-1122", "is_deleted": false]
            case "Printer":
                return ["id": id, "name": "Kit WebCam + Tripé", "serial": "WC-3344", "is_deleted": false]
            default:
                return ["id": id, "name": "Dispositivo \(id)", "serial": "SN-\(id)", "is_deleted": false]
            }
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/\(itemtype)/\(id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }
    
    func getReservationsForItem(resItemId: Int) async throws -> [[String: Any]] {
        if PreferenceManager.shared.isOfflineMode {
            // Mock reservations list
            let cal = Calendar.current
            let sdf = DateFormatter()
            sdf.dateFormat = "yyyy-MM-dd HH:mm:ss"
            sdf.timeZone = TimeZone(secondsFromGMT: 0)
            
            let twoDaysLaterBegin = cal.date(byAdding: .day, value: 2, to: Date())!
            let twoDaysLaterEnd = cal.date(byAdding: .hour, value: 4, to: twoDaysLaterBegin)!
            
            let fiveDaysLaterBegin = cal.date(byAdding: .day, value: 5, to: Date())!
            let fiveDaysLaterEnd = cal.date(byAdding: .hour, value: 3, to: fiveDaysLaterBegin)!
            
            if resItemId == 1 {
                return [
                    [
                        "id": 99901,
                        "begin": sdf.string(from: twoDaysLaterBegin),
                        "end": sdf.string(from: twoDaysLaterEnd),
                        "users_id": [7, "Maria Silva"],
                        "comment": "Necessário para inventário local."
                    ]
                ]
            } else if resItemId == 3 {
                return [
                    [
                        "id": 99902,
                        "begin": sdf.string(from: fiveDaysLaterBegin),
                        "end": sdf.string(from: fiveDaysLaterEnd),
                        "users_id": [8, "João Mendes"],
                        "comment": "Apresentação na sala de reuniões."
                    ]
                ]
            }
            return []
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/ReservationItem/\(resItemId)/Reservation?expand_dropdowns=true&range=0-100"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return jsonArray
        }
        return []
    }
    
    func createReservation(reservationItemsId: Int, begin: String, end: String, comment: String, userId: Int) async throws -> Bool {
        if PreferenceManager.shared.isOfflineMode {
            return true
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Reservation"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let input: [String: Any] = [
            "reservationitems_id": reservationItemsId,
            "begin": begin,
            "end": end,
            "comment": comment.isEmpty ? "Reserva efetuada via App GLPIMobile" : comment,
            "users_id": userId
        ]
        let body: [String: Any] = ["input": input]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200 || httpResponse.statusCode == 201
        }
        return false
    }
    
    func deleteReservation(id: Int) async throws -> Bool {
        if PreferenceManager.shared.isOfflineMode {
            return true
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Reservation/\(id)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200 || httpResponse.statusCode == 204
        }
        return false
    }
    
    // --- Network Ports API Support ---
    
    func getNetworkPortsSearch(range: String, assetType: String, assetId: Int) async throws -> [[String: Any]] {
        if PreferenceManager.shared.isOfflineMode {
            return [
                ["1": "Port 1", "2": 1, "3": "1", "39": "Computador Sala 3", "4": "00:11:22:33:44:55"],
                ["1": "Port 2", "2": 2, "3": "2", "39": "", "4": ""],
                ["1": "Port 3", "2": 3, "3": "3", "39": "AT02", "4": "00:aa:bb:cc:dd:ee"]
            ]
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/search/NetworkPort?range=\(range)&criteria[0][field]=20&criteria[0][searchtype]=equals&criteria[0][value]=\(assetType)&criteria[1][link]=AND&criteria[1][field]=21&criteria[1][searchtype]=equals&criteria[1][value]=\(assetId)&forcedisplay[0]=1&forcedisplay[1]=3&forcedisplay[2]=4&forcedisplay[3]=39&forcedisplay[4]=126&forcedisplay[5]=2&sort=3&order=ASC&expand_dropdowns=true"
        
        guard let url = URL(string: urlString.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let decoded = try? JSONDecoder().decode(TicketListResponse.self, from: data),
           let dataArray = decoded.data {
            var results: [[String: Any]] = []
            for item in dataArray {
                var map: [String: Any] = [:]
                for (k, v) in item {
                    map[k] = v.value
                }
                results.append(map)
            }
            return results
        }
        return []
    }
    
    func getPortConnection(searchField: Int, portId: String) async throws -> [[String: Any]] {
        if PreferenceManager.shared.isOfflineMode {
            return []
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/search/NetworkPort_NetworkPort?range=0-1&criteria[0][field]=\(searchField)&criteria[0][searchtype]=equals&criteria[0][value]=\(portId)&expand_dropdowns=true"
        
        guard let url = URL(string: urlString.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let decoded = try? JSONDecoder().decode(TicketListResponse.self, from: data),
           let dataArray = decoded.data {
            var results: [[String: Any]] = []
            for item in dataArray {
                var map: [String: Any] = [:]
                for (k, v) in item {
                    map[k] = v.value
                }
                results.append(map)
            }
            return results
        }
        return []
    }
    
    func getRemotePortDetails(remotePortId: String) async throws -> [[String: Any]] {
        if PreferenceManager.shared.isOfflineMode {
            return []
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/search/NetworkPort?range=0-1&criteria[0][field]=2&criteria[0][searchtype]=equals&criteria[0][value]=\(remotePortId)&forcedisplay[0]=20&forcedisplay[1]=21&forcedisplay[2]=4&forcedisplay[3]=126&expand_dropdowns=true"
        
        guard let url = URL(string: urlString.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let decoded = try? JSONDecoder().decode(TicketListResponse.self, from: data),
           let dataArray = decoded.data {
            var results: [[String: Any]] = []
            for item in dataArray {
                var map: [String: Any] = [:]
                for (k, v) in item {
                    map[k] = v.value
                }
                results.append(map)
            }
            return results
        }
        return []
    }
    
    func getDeviceById(itemtype: String, id: String) async throws -> [String: Any] {
        if PreferenceManager.shared.isOfflineMode {
            return ["name": "AT-Device-Mock"]
        }
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/\(itemtype)/\(id)"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }
}



