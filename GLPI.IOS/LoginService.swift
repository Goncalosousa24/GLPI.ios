//
//  LoginService.swift
//  GLPI.IOS
//
//  Created by Antigravity on 17/04/2026.
//

import Foundation

class LoginService {
    static let shared = LoginService()
    
    func login(user: String, pass: String, completion: @escaping (Result<String, Error>) -> Void) {
        if PreferenceManager.shared.isOfflineMode {
            PreferenceManager.shared.sessionToken = "mock_session_token"
            PreferenceManager.shared.userName = user
            completion(.success("mock_session_token"))
            return
        }
        
        // Limpar qualquer sessão antiga para evitar conflitos
        PreferenceManager.shared.sessionToken = ""
        
        let baseURL = PreferenceManager.shared.baseURL
        let appToken = PreferenceManager.shared.appToken
        
        let cleanBaseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: "\(cleanBaseURL)/apirest.php/initSession") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        let loginString = "\(user):\(pass)"
        guard let loginData = loginString.data(using: .utf8) else { return }
        let base64LoginString = loginData.base64EncodedString(options: [])
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(appToken, forHTTPHeaderField: "App-Token")
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let sessionResponse = try decoder.decode(SessionResponse.self, from: data)
                PreferenceManager.shared.sessionToken = sessionResponse.session_token
                completion(.success(sessionResponse.session_token))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
