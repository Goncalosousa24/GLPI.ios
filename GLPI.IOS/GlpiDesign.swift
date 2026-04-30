//
//  GlpiDesign.swift
//  GLPI.IOS
//
//  Created by Antigravity on 17/04/2026.
//

import SwiftUI
import UIKit

struct GlpiColors {
    static let primary = Color(red: 0.0, green: 0.37, blue: 0.72) // #005FB8
    static let secondary = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let accent = Color.blue
    static let background = Color(UIColor.systemBackground)
    
    // Tons Premium Universais (Dashboard & Menus) - Agora mais profundos para integrar com fundoIOS
    static let deepPremiumBlue = Color(red: 0, green: 0.02, blue: 0.12)
    static let premiumNeonGradient = LinearGradient(
        colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Extensão interna para suporte HEX
    static func hex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        return Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    
    static let primaryGradient = LinearGradient(
        colors: [primary, primary.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Fundo Premium (Estável para evitar loops e distorção)
    static var premiumBackground: some View {
        PremiumBackgroundView()
    }
}

struct PremiumBackgroundView: View {
    
    var body: some View {
        Image("fundoIOS")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
    }
}

// Facilitador para usar Color(hex: "...") fora da struct
extension Color {
    init(hexString: String) {
        self = GlpiColors.hex(hexString)
    }
}
extension View {
    // Estilo de Vidro Radicalmente Transparente (ESTRUTURA ORIGINAL)
    func glassStyle(cornerRadius: CGFloat = 16, isSelection: Bool = false) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius, isSelection: isSelection))
    }
    
    // Novo Padrão de Vidro Premium (ESTRUTURA ORIGINAL)
    func premiumGlassStyle(cornerRadius: CGFloat = 16, isCapsule: Bool = false) -> some View {
        self.modifier(PremiumGlassModifier(cornerRadius: cornerRadius, isCapsule: isCapsule))
    }
    
    // Estilo especial para a TabBar (Ultra-Dark com Neon integrado)
    func tabBarGlassStyle() -> some View {
        self.modifier(TabBarGlassModifier())
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Modern Screen Helpers
extension UIScreen {
    @MainActor static var screenWidth: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds.width
        }
        return 390
    }
    
    @MainActor static var screenHeight: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds.height
        }
        return 844
    }
}

// MARK: - Reusable Filter Pill
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var width: CGFloat? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.amiko(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                .padding(.horizontal, width == nil ? 16 : 4)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: width, height: 44)
                .background(
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                            Capsule()
                                .inset(by: 2)
                                .stroke(Color.white.opacity(0.5), lineWidth: 3.5)
                                .blur(radius: 2)
                            Capsule()
                                .inset(by: 2)
                                .stroke(Color.white, lineWidth: 2.0)
                        } else {
                            Capsule()
                                .fill(Color.white.opacity(0.05))
                        }
                    }
                )
        }
    }
}

// Auxiliar para permitir formas dinâmicas no modificador
struct AnyShape: Shape, @unchecked Sendable {
    private let _path: (CGRect) -> Path
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// Fonte Amiko personalizada
extension Font {
    static func amiko(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let suffix: String
        switch weight {
        case .bold: suffix = "-Bold"
        case .semibold: suffix = "-SemiBold"
        default: suffix = "-Regular"
        }
        return .custom("Amiko\(suffix)", size: size)
    }
    
    static func inconsolata(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .custom("Inconsolata", size: size)
    }
}

// Componente de Campo de Texto com efeito vidro real e Amiko
struct GLPITextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .font(.system(size: 16))
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.amiko(size: 16))
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .font(.amiko(size: 16))
                    .foregroundColor(.white)
                    .autocapitalization(.none)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .glassStyle(cornerRadius: 12)
    }
}

// Botão moderno com Amiko
struct GLPIButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.amiko(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(GlpiColors.primaryGradient)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
        }
        .disabled(isLoading)
    }
}

struct DashboardQuickActionCard: View {
    let title: String
    let icon: String
    var color: Color = .white
    var action: (() -> Void)? = nil
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
            } else {
                cardContent
            }
        }
    }
    
    private var cardContent: some View {
        let finalColor = color
        
        return VStack(spacing: 0) {
            Spacer()
            
            // Content Container with fixed height to force alignment
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(finalColor)
                    .frame(width: 32, height: 32, alignment: .center) // Frame fixo total
                    .shadow(color: finalColor.opacity(0.3), radius: 5)
                
                if !title.isEmpty {
                    Text(title.uppercased())
                        .font(.amiko(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(height: 12, alignment: .center)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .glassStyle(cornerRadius: 22)
    }
}

// Auxiliar para efeito Blur real
struct Blur: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Componentes de Formulário Premium

struct EditFieldCapsule: View {
    let label: String
    let value: String
    let icon: String
    var valueColor: Color? = nil
    var action: () -> Void
    
    init(label: String, value: String, icon: String, valueColor: Color? = nil, action: @escaping () -> Void = {}) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            let finalValueColor = valueColor ?? .white
            
            return HStack(spacing: 15) {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.amiko(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(value)
                        .font(.amiko(size: 14))
                        .foregroundColor(finalValueColor)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .glassStyle(cornerRadius: 22)
        }
    }
}

struct OptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.amiko(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(isSelected ? Color.white.opacity(0.05) : Color.clear)
            .cornerRadius(12)
        }
    }
}

// MARK: - Scroll Tracking para Esconder TabBar

struct ScrollDirectionPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetTracker: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: ScrollDirectionPreferenceKey.self, value: geo.frame(in: .global).minY)
        }
        .frame(height: 0)
    }
}
struct DashboardStatCard: View {
    let title: String
    let value: Int
    var color: Color = .blue
    let trigger: Int
    
    @State private var displayValue: Int = 0
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text("\(displayValue)")
                .font(.amiko(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.amiko(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 85)
        .glassStyle(cornerRadius: 18)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                runCountAnimation()
            }
        }
        .onChange(of: trigger) { oldValue, newValue in
            runCountAnimation()
        }
        .onChange(of: value) { oldValue, newValue in
            runCountAnimation()
        }
    }
    
    private func runCountAnimation() {
        guard value > 0 else {
            displayValue = 0
            return
        }
        
        displayValue = 0
        let steps = 40
        let duration = 0.8 // Um pouco mais rápido para ser mais dinâmico
        let interval = duration / Double(steps)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + (Double(i) * interval)) {
                let nextValue = Int(Double(value) * Double(i) / Double(steps))
                // Usamos withAnimation apenas para o feedback visual do número a mudar
                withAnimation(.spring(response: 0.1, dampingFraction: 0.8)) {
                    self.displayValue = nextValue
                }
            }
        }
    }
}

// MARK: - Activity Components

struct ActivityRow: View {
    let activity: (title: String, desc: String, status: String)
    
    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(statusColor(activity.status).opacity(0.2))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.amiko(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(activity.desc)
                    .font(.amiko(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(activity.status.uppercased())
                .font(.amiko(size: 9, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(activity.status).opacity(0.1))
                .foregroundColor(statusColor(activity.status))
                .clipShape(Capsule())
        }
        .padding(15)
        .glassStyle(cornerRadius: 18)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "novo": return .cyan
        case "atribuído": return .yellow
        case "resolvido": return .green
        case "pendente": return .orange
        default: return .white
        }
    }
}

// MARK: - Glass Modifiers with Mode Support

struct GlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isSelection: Bool
    
    func body(content: Content) -> some View {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        
        content
            .background(
                ZStack {
                    if isPreview {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.white.opacity(0.02))
                            .background(Blur(style: .systemUltraThinMaterial).opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                    
                    if isSelection {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.blue.opacity(0.1))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isSelection ? LinearGradient(colors: [.white, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

struct PremiumGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isCapsule: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Blur(style: .systemUltraThinMaterial)
                        .opacity(0.8)
                    GlpiColors.deepPremiumBlue.opacity(0.8)
                }
                .clipShape(isCapsule ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius)))
            )
            .overlay(
                Group {
                    if isCapsule {
                        Capsule()
                            .stroke(GlpiColors.premiumNeonGradient, lineWidth: 1.0)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(GlpiColors.premiumNeonGradient, lineWidth: 1.0)
                    }
                }
            )
    }
}

struct TabBarGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Blur(style: .systemUltraThinMaterial)
                        .opacity(0.85)
                    GlpiColors.deepPremiumBlue.opacity(0.8)
                }
                .clipShape(Capsule())
            )
            .shadow(color: Color.blue.opacity(0.15), radius: 20, x: 0, y: 10)
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.8), Color.blue.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
    }
}

