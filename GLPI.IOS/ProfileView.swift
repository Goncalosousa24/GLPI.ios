import SwiftUI

struct ProfileView: View {
    @Binding var isLoggedIn: Bool
    @State private var isAnimating = false
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    private var isDarkMode: Binding<Bool> {
        Binding(
            get: { !isLightMode },
            set: { isLightMode = !$0 }
        )
    }
    
    var body: some View {
        ZStack {
            GlpiColors.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                        Spacer(minLength: 60)
                        
                        // MARK: - User Info
                        VStack(spacing: 8) {
                            // Animated Profile Icon
                            ZStack {
                                Circle()
                                    .fill(GlpiColors.universalBlue.opacity(0.15))
                                    .frame(width: 110, height: 110)
                                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                                    .blur(radius: isAnimating ? 0 : 10)
                                
                                Image(systemName: "person.crop.circle.fill.badge.checkmark")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, GlpiColors.universalBlue)
                                    .font(.system(size: 90))
                                    .opacity(isAnimating ? 1 : 0)
                                    .scaleEffect(isAnimating ? 1 : 0.8)
                                    .offset(y: isAnimating ? 0 : 20)
                            }
                            .padding(.bottom, 15)
                            .animation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.5), value: isAnimating)
                            
                            Text("Gonçalo Sousa")
                                .font(.inconsolata(size: 26, weight: .bold))
                                .foregroundColor(GlpiColors.dynamicText)
                        }
                        
                        // MARK: - Stats (Devices & Monthly Tickets)
                        HStack(spacing: 15) {
                            ProfileStatCard(title: "DISPOSITIVOS", value: "3")
                            ProfileStatCard(title: "TICKETS (MÊS)", value: "14")
                        }
                        .padding(.horizontal, 16)
                        
                        // MARK: - App Info & Options
                        VStack(spacing: 0) {
                            // User Information
                            ProfileInfoRow(title: "Conta", value: "ADMINISTRADOR", icon: "person.badge.key.fill")
                            ProfileInfoRow(title: "Email", value: "goncalo@glpi.com", icon: "envelope.fill")
                            
                            Divider()
                                .background(GlpiColors.dynamicText.opacity(0.05))
                                .padding(.vertical, 15)
                            
                            // App Options
                            VStack(spacing: 12) {
                                ProfileMenuButton(title: "Modo Escuro", icon: "moon.fill", hasToggle: true, toggleValue: isDarkMode)
                                
                                NavigationLink(destination: UsersListView()) {
                                    ProfileMenuButton(title: "Utilizadores", icon: "person.2.fill")
                                }
                                NavigationLink(destination: ProfileStatisticsView()) {
                                    ProfileMenuButton(title: "Estatísticas", icon: "chart.bar.fill")
                                }
                                
                                NavigationLink(destination: NotificationsSettingsView()) {
                                    ProfileMenuButton(title: "Notificações", icon: "bell.fill")
                                }
                                NavigationLink(destination: TicketHistoryView()) {
                                    ProfileMenuButton(title: "Histórico", icon: "clock.arrow.2.circlepath")
                                }
                            }
                        }
                        .padding(20)
                        .glassStyle(cornerRadius: 25)
                        .padding(.horizontal, 16)
                        
                        // Botão Sair
                        Button(action: {
                            withAnimation {
                                isLoggedIn = false
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("ENCERRAR SESSÃO")
                                    .font(.amiko(size: 14, weight: .bold))
                            }
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .glassStyle(cornerRadius: 15)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .id(isLightMode)
            .animation(.easeInOut(duration: 0.3), value: isLightMode)
            .navigationBarHidden(true)
            .frame(width: UIScreen.main.bounds.width)
            .clipped()
            .tint(GlpiColors.dynamicText)
            .onAppear {
                isAnimating = true
            }
        }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(GlpiColors.universalBlue)
            
            Text(title)
                .font(.amiko(size: 11, weight: .bold))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 25)
        .glassStyle(cornerRadius: 22)
    }
}

struct ProfileMenuButton: View {
    let title: String
    let icon: String
    var hasToggle: Bool = false
    @Binding var toggleValue: Bool
    
    init(title: String, icon: String, hasToggle: Bool = false, toggleValue: Binding<Bool>? = nil) {
        self.title = title
        self.icon = icon
        self.hasToggle = hasToggle
        self._toggleValue = toggleValue ?? .constant(false)
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(GlpiColors.universalBlue)
                .frame(width: 24)
            
            Text(title)
                .font(.amiko(size: 15))
                .foregroundColor(GlpiColors.dynamicText)
            
            Spacer()
            
            if hasToggle {
                Toggle("", isOn: $toggleValue)
                    .labelsHidden()
                    .tint(GlpiColors.universalBlue)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
            }
        }
        .padding(.vertical, 5)
    }
}

struct ProfileInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(GlpiColors.universalBlue)
                .frame(width: 24)
            
            Text(title)
                .font(.amiko(size: 15))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.amiko(size: 14))
                .foregroundColor(GlpiColors.dynamicText)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ProfileView(isLoggedIn: .constant(true))
}
