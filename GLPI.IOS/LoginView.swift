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
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 80)
                    
                    VStack(spacing: 45) {
                        // LOGO OFICIAL (Adaptativo ao Modo Claro/Escuro)
                        VStack(spacing: 0) {
                            Image("logoapp")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 140)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        VStack(spacing: 16) {
                            GLPITextField(icon: "pessoa2", placeholder: "Utilizador", text: $username, isSystemIcon: false, activeIcon: "pessoa")
                            GLPITextField(icon: "lock", placeholder: "Palavra-passe", text: $password, isSecure: true, activeIcon: "lock.fill")
                        }
                        .padding(.horizontal, 8)
                        
                        VStack(spacing: 20) {
                            let isFormValid = !username.isEmpty && !password.isEmpty
                            
                            Button(action: {
                                hideKeyboard()
                                performRealLogin()
                            }) {
                                ZStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("ENTRAR")
                                            .font(.amiko(size: 16, weight: .black))
                                            .foregroundColor(.white)
                                            .tracking(1)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    isFormValid ? 
                                    AnyView(GlpiColors.universalBlue) : 
                                    AnyView(GlpiColors.universalBlue.opacity(0.3))
                                )
                                .cornerRadius(16)
                                .shadow(color: isFormValid ? GlpiColors.universalBlue.opacity(0.4) : Color.clear, radius: 15, x: 0, y: 8)
                            }
                            .disabled(!isFormValid || isLoading)
                            .animation(.spring(), value: isFormValid)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .frame(minHeight: UIScreen.screenHeight)
            }
            .universalBackgroundDismiss { hideKeyboard() }
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
