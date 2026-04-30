//
//  PreferenceManager.swift
//  GLPI.IOS
//
//  Created by Antigravity on 17/04/2026.
//

import Foundation

class PreferenceManager {
    static let shared = PreferenceManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let baseURL = "base_url"
        static let appToken = "app_token"
        static let sessionToken = "session_token"
        static let userName = "cached_user_name"
        static let userEmail = "cached_user_email"
        static let userProfile = "cached_user_profile"
        static let userId = "authenticated_user_id"
        static let isOfflineMode = "is_offline_mode"
    }
    
    // --- Configurações do Servidor ---
    var isOfflineMode: Bool {
        get { return true } // Forçado a true para desenvolvimento offline
        set { defaults.set(newValue, forKey: Keys.isOfflineMode) }
    }
    
    var baseURL: String {
        get { defaults.string(forKey: Keys.baseURL) ?? "http://localhost:8080/" }
        set { defaults.set(newValue, forKey: Keys.baseURL) }
    }
    
    var appToken: String {
        get { defaults.string(forKey: Keys.appToken) ?? "Kv6GgUHREqU0e35dKamiQSh5vjUYenPrqMItEeIh" }
        set { defaults.set(newValue, forKey: Keys.appToken) }
    }
    
    var sessionToken: String {
        get { defaults.string(forKey: Keys.sessionToken) ?? "2j7mk6e6vje7866g8jvlgft1s6" }
        set { defaults.set(newValue, forKey: Keys.sessionToken) }
    }
    
    // --- Dados do Utilizador ---
    var userName: String? {
        get { defaults.string(forKey: Keys.userName) }
        set { defaults.set(newValue, forKey: Keys.userName) }
    }
    
    var userEmail: String? {
        get { defaults.string(forKey: Keys.userEmail) }
        set { defaults.set(newValue, forKey: Keys.userEmail) }
    }
    
    var userProfile: String? {
        get { defaults.string(forKey: Keys.userProfile) }
        set { defaults.set(newValue, forKey: Keys.userProfile) }
    }
    
    var userId: Int {
        get { defaults.integer(forKey: Keys.userId) == 0 ? 7 : defaults.integer(forKey: Keys.userId) }
        set { defaults.set(newValue, forKey: Keys.userId) }
    }
    
    func clearAllDataCache() {
        let keysToRemove = [Keys.userName, Keys.userEmail, Keys.userProfile]
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
    }
}
