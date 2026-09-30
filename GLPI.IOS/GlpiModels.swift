import Foundation
import SwiftUI

// NOTA: Os modelos de resposta da API (SessionResponse, TicketListResponse, etc)
// foram movidos para GLPIServiceModels.swift para evitar conflitos de concorrência.

// --- Modelos de IU para Inventário ---

struct GLPIAsset: Identifiable {
    let id = UUID()
    let realId: Int
    let name: String
    let tag: String 
    let icon: String 
    let type: AssetType
    let status: String
    let owner: String?
    let department: String?
    let serialNumber: String
}

typealias Asset = GLPIAsset

enum AssetType: String {
    case computer = "desktopcomputer"
    case monitor = "display"
    case printer = "printer.fill"
    case network = "network"
    
    var displayName: String {
        switch self {
        case .computer: return "Computadores"
        case .monitor: return "Monitores"
        case .printer: return "Impressoras"
        case .network: return "Rede"
        }
    }
}

// --- Modelos de Tickets ---

struct TicketResponse: Identifiable, Sendable {
    let id = UUID()
    let author: String
    let content: String
    let date: Date
    let isInternal: Bool
    var isSolution: Bool = false
}

struct GLPITicket: Identifiable {
    let id: String
    var name: String // Alterado de title para name para bater com TicketRowView
    var title: String { name } // Alias for backward compatibility
    var requester: String
    var author: String // Novo campo para o criador real
    var assignedTo: String
    var observer: String // Novo campo para observador
    let description: String
    let date: Date // Alterado de String para Date para bater com TicketRowView
    let priority: TicketPriority
    let status: TicketStatus
    let rawStatus: String
    let isMine: Bool
    let isAssignedToMe: Bool
    var responses: [TicketResponse] = [] // Nova lista de respostas
    var associatedItemType: String? = nil
    var associatedItemId: String? = nil
    var dueDate: Date? = nil
    var ttr: Date? = nil
    var tto: Date? = nil

    init(
        id: String,
        name: String,
        requester: String,
        author: String,
        assignedTo: String,
        observer: String = "",
        description: String,
        date: Date,
        priority: TicketPriority,
        status: TicketStatus,
        rawStatus: String,
        isMine: Bool,
        isAssignedToMe: Bool,
        responses: [TicketResponse] = [],
        associatedItemType: String? = nil,
        associatedItemId: String? = nil,
        dueDate: Date? = nil,
        ttr: Date? = nil,
        tto: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.requester = requester
        self.author = author
        self.assignedTo = assignedTo
        self.observer = observer
        self.description = description
        self.date = date
        self.priority = priority
        self.status = status
        self.rawStatus = rawStatus
        self.isMine = isMine
        self.isAssignedToMe = isAssignedToMe
        self.responses = responses
        self.associatedItemType = associatedItemType
        self.associatedItemId = associatedItemId
        self.dueDate = dueDate
        self.ttr = ttr
        self.tto = tto
    }
}

typealias Ticket = GLPITicket

enum TicketPriority: String, CaseIterable {
    case veryLow = "Muito Baixo"
    case low = "Baixo"
    case medium = "Médio"
    case high = "Alto"
    case veryHigh = "Muito Alto"
    case major = "Principal"
    
    var color: Color {
        switch self {
        case .veryLow, .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .veryHigh, .major: return .red
        }
    }
}

enum TicketStatus: String {
    case new = "NOVO"
    case assigned = "ATRIBUÍDO"
    case planned = "PLANEADO"
    case waiting = "AGUARDANDO"
    case resolved = "FINALIZADO"
    case deleted = "RECICLAGEM"
    
    var title: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .new: return "star.fill"
        case .assigned: return "person.fill"
        case .planned: return "calendar.badge.clock"
        case .waiting: return "clock.fill"
        case .resolved: return "checkmark.circle.fill"
        case .deleted: return "trash.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .new: return .cyan
        case .assigned: return .yellow
        case .planned: return .purple
        case .waiting: return .orange
        case .resolved: return .green
        case .deleted: return .white.opacity(0.6)
        }
    }
}

// --- Modelos de Utilizadores ---

struct GLPIUser: Identifiable {
    let id = UUID()
    let name: String
    let email: String
    let profile: String       // Perfil principal (normalizado para exibição)
    let rawProfileList: String // Lista bruta do campo 20 (pode ter múltiplos perfis)
    
    init(name: String, email: String, profile: String, rawProfileList: String = "") {
        self.name = name
        self.email = email
        self.profile = profile
        self.rawProfileList = rawProfileList.isEmpty ? profile : rawProfileList
    }
}

// --- Modelos de Estatísticas ---

struct PerformanceStat: Identifiable, Codable {
    let id: UUID
    let month: String
    let attributed: Int
    let resolved: Int

    init(id: UUID = UUID(), month: String, attributed: Int, resolved: Int) {
        self.id = id
        self.month = month
        self.attributed = attributed
        self.resolved = resolved
    }
}

// --- Nome Formatting Helper ---
func formatarStringNome(_ raw: String?) -> String? {
    guard let raw = raw else { return nil }
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.isEmpty || s.lowercased() == "null" { return nil }
    if s.lowercased().hasPrefix("utilizador #") {
        let potential = String(s.dropFirst("utilizador #".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        if !potential.isEmpty && potential.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
            s = potential
        }
    }
    s = s.replacingOccurrences(of: ".", with: " ")
    let components = s.components(separatedBy: " ").filter { !$0.isEmpty }
    return components.map { word -> String in
        guard let first = word.first else { return "" }
        return String(first).uppercased() + String(word.dropFirst()).lowercased()
    }.joined(separator: " ")
}

