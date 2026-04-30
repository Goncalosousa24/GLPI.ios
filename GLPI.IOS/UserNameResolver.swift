import Foundation
import Combine


/// Serviço dedicado para resolver nomes de utilizadores e grupos com cache e async/await
actor UserNameResolver {
    static let shared = UserNameResolver()
    
    private var cache: [String: String] = [:]
    private var pendingTasks: [String: Task<String, Error>] = [:]
    
    private init() {}
    
    /// Resolve o nome de um utilizador ou grupo de forma assíncrona
    func resolve(id: String, baseURL: String, sessionToken: String, appToken: String) async -> String {
        if PreferenceManager.shared.isOfflineMode {
            return "User #\(id)"
        }
        
        let cleanId = id.replacingOccurrences(of: ".0", with: "")
        if cleanId.isEmpty || cleanId == "0" || Int(cleanId) == nil { return id }
        
        // 1. Verificar Cache
        if let cached = cache[cleanId] {
            return cached
        }
        
        // 2. Verificar se já existe uma tarefa em curso para este ID
        if let existingTask = pendingTasks[cleanId] {
            do {
                return try await existingTask.value
            } catch {
                return "ID: \(cleanId)"
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
            return result
        } catch {
            pendingTasks.removeValue(forKey: cleanId)
            return "ID: \(cleanId)"
        }
    }
    
    private func fetchNameFromServer(id: String, baseURL: String, sessionToken: String, appToken: String) async -> String {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        // Tentamos primeiro USER, depois GROUP
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
        
        // Se ambos falharem com endpoints diretos, o teu servidor pode exigir a API de SEARCH
        return await fetchViaSearch(id: id, baseURL: baseURL, sessionToken: sessionToken, appToken: appToken)
    }
    
    private func fetchViaSearch(id: String, baseURL: String, sessionToken: String, appToken: String) async -> String {
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        
        // Procurar no Search de User (Campo 2 é o ID)
        let urlString = "\(cleanBaseURL)/apirest.php/search/User?criteria[0][field]=2&criteria[0][searchtype]=equals&criteria[0][value]=\(id)&forcedisplay[0]=1&forcedisplay[1]=9&forcedisplay[2]=34&forcedisplay[3]=81"
        
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            return "ID: \(id)"
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
                              (!uname.isEmpty ? uname : "ID: \(id)"))
                return fullName
            }
        } catch {
            return "ID: \(id)"
        }
        
        return "ID: \(id)"
    }
}
