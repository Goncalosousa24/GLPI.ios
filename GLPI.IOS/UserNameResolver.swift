import Foundation
import Combine


/// Serviço dedicado para resolver nomes de utilizadores e grupos com cache e async/await
actor UserNameResolver {
    static let shared = UserNameResolver()
    
    private var cache: [String: String] = [:]
    private var pendingTasks: [String: Task<String, Error>] = [:]
    
    private init() {}
    
    private func formatName(_ name: String) -> String {
        var cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanName.contains("@") && cleanName.contains(".") {
            cleanName = cleanName.replacingOccurrences(of: ".", with: " ")
        }
        
        let trimmed = cleanName
        if trimmed.isEmpty || trimmed.lowercased().hasPrefix("id:") || Int(trimmed) != nil {
            return name
        }
        
        if trimmed.lowercased() == "pendente" || trimmed.lowercased() == "desconhecido" {
            return trimmed.capitalized
        }
        
        let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !components.isEmpty else { return name }
        
        let ignoreWords = Set(["de", "do", "da", "dos", "das", "e"])
        let filtered = components.filter { !ignoreWords.contains($0.lowercased()) }
        
        guard !filtered.isEmpty else { return name }
        
        let first = filtered.first!.lowercased().capitalized
        if filtered.count > 1 {
            let last = filtered.last!.lowercased().capitalized
            return "\(first) \(last)"
        }
        return first
    }
    
    /// Resolve o nome de um utilizador ou grupo de forma assíncrona
    func resolve(id: String, baseURL: String, sessionToken: String, appToken: String) async -> String {
        if PreferenceManager.shared.isOfflineMode {
            return formatName(id)
        }
        
        let cleanId = id.replacingOccurrences(of: ".0", with: "")
        if cleanId.isEmpty || cleanId == "0" {
            return formatName(id)
        }
        
        // 1. Verificar se é o utilizador logado para evitar chamadas de API desnecessárias/bloqueadas por permissões
        if let loggedInUsername = PreferenceManager.shared.userName, cleanId.lowercased() == loggedInUsername.lowercased() {
            if let cachedDisplayName = PreferenceManager.shared.userDisplayName {
                return formatName(cachedDisplayName)
            }
        }
        if cleanId == String(PreferenceManager.shared.userId) {
            if let cachedDisplayName = PreferenceManager.shared.userDisplayName {
                return formatName(cachedDisplayName)
            }
        }
        
        // 2. Verificar Cache
        if let cached = cache[cleanId] {
            return formatName(cached)
        }
        
        // 2. Verificar se já existe uma tarefa em curso para este ID/Username
        if let existingTask = pendingTasks[cleanId] {
            do {
                let name = try await existingTask.value
                return formatName(name)
            } catch {
                return formatName(cleanId)
            }
        }
        
        // 3. Criar nova tarefa de procura
        let task = Task<String, Error> { [weak self] in
            guard let self = self else { return "" }
            return await self.fetchNameFromServer(id: cleanId, baseURL: baseURL, sessionToken: sessionToken, appToken: appToken)
        }
        
        pendingTasks[cleanId] = task
        
        do {
            let result = try await task.value
            cache[cleanId] = result
            pendingTasks.removeValue(forKey: cleanId)
            return formatName(result)
        } catch {
            pendingTasks.removeValue(forKey: cleanId)
            return formatName(cleanId)
        }
    }
    
    private func fetchNameFromServer(id: String, baseURL: String, sessionToken: String, appToken: String) async -> String {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        // Se for numérico, tentamos primeiro endpoints diretos de User / Group
        if Int(id) != nil {
            let types = ["User", "Group"]
            for type in types {
                let urlString = "\(cleanBaseURL)/apirest.php/\(type)/\(id)?expand_dropdowns=true"
                guard let url = URL(string: urlString) else { continue }
                
                var request = URLRequest(url: url)
                request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
                request.addValue(appToken, forHTTPHeaderField: "App-Token")
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        continue // Tenta o próximo tipo se não for 200
                    }
                    
                    let actor = try JSONDecoder().decode(GLPIActor.self, from: data)
                    return actor.displayName
                } catch {
                    continue
                }
            }
        }
        
        // Se ambos falharem com endpoints diretos, ou se não for ID numérico (e.g. username), tentamos a pesquisa
        return await fetchViaSearch(id: id, baseURL: baseURL, sessionToken: sessionToken, appToken: appToken)
    }
    
    private func fetchViaSearch(id: String, baseURL: String, sessionToken: String, appToken: String) async -> String {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        // Se for numérico, procuramos no campo 2 (ID). Se não, no campo 1 (Username/Login)
        let isNumeric = Int(id) != nil
        let field = isNumeric ? "2" : "1"
        
        let urlString = "\(cleanBaseURL)/apirest.php/search/User?criteria[0][field]=\(field)&criteria[0][searchtype]=equals&criteria[0][value]=\(id)&forcedisplay[0]=1&forcedisplay[1]=9&forcedisplay[2]=34&forcedisplay[3]=81"
        
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            return id
        }
        
        var request = URLRequest(url: url)
        request.addValue(sessionToken, forHTTPHeaderField: "Session-Token")
        request.addValue(appToken, forHTTPHeaderField: "App-Token")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]],
               let first = dataArray.first {
                
                let fname = first["34"] as? String ?? ""
                let rname = first["9"] as? String ?? ""
                let uname = first["1"] as? String ?? ""
                let cname = first["81"] as? String ?? ""
                
                let fullName = !cname.isEmpty ? cname : 
                              (!(fname.isEmpty && rname.isEmpty) ? "\(fname) \(rname)".trimmingCharacters(in: .whitespaces) : 
                              (!uname.isEmpty ? uname : id))
                return fullName
            }
        } catch {
            return id
        }
        
        return id
    }
}
