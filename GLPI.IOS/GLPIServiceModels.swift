//
//  GLPIServiceModels.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 30/04/2026.
//

@preconcurrency import Foundation

// Estas estruturas são puramente para a API e não devem depender de SwiftUI
// para evitar avisos de concorrência (Swift 6).

struct GLPIActor: Decodable, Sendable {
    let id: Int
    let name: String?
    let realname: String?
    let firstname: String?
    let completename: String?
    
    nonisolated var displayName: String {
        if let c = completename, !c.isEmpty { return c }
        let full = "\(firstname ?? "") \(realname ?? "")".trimmingCharacters(in: .whitespaces)
        if !full.isEmpty { return full }
        return name ?? "ID: \(id)"
    }
}

struct SessionResponse: Codable, Sendable {
    let session_token: String
}

struct UserResponse: Codable, Sendable {
    let id: Int
    let name: String
    let realname: String?
    let firstname: String?
    let completename: String?
}

struct TicketListResponse: Codable, Sendable {
    var data: [[String: AnyCodable]]?
    var totalcount: AnyCodable?
    var count: AnyCodable?
    
    enum CodingKeys: String, CodingKey {
        case data, totalcount, count
    }
    
    init(totalcount: Int, count: Int, data: [[String: AnyCodable]]? = nil) {
        self.totalcount = AnyCodable(totalcount)
        self.count = AnyCodable(count)
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        if let container = container {
            data = try? container.decode([[String: AnyCodable]].self, forKey: .data)
            totalcount = try? container.decode(AnyCodable.self, forKey: .totalcount)
            count = try? container.decode(AnyCodable.self, forKey: .count)
        } else {
            let arrayContainer = try? decoder.singleValueContainer()
            if let array = try? arrayContainer?.decode([[String: AnyCodable]].self) {
                data = array
                totalcount = AnyCodable(array.count)
                count = AnyCodable(array.count)
            }
        }
    }
    
    var totalInt: Int {
        if let val = totalcount?.value as? Int { return val }
        if let val = totalcount?.value as? String, let intVal = Int(val) { return intVal }
        if let array = data { return array.count }
        return 0
    }
}

struct AnyCodable: Codable, Sendable {
    let value: Sendable
    
    init(_ value: Sendable) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = "null"
        } else if let x = try? container.decode(Int.self) { value = x }
        else if let x = try? container.decode(String.self) { value = x }
        else if let x = try? container.decode(Double.self) { value = x }
        else if let x = try? container.decode(Bool.self) { value = x }
        else if let x = try? container.decode([String: AnyCodable].self) { value = x }
        else if let x = try? container.decode([AnyCodable].self) { value = x }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Wrong type") }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let x = value as? Int { try container.encode(x) }
        else if let x = value as? String { try container.encode(x) }
        else if let x = value as? Double { try container.encode(x) }
        else if let x = value as? Bool { try container.encode(x) }
        else if let x = value as? [String: AnyCodable] { try container.encode(x) }
        else if let x = value as? [AnyCodable] { try container.encode(x) }
    }
    
    var stringValue: String {
        if let str = value as? String {
            return str
        }
        if let intVal = value as? Int {
            return String(intVal)
        }
        if let dblVal = value as? Double {
            return String(dblVal)
        }
        if let boolVal = value as? Bool {
            return String(boolVal)
        }
        if let arr = value as? [AnyCodable] {
            let elements = arr.map { $0.stringValue }
            return "[" + elements.joined(separator: ", ") + "]"
        }
        if let dict = value as? [String: AnyCodable] {
            if let nameVal = dict["name"]?.stringValue {
                return nameVal
            }
            let pairs = dict.map { "\($0.key): \($0.value.stringValue)" }
            return "{" + pairs.joined(separator: ", ") + "}"
        }
        return "\(value)"
    }
}
