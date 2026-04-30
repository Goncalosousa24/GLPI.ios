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
            return 32 // Outros (ex: Resolvidos no Mês)
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
    
    func getCountResolvidosGlobalCurrentMonth() async throws -> Int {
        let dataLimite = getStartOfMonth()
        
        // Replica exata da estrutura de sub-critérios do Android
        let query = [
            "criteria[0][criteria][0][field]=12&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=5",
            "criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=12&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=6",
            "criteria[1][link]=AND&criteria[1][field]=17&criteria[1][searchtype]=morethan&criteria[1][value]=\(dataLimite)"
        ].joined(separator: "&")
        
        return try await performSearch(query: query)
    }
    
    func getCountResolvidosMyCurrentMonth(userId: Int) async throws -> Int {
        let dataLimite = getStartOfMonth()
        
        // Replica exata da estrutura de sub-critérios do Android (Vista Pessoal)
        let query = [
            "criteria[0][criteria][0][field]=12&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=5",
            "criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=12&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=6",
            "criteria[1][link]=AND&criteria[1][field]=17&criteria[1][searchtype]=morethan&criteria[1][value]=\(dataLimite)",
            "criteria[2][link]=AND&criteria[2][criteria][0][field]=4&criteria[2][criteria][0][searchtype]=equals&criteria[2][criteria][0][value]=\(userId)",
            "criteria[2][criteria][1][link]=OR&criteria[2][criteria][1][field]=5&criteria[2][criteria][1][searchtype]=equals&criteria[2][criteria][1][value]=\(userId)"
        ].joined(separator: "&")
        
        return try await performSearch(query: query)
    }
    
    /// Obtém a LISTA de tickets resolvidos (Paridade Android - Ficheiro Separado)
    func getTicketsResolvidos(userId: Int? = nil, range: String) async throws -> ([GLPITicket], Int) {
        let dataLimite = getStartOfMonth()
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        // Query complexa idêntica ao Android
        var queryParts = [
            "criteria[0][criteria][0][field]=12&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=5",
            "criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=12&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=6",
            "criteria[1][link]=AND&criteria[1][field]=17&criteria[1][searchtype]=morethan&criteria[1][value]=\(dataLimite)"
        ]
        
        if let uid = userId {
            queryParts.append("criteria[2][link]=AND&criteria[2][criteria][0][field]=4&criteria[2][criteria][0][searchtype]=equals&criteria[2][criteria][0][value]=\(uid)")
            queryParts.append("criteria[2][criteria][1][link]=OR&criteria[2][criteria][1][field]=5&criteria[2][criteria][1][searchtype]=equals&criteria[2][criteria][1][value]=\(uid)")
        }
        
        let query = queryParts.joined(separator: "&") +
            "&forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=12&forcedisplay[3]=15&forcedisplay[4]=19&forcedisplay[5]=4&forcedisplay[6]=5&forcedisplay[7]=17&forcedisplay[8]=3" +
            "&sort=19&order=DESC&expand_dropdowns=true&range=\(range)"
        
        let encodedQuery = query
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
            .replacingOccurrences(of: " ", with: "%20")
        
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(encodedQuery)"
        
        guard let url = URL(string: fullURLString) else { throw URLError(.badURL) }
        
        if PreferenceManager.shared.isOfflineMode {
            // Mock de tickets resolvidos
            let mockTickets = [
                GLPITicket(id: "201", name: "Monitor substituído", requester: "Alice", assignedTo: "Eu", description: "Feito", date: Date(), priority: .medium, status: .resolved, isMine: true, isAssignedToMe: true),
                GLPITicket(id: "202", name: "Teclado trocado", requester: "Bob", assignedTo: "Eu", description: "Feito", date: Date(), priority: .low, status: .resolved, isMine: true, isAssignedToMe: true)
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
    
    private func getPrioritariosQuery(userId: Int? = nil) -> String {
        var queryParts = [
            // Status 1,2,3,4,5
            "criteria[0][criteria][0][field]=12&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=1",
            "criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=12&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=2",
            "criteria[0][criteria][2][link]=OR&criteria[0][criteria][2][field]=12&criteria[0][criteria][2][searchtype]=equals&criteria[0][criteria][2][value]=3",
            "criteria[0][criteria][3][link]=OR&criteria[0][criteria][3][field]=12&criteria[0][criteria][3][searchtype]=equals&criteria[0][criteria][3][value]=4",
            "criteria[0][criteria][4][link]=OR&criteria[0][criteria][4][field]=12&criteria[0][criteria][4][searchtype]=equals&criteria[0][criteria][4][value]=5",
            
            // Prioridade 4,5,6
            "criteria[1][link]=AND&criteria[1][criteria][0][field]=3&criteria[1][criteria][0][searchtype]=equals&criteria[1][criteria][0][value]=4",
            "criteria[1][criteria][1][link]=OR&criteria[1][criteria][1][field]=3&criteria[1][criteria][1][searchtype]=equals&criteria[1][criteria][1][value]=5",
            "criteria[1][criteria][2][link]=OR&criteria[1][criteria][2][field]=3&criteria[1][criteria][2][searchtype]=equals&criteria[1][criteria][2][value]=6"
        ]
        
        if let uid = userId {
            queryParts.append("criteria[2][link]=AND&criteria[2][criteria][0][field]=4&criteria[2][criteria][0][searchtype]=equals&criteria[2][criteria][0][value]=\(uid)")
            queryParts.append("criteria[2][criteria][1][link]=OR&criteria[2][criteria][1][field]=5&criteria[2][criteria][1][searchtype]=equals&criteria[2][criteria][1][value]=\(uid)")
        }
        
        return queryParts.joined(separator: "&")
    }
    
    func getCountPrioritariosGlobal() async throws -> Int {
        return try await performSearch(query: getPrioritariosQuery())
    }
    
    func getCountPrioritariosMeus(userId: Int) async throws -> Int {
        return try await performSearch(query: getPrioritariosQuery(userId: userId))
    }
    
    func getTicketsPrioritarios(userId: Int? = nil, range: String) async throws -> ([GLPITicket], Int) {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let query = getPrioritariosQuery(userId: userId) + "&range=\(range)&expand_dropdowns=true&forcedisplay[0]=1&forcedisplay[1]=2&forcedisplay[2]=12&forcedisplay[3]=15&forcedisplay[4]=19&forcedisplay[5]=4&forcedisplay[6]=5&forcedisplay[8]=3&sort=19&order=DESC"
        
        let encodedQuery = query.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D").replacingOccurrences(of: " ", with: "%20")
        let fullURLString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(encodedQuery)"
        
        guard let url = URL(string: fullURLString) else { throw URLError(.badURL) }
        if PreferenceManager.shared.isOfflineMode {
            // Mock de tickets prioritários
            let mockTickets = [
                GLPITicket(id: "301", name: "Servidor Down", requester: "Admin", assignedTo: "Pendente", description: "Urgente", date: Date(), priority: .major, status: .new, isMine: false, isAssignedToMe: false)
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
}
