import Foundation
import Combine

class InventoryViewModel: ObservableObject {
    @Published var assets: [Asset] = [
        Asset(name: "MacBook Pro 16\"", tag: "TAG-001", icon: "desktopcomputer", type: .computer, status: "Operacional", owner: "João Silva", department: "Tecnologia", serialNumber: "C02F9XJ8MD6M"),
        Asset(name: "Monitor Dell 27\"", tag: "TAG-042", icon: "display", type: .monitor, status: "Operacional", owner: "Maria Santos", department: "Design", serialNumber: "CN-0F9XJ8-74261"),
        Asset(name: "iPhone 15 Pro", tag: "TAG-089", icon: "network", type: .network, status: "Operacional", owner: "João Silva", department: "Tecnologia", serialNumber: "H8X9J2L1X0V"),
        Asset(name: "Impressora HP", tag: "TAG-112", icon: "printer.fill", type: .printer, status: "Manutenção", owner: "Piso 1", department: "Administração", serialNumber: "VNB3K02948")
    ]
    
    @Published var isLoading = false
    
    func refreshAssets() {
        // Implementação futura
    }
}
