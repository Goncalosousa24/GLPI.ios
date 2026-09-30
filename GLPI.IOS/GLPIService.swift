//
//  GLPIService.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 29/04/2026.
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
        let glpiStatuses: [Int] = [1, 2, 3, 4, 5]
        let monthlyStart = Date().firstDayOfMonth()
        
        let publishers = glpiStatuses.map { glpiValue in
            self.searchCount(itemType: "Ticket", statusValue: glpiValue, startDate: glpiValue == 5 ? monthlyStart : nil, userId: userId)
                .map { (glpiValue, $0) }
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { pairs in
                var dict: [TicketStatus: Int] = [
                    .new: 0,
                    .assigned: 0,
                    .planned: 0,
                    .waiting: 0,
                    .resolved: 0,
                    .deleted: 0
                ]
                var inProgressCount = 0
                
                for (glpiValue, count) in pairs {
                    switch glpiValue {
                    case 1:
                        dict[.new] = count
                    case 2:
                        inProgressCount += count
                        dict[.assigned] = count
                    case 3:
                        inProgressCount += count
                        dict[.planned] = count
                    case 4:
                        inProgressCount += count
                        dict[.waiting] = count
                    case 5:
                        dict[.resolved] = count
                    default:
                        break
                    }
                }
                
                // O card "EM PROGRESSO" no dashboard agrega os status 2+3+4
                dict[.assigned] = inProgressCount
                dict[.deleted] = 0
                return dict
            }
            .eraseToAnyPublisher()
    }
    
    /// Valida a sessão completa e extrai os dados do utilizador logado
    func getFullSession() -> AnyPublisher<Bool, Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: "\(cleanBaseURL)/apirest.php/getFullSession") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return sessionRequest(url: url)
            .map { (responseDict: [String: AnyCodable]) -> Bool in
                guard let sessionCodable = responseDict["session"],
                      let sessionMap = sessionCodable.value as? [String: AnyCodable] else {
                    return true
                }
                
                // Extrair ID do utilizador logado
                var sessionRealId = 0
                let possibleIdKeys = ["glpiID", "glpi_id", "id", "users_id"]
                for key in possibleIdKeys {
                    if let val = sessionMap[key]?.value {
                        if let intVal = val as? Int {
                            sessionRealId = intVal
                            break
                        } else if let doubleVal = val as? Double {
                            sessionRealId = Int(doubleVal)
                            break
                        } else if let strVal = val as? String, let intVal = Int(strVal) {
                            sessionRealId = intVal
                            break
                        }
                    }
                }
                
                if sessionRealId == 0 {
                    // Tentar extrair do glpiactiveprofile -> users_id
                    if let profileCodable = sessionMap["glpiactiveprofile"],
                       let profileMap = profileCodable.value as? [String: AnyCodable],
                       let uidVal = profileMap["users_id"]?.value {
                        if let intVal = uidVal as? Int {
                            sessionRealId = intVal
                        } else if let doubleVal = uidVal as? Double {
                            sessionRealId = Int(doubleVal)
                        } else if let strVal = uidVal as? String, let intVal = Int(strVal) {
                            sessionRealId = intVal
                        }
                    }
                }
                
                if sessionRealId > 0 {
                    PreferenceManager.shared.userId = sessionRealId
                    print("getFullSession: ID do utilizador atualizado com sucesso: \(sessionRealId)")
                }
                
                // Extrair nome
                if let glpiName = sessionMap["glpiname"]?.value as? String {
                    PreferenceManager.shared.userName = glpiName
                }
                
                let firstName = sessionMap["glpifirstname"]?.value as? String ?? ""
                let realName = sessionMap["glpirealname"]?.value as? String ?? ""
                let fullName = "\(firstName) \(realName)".trimmingCharacters(in: .whitespacesAndNewlines)
                if !fullName.isEmpty {
                    PreferenceManager.shared.userDisplayName = fullName
                }
                
                // Extrair perfil ativo
                if let profileCodable = sessionMap["glpiactiveprofile"],
                   let profileMap = profileCodable.value as? [String: AnyCodable],
                   let profileName = profileMap["name"]?.value as? String {
                    PreferenceManager.shared.userProfile = profileName
                }
                
                return true
            }
            .eraseToAnyPublisher()
    }
    
    /// Procura tickets por status com paginação
    func fetchTickets(status: TicketStatus? = nil, statusValue: Int? = nil, statusQueryString: String? = nil, range: String = "0-50", startDate: String? = nil, userId: Int? = nil, isRequesterOnly: Bool = false, isAssignedOnly: Bool = false, order: String = "DESC", searchQuery: String? = nil, isDeleted: Bool = false) -> AnyPublisher<([GLPITicket], Int), Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var queryParts: [String] = []
        
        func buildSearchQueryParts(for queryStr: String, criteriaIndex: Int) -> [String] {
            var parts: [String] = []
            let idx = criteriaIndex
            let linkPrefix = idx > 0 ? "criteria[\(idx)][link]=AND&" : ""
            
            let isNumeric = queryStr.allSatisfy { $0.isNumber }
            if isNumeric {
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=2&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=\(queryStr)")
            } else {
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=1&criteria[\(idx)][criteria][0][searchtype]=contains&criteria[\(idx)][criteria][0][value]=\(queryStr)")
                parts.append("criteria[\(idx)][criteria][1][link]=OR&criteria[\(idx)][criteria][1][field]=2&criteria[\(idx)][criteria][1][searchtype]=equals&criteria[\(idx)][criteria][1][value]=\(queryStr)")
            }
            return parts
        }
        
        func buildStatusQueryParts(for statusStr: String, criteriaIndex: Int) -> [String] {
            var parts: [String] = []
            let idx = criteriaIndex
            let linkPrefix = idx > 0 ? "criteria[\(idx)][link]=AND&" : ""
            
            switch statusStr.lowercased() {
            case "novo":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=1")
            case "a processar (atribuído)":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=2")
            case "a processar (planeado)":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=3")
            case "aguardando":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=4")
            case "finalizado":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=5")
            case "encerrado":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=6")
            case "não finalizado":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=1")
                parts.append("criteria[\(idx)][criteria][1][link]=OR&criteria[\(idx)][criteria][1][field]=12&criteria[\(idx)][criteria][1][searchtype]=equals&criteria[\(idx)][criteria][1][value]=2")
                parts.append("criteria[\(idx)][criteria][2][link]=OR&criteria[\(idx)][criteria][2][field]=12&criteria[\(idx)][criteria][2][searchtype]=equals&criteria[\(idx)][criteria][2][value]=3")
                parts.append("criteria[\(idx)][criteria][3][link]=OR&criteria[\(idx)][criteria][3][field]=12&criteria[\(idx)][criteria][3][searchtype]=equals&criteria[\(idx)][criteria][3][value]=4")
            case "não encerrado":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=1")
                parts.append("criteria[\(idx)][criteria][1][link]=OR&criteria[\(idx)][criteria][1][field]=12&criteria[\(idx)][criteria][1][searchtype]=equals&criteria[\(idx)][criteria][1][value]=2")
                parts.append("criteria[\(idx)][criteria][2][link]=OR&criteria[\(idx)][criteria][2][field]=12&criteria[\(idx)][criteria][2][searchtype]=equals&criteria[\(idx)][criteria][2][value]=3")
                parts.append("criteria[\(idx)][criteria][3][link]=OR&criteria[\(idx)][criteria][3][field]=12&criteria[\(idx)][criteria][3][searchtype]=equals&criteria[\(idx)][criteria][3][value]=4")
                parts.append("criteria[\(idx)][criteria][4][link]=OR&criteria[\(idx)][criteria][4][field]=12&criteria[\(idx)][criteria][4][searchtype]=equals&criteria[\(idx)][criteria][4][value]=5")
            case "a processar":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=2")
                parts.append("criteria[\(idx)][criteria][1][link]=OR&criteria[\(idx)][criteria][1][field]=12&criteria[\(idx)][criteria][1][searchtype]=equals&criteria[\(idx)][criteria][1][value]=3")
            case "finalizado + encerrado":
                parts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=5")
                parts.append("criteria[\(idx)][criteria][1][link]=OR&criteria[\(idx)][criteria][1][field]=12&criteria[\(idx)][criteria][1][searchtype]=equals&criteria[\(idx)][criteria][1][value]=6")
            default:
                break
            }
            return parts
        }
        
        var criteriaIndex = 0
        
        if let uid = userId {
            let idx = criteriaIndex
            criteriaIndex += 1
            if isRequesterOnly {
                queryParts.append("criteria[\(idx)][criteria][0][field]=4&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=\(uid)")
            } else if isAssignedOnly {
                queryParts.append("criteria[\(idx)][criteria][0][field]=5&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=\(uid)")
            } else {
                queryParts.append("criteria[\(idx)][criteria][0][field]=4&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=\(uid)")
                queryParts.append("criteria[\(idx)][criteria][1][link]=OR&criteria[\(idx)][criteria][1][field]=5&criteria[\(idx)][criteria][1][searchtype]=equals&criteria[\(idx)][criteria][1][value]=\(uid)")
                queryParts.append("criteria[\(idx)][criteria][2][link]=OR&criteria[\(idx)][criteria][2][field]=22&criteria[\(idx)][criteria][2][searchtype]=equals&criteria[\(idx)][criteria][2][value]=\(uid)")
                queryParts.append("criteria[\(idx)][criteria][3][link]=OR&criteria[\(idx)][criteria][3][field]=6&criteria[\(idx)][criteria][3][searchtype]=equals&criteria[\(idx)][criteria][3][value]=\(uid)")
            }
        }
        
        var isResolvedOrClosed = false
        
        if let sqs = statusQueryString, !sqs.isEmpty, sqs.lowercased() != "todos" {
            let idx = criteriaIndex
            criteriaIndex += 1
            queryParts.append(contentsOf: buildStatusQueryParts(for: sqs, criteriaIndex: idx))
            let sqsLower = sqs.lowercased()
            isResolvedOrClosed = (sqsLower == "finalizado" || sqsLower == "encerrado" || sqsLower == "finalizado + encerrado")
        } else if let sv = statusValue {
            let idx = criteriaIndex
            criteriaIndex += 1
            let linkPrefix = idx > 0 ? "criteria[\(idx)][link]=AND&" : ""
            queryParts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=\(sv)")
            isResolvedOrClosed = (sv == 5 || sv == 6)
        } else if let s = status {
            let idx = criteriaIndex
            criteriaIndex += 1
            let linkPrefix = idx > 0 ? "criteria[\(idx)][link]=AND&" : ""
            if s == .assigned {
                // Dashboard "EM PROGRESSO" — agrega atribuído (2) + planeado (3) + aguardando (4)
                queryParts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=2")
                queryParts.append("criteria[\(idx)][criteria][1][link]=OR&criteria[\(idx)][criteria][1][field]=12&criteria[\(idx)][criteria][1][searchtype]=equals&criteria[\(idx)][criteria][1][value]=3")
                queryParts.append("criteria[\(idx)][criteria][2][link]=OR&criteria[\(idx)][criteria][2][field]=12&criteria[\(idx)][criteria][2][searchtype]=equals&criteria[\(idx)][criteria][2][value]=4")
            } else {
                let glpiValue: Int
                switch s {
                case .new: glpiValue = 1
                case .planned: glpiValue = 3
                case .resolved: glpiValue = 5
                case .deleted: glpiValue = 6
                case .waiting: glpiValue = 4
                default: glpiValue = 2
                }
                queryParts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=12&criteria[\(idx)][criteria][0][searchtype]=equals&criteria[\(idx)][criteria][0][value]=\(glpiValue)")
                isResolvedOrClosed = (s == .resolved || s == .deleted)
            }
        }
        
        if let sd = startDate {
            let idx = criteriaIndex
            criteriaIndex += 1
            let linkPrefix = idx > 0 ? "criteria[\(idx)][link]=AND&" : ""
            let dateField = isResolvedOrClosed ? 19 : 15
            queryParts.append("\(linkPrefix)criteria[\(idx)][criteria][0][field]=\(dateField)&criteria[\(idx)][criteria][0][searchtype]=morethan&criteria[\(idx)][criteria][0][value]=\(sd)")
        }
        
        if let query = searchQuery, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let idx = criteriaIndex
            criteriaIndex += 1
            queryParts.append(contentsOf: buildSearchQueryParts(for: query.trimmingCharacters(in: .whitespacesAndNewlines), criteriaIndex: idx))
        }
        
        let criteriaString = queryParts.joined(separator: "&")
        var urlString = "\(cleanBaseURL)/apirest.php/search/Ticket?range=\(range)&expand_dropdowns=true"
        if isDeleted {
            urlString += "&is_deleted=1"
        }
        if !criteriaString.isEmpty {
            urlString += "&\(criteriaString)"
        }
        
        // Campos forçados (Essenciais + Requerente + Prioridade + Descrição)
        var forcedisplayIndex = 0
        var forcedisplayString = ""
        
        forcedisplayString += "forcedisplay[\(forcedisplayIndex)]=1" // Title
        forcedisplayIndex += 1
        forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=2" // ID
        forcedisplayIndex += 1
        forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=12" // Status
        forcedisplayIndex += 1
        forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=15" // Date
        forcedisplayIndex += 1
        forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=19" // Date Mod
        forcedisplayIndex += 1
        forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=4" // Requester
        forcedisplayIndex += 1
        forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=3" // Priority
        forcedisplayIndex += 1
        forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=21" // Content (Description)
        forcedisplayIndex += 1
        forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=22" // Observer/Creator
        forcedisplayIndex += 1
        forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=6" // Observer
        forcedisplayIndex += 1
        
        // Adicionar Técnico apenas se não for pesquisa de NOVOS (Status 1) para evitar quebra do servidor
        if status != .new && statusValue != 1 && statusQueryString?.lowercased() != "novo" {
            forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=5"
            forcedisplayIndex += 1
            forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=70"
            forcedisplayIndex += 1
            forcedisplayString += "&forcedisplay[\(forcedisplayIndex)]=71"
            forcedisplayIndex += 1
        }
        urlString += "&\(forcedisplayString)"
        
        // Sorting
        urlString += "&sort=19&order=\(order)"
        
        // Codificação segura apenas dos caracteres necessários
        let safeURLString = urlString.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")
        
        guard let url = URL(string: safeURLString) else {
            print("GLPI ERROR: URL inválido = \(safeURLString)")
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        print("GLPI FETCH: \(url.absoluteString)")
        return sessionRequest(url: url)
            .handleEvents(receiveOutput: { (response: TicketListResponse) in
                print("GLPI FETCH SUCCESS: total = \(response.totalInt), items = \(response.data?.count ?? 0)")
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("GLPI FETCH ERROR: \(error.localizedDescription)")
                }
            })
            .map { (response: TicketListResponse) -> ([GLPITicket], Int) in
                let rawData = response.data ?? []
                let mapped = self.mapToTickets(rawData)
                if isDeleted {
                    let updated = mapped.map { ticket in
                        GLPITicket(
                            id: ticket.id,
                            name: ticket.name,
                            requester: ticket.requester,
                            author: ticket.author,
                            assignedTo: ticket.assignedTo,
                            description: ticket.description,
                            date: ticket.date,
                            priority: ticket.priority,
                            status: .deleted,
                            rawStatus: ticket.rawStatus,
                            isMine: ticket.isMine,
                            isAssignedToMe: ticket.isAssignedToMe,
                            responses: ticket.responses
                        )
                    }
                    return (updated, response.totalInt)
                }
                return (mapped, response.totalInt)
            }
            .eraseToAnyPublisher()
    }
    
    func mapToTickets(_ data: [[String: AnyCodable]]) -> [GLPITicket] {
        return data.compactMap { dict in
            let idValue = dict["2"]?.value ?? dict["id"]?.value ?? "0"
            let idStr = String(describing: idValue).replacingOccurrences(of: ".0", with: "")
            
            let title = dict["1"]?.value as? String ?? "Ticket #\(idStr)"
            let descRaw = dict["21"]?.value as? String ?? ""
            let desc = GlpiHtmlFixer.clean(descRaw)
            
            let rawDate15 = dict["15"]?.value as? String
            let rawDate19 = dict["19"]?.value as? String
            let rawDate17 = dict["17"]?.value as? String
            
            let date: String
            if let r15 = rawDate15, r15 != "null", !r15.isEmpty {
                date = r15
            } else if let r19 = rawDate19, r19 != "null", !r19.isEmpty {
                date = r19
            } else if let r17 = rawDate17, r17 != "null", !r17.isEmpty {
                date = r17
            } else {
                date = ""
            }
            
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
            
            // Requerente: Apenas campo 4 (Requerente real no sistema GLPI)
            let requester = formatarNome(fieldId: "4") ?? ""
            
            // Técnico: Tenta 5, 70, 71 (Paridade Android)
            let assigned = formatarNome(fieldId: "5") ?? formatarNome(fieldId: "70") ?? formatarNome(fieldId: "71") ?? "Pendente"
            
            // Observador: Campo 6 (Observador real no sistema GLPI)
            let observer = formatarNome(fieldId: "6") ?? ""
            
            let statusRaw = String(describing: dict["12"]?.value ?? "1").replacingOccurrences(of: ".0", with: "")
            let status: TicketStatus
            switch statusRaw {
            case "1": status = .new
            case "2": status = .assigned
            case "3": status = .planned
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

            // Extração de itemtype (campo 70) e items_id (campo 71)
            let rawItemType = dict["70"]?.value
            let assocItemType: String?
            if let map = rawItemType as? [String: AnyCodable] {
                assocItemType = map["name"]?.value as? String ?? map["completename"]?.value as? String
            } else if let s = rawItemType as? String, s != "0", s != "null" {
                assocItemType = s
            } else {
                assocItemType = nil
            }
            
            let rawItemId = dict["71"]?.value
            let assocItemId: String?
            if let s = rawItemId as? String, s != "0", s != "null" {
                assocItemId = s
            } else if let i = rawItemId as? Int, i != 0 {
                assocItemId = String(i)
            } else if let d = rawItemId as? Double, d != 0.0 {
                assocItemId = String(Int(d))
            } else {
                assocItemId = nil
            }

            let dueDateStr = dict["18"]?.value as? String
            let ttrStr = dict["151"]?.value as? String
            let ttoStr = dict["158"]?.value as? String
            
            return GLPITicket(
                id: idStr,
                name: title,
                requester: requester,
                author: formatarNome(fieldId: "22") ?? "Desconhecido",
                assignedTo: assigned,
                observer: observer,
                description: desc,
                date: date.toDate() ?? Date(),
                priority: priority,
                status: status,
                rawStatus: statusRaw,
                isMine: false,
                isAssignedToMe: false,
                associatedItemType: assocItemType,
                associatedItemId: assocItemId,
                dueDate: dueDateStr?.toDate(),
                ttr: ttrStr?.toDate(),
                tto: ttoStr?.toDate()
            )
        }
    }
    
    /// Obtém tickets ativos do utilizador nos papéis de Requerente, Atribuído ou Observador
    func fetchActiveUserTickets(userId: Int, notifyRequester: Bool, notifyAssigned: Bool, notifyObserver: Bool) -> AnyPublisher<[GLPITicket], Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var queryParts: [String] = []
        var subCriteriaIndex = 0
        
        if notifyRequester {
            queryParts.append("criteria[0][criteria][\(subCriteriaIndex)][field]=4&criteria[0][criteria][\(subCriteriaIndex)][searchtype]=equals&criteria[0][criteria][\(subCriteriaIndex)][value]=\(userId)")
            subCriteriaIndex += 1
        }
        
        if notifyAssigned {
            let link = subCriteriaIndex > 0 ? "criteria[0][criteria][\(subCriteriaIndex)][link]=OR&" : ""
            queryParts.append("\(link)criteria[0][criteria][\(subCriteriaIndex)][field]=5&criteria[0][criteria][\(subCriteriaIndex)][searchtype]=equals&criteria[0][criteria][\(subCriteriaIndex)][value]=\(userId)")
            subCriteriaIndex += 1
        }
        
        if notifyObserver {
            let link = subCriteriaIndex > 0 ? "criteria[0][criteria][\(subCriteriaIndex)][link]=OR&" : ""
            queryParts.append("\(link)criteria[0][criteria][\(subCriteriaIndex)][field]=22&criteria[0][criteria][\(subCriteriaIndex)][searchtype]=equals&criteria[0][criteria][\(subCriteriaIndex)][value]=\(userId)")
            subCriteriaIndex += 1
        }
        
        // Se nenhum estiver ativo, retorna vazio
        guard subCriteriaIndex > 0 else {
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        // Apenas tickets ativos (status < 5, ou seja, 1, 2, 3, 4)
        queryParts.append("criteria[1][link]=AND&criteria[1][criteria][0][field]=12&criteria[1][criteria][0][searchtype]=lessthan&criteria[1][criteria][0][value]=5")
        
        let criteriaString = queryParts.joined(separator: "&")
        let urlString = "\(cleanBaseURL)/apirest.php/search/Ticket?range=0-50&expand_dropdowns=true&\(criteriaString)&forcedisplay[0]=2&forcedisplay[1]=1&forcedisplay[2]=4&forcedisplay[3]=5&forcedisplay[4]=22&forcedisplay[5]=12"
        
        let safeURLString = urlString.replacingOccurrences(of: "[", with: "%5B").replacingOccurrences(of: "]", with: "%5D")
        
        guard let url = URL(string: safeURLString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return sessionRequest(url: url)
            .map { (response: TicketListResponse) -> [GLPITicket] in
                let rawData = response.data ?? []
                return self.mapToTickets(rawData)
            }
            .eraseToAnyPublisher()
    }
    
    /// Obtém as últimas atualizações para o carrossel
    func fetchRecentActivities(userId: Int? = nil) -> AnyPublisher<[(title: String, desc: String, status: String)], Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var queryParams = "range=0-8&sort=19&order=DESC&forcedisplay[0]=2&forcedisplay[1]=1&forcedisplay[3]=15&forcedisplay[4]=12&forcedisplay[5]=21&forcedisplay[6]=17&forcedisplay[7]=16&forcedisplay[8]=4&forcedisplay[9]=5&forcedisplay[10]=22&forcedisplay[11]=8&forcedisplay[12]=14&forcedisplay[13]=70&forcedisplay[14]=71&forcedisplay[15]=6&forcedisplay[16]=7&forcedisplay[17]=3&expand_dropdowns=true"
        
        if let uid = userId {
            let criteria = "criteria[0][field]=4&criteria[0][searchtype]=equals&criteria[0][value]=\(uid)&criteria[1][link]=OR&criteria[1][field]=5&criteria[1][searchtype]=equals&criteria[1][value]=\(uid)&criteria[2][link]=OR&criteria[2][field]=22&criteria[2][searchtype]=equals&criteria[2][value]=\(uid)&criteria[3][link]=OR&criteria[3][field]=6&criteria[3][searchtype]=equals&criteria[3][value]=\(uid)"
            queryParams += "&\(criteria)"
        }
        
        let urlString = "\(cleanBaseURL)/apirest.php/search/Ticket?\(queryParams)"
        
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
                    
                    // Field 12 (status) pode vir como Int ou String dependendo do GLPI
                    let statusID: String
                    if let s = row["12"]?.value as? String {
                        statusID = s
                    } else if let i = row["12"]?.value as? Int {
                        statusID = String(i)
                    } else if let d = row["12"]?.value as? Double {
                        statusID = String(Int(d))
                    } else {
                        statusID = "1"
                    }
                    
                    let statusStr = self.mapStatus(statusID)
                    return (title: title, desc: desc, status: statusStr)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Obtém os followups (respostas) de um ticket específico
    func fetchTicketFollowups(ticketId: String) -> AnyPublisher<[TicketResponse], Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket/\(ticketId)/ITILFollowup"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return sessionRequest(url: url)
            .map { (responseArray: [[String: AnyCodable]]) -> [TicketResponse] in
                return responseArray.compactMap { dict in
                    let contentRaw = dict["content"]?.value as? String ?? ""
                    let content = GlpiHtmlFixer.clean(contentRaw)
                    let dateStr = dict["date_creation"]?.value as? String ?? ""
                    let userId = String(describing: dict["users_id"]?.value ?? "").replacingOccurrences(of: ".0", with: "")
                    
                    return TicketResponse(
                        author: userId,
                        content: content,
                        date: dateStr.toDate() ?? Date(),
                        isInternal: false,
                        isSolution: false
                    )
                }
            }
            .catch { _ in Just([]).setFailureType(to: Error.self) }
            .eraseToAnyPublisher()
    }

    /// Obtém as soluções de um ticket específico
    func fetchTicketSolutions(ticketId: String) -> AnyPublisher<[TicketResponse], Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let urlString = "\(cleanBaseURL)/apirest.php/Ticket/\(ticketId)/ITILSolution"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        
        return sessionRequest(url: url)
            .map { (responseArray: [[String: AnyCodable]]) -> [TicketResponse] in
                return responseArray.compactMap { dict in
                    let contentRaw = dict["content"]?.value as? String ?? ""
                    let content = GlpiHtmlFixer.clean(contentRaw)
                    let dateStr = dict["date_creation"]?.value as? String ?? ""
                    let userId = String(describing: dict["users_id"]?.value ?? "").replacingOccurrences(of: ".0", with: "")
                    
                    return TicketResponse(
                        author: userId,
                        content: content,
                        date: dateStr.toDate() ?? Date(),
                        isInternal: false,
                        isSolution: true
                    )
                }
            }
            .catch { _ in Just([]).setFailureType(to: Error.self) }
            .eraseToAnyPublisher()
    }
    
    // --- Auxiliares de API ---
    
    func searchCount(itemType: String, statusValue: Int, startDate: String? = nil, userId: Int? = nil) -> AnyPublisher<Int, Error> {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        var criteriaString = ""
        
        if let uid = userId {
            // Vista Pessoal: USER é criteria[0] (Sempre aninhado)
            criteriaString += "criteria[0][criteria][0][field]=4&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(uid)"
            criteriaString += "&criteria[0][criteria][1][link]=OR&criteria[0][criteria][1][field]=5&criteria[0][criteria][1][searchtype]=equals&criteria[0][criteria][1][value]=\(uid)"
            criteriaString += "&criteria[0][criteria][2][link]=OR&criteria[0][criteria][2][field]=22&criteria[0][criteria][2][searchtype]=equals&criteria[0][criteria][2][value]=\(uid)"
            criteriaString += "&criteria[0][criteria][3][link]=OR&criteria[0][criteria][3][field]=6&criteria[0][criteria][3][searchtype]=equals&criteria[0][criteria][3][value]=\(uid)"
            
            // STATUS é criteria[1] (Sempre aninhado)
            criteriaString += "&criteria[1][link]=AND&criteria[1][criteria][0][field]=12&criteria[1][criteria][0][searchtype]=equals&criteria[1][criteria][0][value]=\(statusValue)"
            
            // DATE é criteria[2] (opcional, aninhado)
            if let sd = startDate {
                let dateField = (statusValue == 5) ? 19 : 15
                criteriaString += "&criteria[2][link]=AND&criteria[2][criteria][0][field]=\(dateField)&criteria[2][criteria][0][searchtype]=morethan&criteria[2][criteria][0][value]=\(sd)"
            }
        } else {
            // Vista Geral: STATUS é criteria[0] (Sempre aninhado)
            criteriaString += "criteria[0][criteria][0][field]=12&criteria[0][criteria][0][searchtype]=equals&criteria[0][criteria][0][value]=\(statusValue)"
            
            // DATE é criteria[1] (opcional, aninhado)
            if let sd = startDate {
                let dateField = (statusValue == 5) ? 19 : 15
                criteriaString += "&criteria[1][link]=AND&criteria[1][criteria][0][field]=\(dateField)&criteria[1][criteria][0][searchtype]=morethan&criteria[1][criteria][0][value]=\(sd)"
            }
        }
        
        let urlString = "\(cleanBaseURL)/apirest.php/search/\(itemType)?range=0-0&\(criteriaString)"
        
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
                let isDeletedQuery = url.absoluteString.contains("is_deleted=1")
                if isDeletedQuery { count = 4 }
                else if url.absoluteString.contains("value=1") { count = 24 } // Novos
                else if url.absoluteString.contains("value=2") { count = 12 } // Atribuídos
                else if url.absoluteString.contains("value=4") { count = 5 } // Espera
                else if url.absoluteString.contains("value=5") { count = 48 } // Finalizados
                
                let mockJSON: String
                if isDeletedQuery {
                    mockJSON = """
                    {
                        "totalcount": 4,
                        "count": 4,
                        "data": [
                            {"2": "901", "1": "Impressora Antiga Encerrada", "12": "6", "3": "2", "19": "2026-05-18 10:00:00", "4": "Carla Dias", "22": "Admin", "5": "Suporte Técnico", "21": "Retirada do escritório."},
                            {"2": "902", "1": "Teclado estragado", "12": "6", "3": "1", "19": "2026-05-18 09:30:00", "4": "João Mendes", "22": "Admin", "5": "Manutenção", "21": "Lixo eletrónico."},
                            {"2": "903", "1": "Monitor avariado", "12": "6", "3": "3", "19": "2026-05-17 14:00:00", "4": "Pedro Alves", "22": "Admin", "5": "Suporte Técnico", "21": "Ecrã partido."},
                            {"2": "904", "1": "Rato ótico partido", "12": "6", "3": "1", "19": "2026-05-16 11:15:00", "4": "Sónia Luz", "22": "Admin", "5": "Logística", "21": "Substituído por novo."}
                        ]
                    }
                    """
                } else {
                    mockJSON = """
                    {
                        "totalcount": \(count),
                        "count": 9,
                        "data": [
                        {"2": "110", "1": "Servidor de email em baixo", "12": "1", "3": "5", "19": "2026-05-19 09:00:00", "4": "Admin", "22": "Admin", "21": "Utilizadores sem acesso ao email."},
                        {"2": "109", "1": "Atualização de Segurança crítica", "12": "2", "3": "4", "19": "2026-05-19 08:30:00", "4": "Gonçalo Sousa", "22": "Admin", "5": "Suporte Técnico", "21": "Patch de Maio necessário urgente."},
                        {"2": "108", "1": "Monitor com riscas", "12": "3", "3": "3", "19": "2026-05-18 17:00:00", "4": "Sónia Luz", "22": "Suporte", "5": "Logística", "21": "Monitor LG parou de dar imagem."},
                        {"2": "107", "1": "Acesso VPN Falhou", "12": "4", "3": "5", "19": "2026-05-18 15:30:00", "4": "Rui Santos", "5": "Redes", "21": "Utilizador não consegue autenticar."},
                        {"2": "106", "1": "Substituição de Toner", "12": "5", "3": "2", "19": "2026-05-18 14:00:00", "4": "Carla Dias", "5": "Admin", "21": "Impressora do RH sem tinta."},
                        {"2": "105", "1": "Erro ao imprimir em PDF", "12": "1", "3": "3", "19": "2026-05-17 12:00:00", "4": "Pedro Alves", "22": "Eduardo Lima", "21": "O driver parece estar corrompido."},
                        {"2": "104", "1": "Pedido de software Adobe", "12": "5", "3": "4", "19": "2026-05-16 16:45:00", "4": "Diana Rose", "22": "Admin", "5": "Admin", "21": "Instalação do Photoshop concluída."},
                        {"2": "103", "1": "Teclado MacBook pro com teclas presas", "12": "2", "3": "2", "19": "2026-05-15 11:00:00", "4": "Carlos Mendes", "22": "Admin", "5": "Manutenção", "21": "Teclas A e S não respondem."},
                        {"2": "102", "1": "Configuração de novo iPhone", "12": "6", "3": "3", "19": "2026-05-14 10:15:00", "4": "Beatriz Silva", "22": "Suporte Técnico", "5": "Suporte Técnico", "21": "Migração de dados concluída."}
                    ]
                }
                """
                }
                mockData = mockJSON.data(using: .utf8)!
            } else {
                let emptyString = String(describing: T.self).hasPrefix("Array") || String(describing: T.self).hasPrefix("[") ? "[]" : "{}"
                mockData = emptyString.data(using: .utf8)!
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
        case "3": return "Planeado"
        case "4": return "Aguardando"
        case "5": return "Finalizado"
        case "6": return "Encerrado"
        default: return "Novo"
        }
    }
}
