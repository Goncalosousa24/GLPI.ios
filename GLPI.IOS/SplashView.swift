import SwiftUI

struct SplashView: View {
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    @State private var progress: CGFloat = 0.0
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    
    var onCompletion: () -> Void
    
    var body: some View {
        ZStack {
            // Fundo Branco para Claro / Preto para Escuro
            (isLightMode ? Color.white : Color.black)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo Adaptativo
                Image(isLightMode ? "logoapp" : "logoapp_black")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
                    .clipShape(Rectangle().inset(by: 2.0))
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Spacer()
                
                // Barra de Progresso Oval (Retângulo Oval que vai carregando)
                VStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(isLightMode ? Color.gray.opacity(0.15) : Color.white.opacity(0.1))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(GlpiColors.universalBlue)
                            .frame(width: 200 * progress, height: 8)
                    }
                    .frame(width: 200)
                }
                .padding(.bottom, 120)
            }
        }
        .onAppear {
            // Animação de entrada do Logo
            withAnimation(.easeOut(duration: 0.8)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            // Animação da Barra de Carregamento Oval
            withAnimation(.easeInOut(duration: 2.2)) {
                progress = 1.0
            }
            
            // Finaliza após a animação estar concluída
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onCompletion()
            }
        }
    }
}

#Preview {
    SplashView(onCompletion: {})
}
