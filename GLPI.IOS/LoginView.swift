//
//  LoginView.swift
//  GLPI.IOS
//
//  Created by Antigravity on 17/04/2026.
//

import SwiftUI
import Combine

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @AppStorage("isLightMode") var isLightMode: Bool = false
    
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 35) {
                        VStack(spacing: 12) {
                            Text("GLPI")
                                .font(.amiko(size: 48, weight: .bold)) // Bigger logo for better centering impact
                                .foregroundColor(isLightMode ? .black : .white)
                            
                            Text("Gestão de TI na palma da mão")
                                .font(.amiko(size: 16))
                                .foregroundColor(isLightMode ? .black.opacity(0.7) : .white.opacity(0.7))
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.amiko(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        VStack(spacing: 20) {
                            GLPITextField(icon: "person.fill", placeholder: "Utilizador", text: $username)
                            GLPITextField(icon: "lock.fill", placeholder: "Palavra-passe", text: $password, isSecure: true)
                        }
                        
                        VStack(spacing: 15) {
                            GLPIButton(title: "ENTRAR", action: {
                                performRealLogin()
                            }, isLoading: isLoading)
                            
                            Button(action: { /* Esqueci-me da pass */ }) {
                                Text("Esqueceu a palavra-passe?")
                                    .font(.amiko(size: 14))
                                    .foregroundColor(isLightMode ? .black.opacity(0.5) : .white.opacity(0.5))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                }
                .frame(minHeight: UIScreen.screenHeight)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(isLightMode ? .light : .dark)
    }
    @State private var cancellables = Set<AnyCancellable>()

    private func performRealLogin() {
        if PreferenceManager.shared.isOfflineMode {
            isLoggedIn = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        LoginService.shared.login(user: username, pass: password) { result in
            switch result {
            case .success(let token):
                print("LoginView: Login sucesso, token: \(token)")
                
                // Tenta validar a sessão (como o Android), mas não bloqueia se der erro de formato
                GLPIService.shared.getFullSession()
                    .sink { completion in
                        isLoading = false
                        // Independentemente de erro na validação extra, deixamos entrar
                        isLoggedIn = true
                    } receiveValue: { _ in
                        // Sucesso total
                    }
                    .store(in: &cancellables)
                
            case .failure(let error):
                isLoading = false
                errorMessage = error.localizedDescription
                print("LoginView: Erro no login: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
}
