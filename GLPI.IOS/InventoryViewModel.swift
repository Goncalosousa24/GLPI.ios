import Foundation
import Combine

class InventoryViewModel: ObservableObject {
    @Published var assets: [Asset] = [
        Asset(name: "MacBook Pro 16\"", tag: "TAG-001", icon: "desktopcomputer", type: .computer, status: "Operacional", owner: "João Silva", location: "Sede"),
        Asset(name: "Monitor Dell 27\"", tag: "TAG-042", icon: "display", type: .monitor, status: "Operacional", owner: "Maria Santos", location: "Sede"),
        Asset(name: "iPhone 15 Pro", tag: "TAG-089", icon: "network", type: .network, status: "Operacional", owner: "João Silva", location: "Sede"),
        Asset(name: "Impressora HP", tag: "TAG-112", icon: "printer.fill", type: .printer, status: "Manutenção", owner: nil, location: "Piso 1")
    ]
    
    @Published var isLoading = false
    
    func refreshAssets() {
        // Implementação futura
    }
}
