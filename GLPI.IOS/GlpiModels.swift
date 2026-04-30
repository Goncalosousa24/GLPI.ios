import Foundation
import SwiftUI

// NOTA: Os modelos de resposta da API (SessionResponse, TicketListResponse, etc)
// foram movidos para GLPIServiceModels.swift para evitar conflitos de concorrência.

// --- Modelos de IU para Inventário ---

struct GLPIAsset: Identifiable {
    let id = UUID()
    let name: String
    let tag: String // Alterado de serial para tag para bater com InventoryView
    let icon: String // Adicionado icon para bater com InventoryView
    let type: AssetType
    let status: String
    let owner: String?
    let location: String?
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

struct GLPITicket: Identifiable {
    let id: String
    var name: String // Alterado de title para name para bater com TicketRowView
    var title: String { name } // Alias for backward compatibility
    var requester: String
    var assignedTo: String
    let description: String
    let date: Date // Alterado de String para Date para bater com TicketRowView
    let priority: TicketPriority
    let status: TicketStatus
    let isMine: Bool
    let isAssignedToMe: Bool
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
    case waiting = "AGUARDANDO"
    case resolved = "RESOLVIDO"
    case deleted = "RECICLAGEM"
    
    var title: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .new: return "star.fill"
        case .assigned: return "person.fill"
        case .waiting: return "clock.fill"
        case .resolved: return "checkmark.circle.fill"
        case .deleted: return "trash.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .new: return .cyan
        case .assigned: return .yellow
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
    let profile: String
}

// --- Modelos de Estatísticas ---

struct PerformanceStat: Identifiable {
    let id = UUID()
    let month: String
    let attributed: Int
    let resolved: Int
}
