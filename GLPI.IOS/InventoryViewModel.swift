import Foundation
import Combine
import SwiftUI

class InventoryViewModel: ObservableObject {
    @Published var assets: [Asset] = []
    @Published var isLoading = false
    
    @Published var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            // Reset to page 1 when search text changes
            if currentPage != 1 {
                currentPage = 1
            } else {
                fetchAssets()
            }
        }
    }
    
    @Published var selectedCategory: String? = nil {
        didSet {
            // Reset to page 1 when category changes
            if currentPage != 1 {
                currentPage = 1
            } else {
                fetchAssets()
            }
        }
    }
    
    @Published var selectedLocation: String? = nil {
        didSet {
            if currentPage != 1 {
                currentPage = 1
            } else {
                fetchAssets()
            }
        }
    }
    
    @Published var currentPage = 1 {
        didSet {
            fetchAssets()
        }
    }
    
    @Published var totalCount = 0
    let itemsPerPage = 5
    
    private var currentTask: Task<Void, Never>?
    
    var totalPages: Int {
        max(1, Int(ceil(Double(totalCount) / Double(itemsPerPage))))
    }
    
    init() {
        fetchAssets()
    }
    
    func refreshAssets() {
        fetchAssets()
    }
    
    func fetchAssets() {
        currentTask?.cancel()
        currentTask = Task {
            // Debounce se o utilizador estiver a digitar a pesquisa
            if !searchText.isEmpty {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
            }
            
            await MainActor.run {
                self.isLoading = true
            }
            
            do {
                let types: [String]
                if let category = selectedCategory {
                    switch category {
                    case "Computadores": types = ["Computer"]
                    case "Monitores": types = ["Monitor"]
                    case "Impressoras": types = ["Printer"]
                    case "Rede": types = ["NetworkEquipment"]
                    default: types = ["Computer", "Monitor", "Printer", "NetworkEquipment"]
                    }
                } else {
                    types = ["Computer", "Monitor", "Printer", "NetworkEquipment"]
                }
                
                let start = (currentPage - 1) * itemsPerPage
                let end = start + itemsPerPage - 1
                let range = "\(start)-\(end)"
                
                var allFetched: [Asset] = []
                var calculatedTotalCount = 0
                
                try await withThrowingTaskGroup(of: (String, TicketListResponse).self) { group in
                    for type in types {
                        group.addTask {
                            let response = try await GLPIClient.shared.searchInventory(itemtype: type, range: range, searchText: self.searchText)
                            return (type, response)
                        }
                    }
                    
                    for try await (type, response) in group {
                        calculatedTotalCount += response.totalInt
                        if let data = response.data {
                            let mapped = data.compactMap { item -> Asset? in
                                let name = item["1"]?.value as? String ?? "Equipamento"
                                let tag = item["2"]?.value as? String ?? "TAG-\(item["2"]?.value ?? "")"
                                let assetType = self.mapItemtypeToAssetType(type)
                                let icon = assetType.rawValue
                                let status = self.parseAssetField(item["31"]?.value) ?? "Nenhum"
                                let rawOwner = self.parseAssetField(item["70"]?.value)
                                let owner = rawOwner?.replacingOccurrences(of: ".", with: " ")
                                let department = self.parseAssetField(item["3"]?.value)
                                let serial = self.parseAssetField(item["5"]?.value) ?? ""
                                let realId = Int(String(describing: item["2"]?.value ?? "0")) ?? 0
                                
                                return Asset(realId: realId, name: name, tag: tag, icon: icon, type: assetType, status: status, owner: owner, department: department, serialNumber: serial)
                            }
                            allFetched.append(contentsOf: mapped)
                        }
                    }
                }
                
                if Task.isCancelled { return }
                
                // Ordenar por nome para manter consistência na exibição
                let sortedFetched = allFetched.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
                let finalAssets = Array(sortedFetched.prefix(itemsPerPage))
                
                await MainActor.run {
                    self.assets = finalAssets
                    self.totalCount = calculatedTotalCount
                    self.isLoading = false
                }
            } catch {
                if Task.isCancelled { return }
                print("Error loading assets: \(error)")
                await MainActor.run {
                    self.assets = []
                    self.totalCount = 0
                    self.isLoading = false
                }
            }
        }
    }
    
    private func mapItemtypeToAssetType(_ itemtype: String) -> AssetType {
        switch itemtype {
        case "Computer": return .computer
        case "Monitor": return .monitor
        case "Printer": return .printer
        case "NetworkEquipment": return .network
        default: return .network
        }
    }
    
    private func parseAssetField(_ value: Sendable?) -> String? {
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
}
