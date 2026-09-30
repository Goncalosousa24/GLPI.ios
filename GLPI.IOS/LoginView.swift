//
//  LoginView.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 17/04/2026.
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
    @State private var serverURL: String = PreferenceManager.shared.baseURL
    @AppStorage("is_offline_mode", store: UserDefaults(suiteName: "group.trabalho.GLPI-IOS")) var isOfflineMode: Bool = false
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 80)
                    
                    VStack(spacing: 45) {
                        // LOGO OFICIAL (Adaptativo ao Modo Claro/Escuro)
                        VStack(spacing: 0) {
                            Image(isLightMode ? "logoapp" : "logoapp_black")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 140)
                                .clipShape(Rectangle().inset(by: 2.0))
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
                            let isFormValid = isOfflineMode || (!username.isEmpty && !password.isEmpty)
                            
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
                    
                    // Modo Offline Toggle
                    Toggle(isOn: $isOfflineMode) {
                        Text("Modo Offline")
                            .font(.amiko(size: 14, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .tint(GlpiColors.universalBlue)
                    
                    // Escolha do Servidor
                    Menu {
                        Button("Localhost (Dev)") {
                            serverURL = "http://localhost:8080/"
                            PreferenceManager.shared.baseURL = serverURL
                        }
                        Button("Vila Verde (Produção)") {
                            serverURL = "http://O_TEU_SERVIDOR_PRODUCAO/"
                            PreferenceManager.shared.baseURL = serverURL
                        }
                    } label: {
                        HStack {
                            Image(systemName: "network")
                            Text(serverURL.contains("localhost") ? "Localhost (Dev)" : "Vila Verde (Produção)")
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .font(.amiko(size: 12, weight: .bold))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.6))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(GlpiColors.dynamicOffWhite)
                        .cornerRadius(12)
                    }
                    .padding(.bottom, 30)
                }
                .frame(minHeight: UIScreen.screenHeight)
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
            }
            .scrollDismissesKeyboard(.immediately)
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
            DispatchQueue.main.async {
                switch result {
                case .success(let token):
                    print("LoginView: Login sucesso, token: \(token)")
                    
                    // Tenta obter a sessão completa e o ID real do utilizador antes de avançar
                    GLPIService.shared.getFullSession()
                        .receive(on: DispatchQueue.main)
                        .sink { completion in
                            self.isLoading = false
                            // Independentemente de erro na validação extra, avançamos para o dashboard
                            withAnimation {
                                self.isLoggedIn = true
                            }
                        } receiveValue: { success in
                            print("LoginView: getFullSession completado com sucesso: \(success). ID do utilizador atualizado: \(PreferenceManager.shared.userId)")
                        }
                        .store(in: &self.cancellables)
                    
                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    print("LoginView: Erro no login: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
}
