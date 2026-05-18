//
//  GlpiDesign.swift
//  GLPI.IOS
//
//  Created by Antigravity on 17/04/2026.
//

import SwiftUI
import UIKit

/*
 =================================================================
 REGRAS DE DESIGN UNIVERSAIS (IMUTÁVEIS)
 =================================================================
 1. INTERAÇÃO E BORDAS: Elementos interativos (retângulos/cápsulas) devem exibir uma borda em 'GlpiColors.universalBlue' com espessura 'GlpiMetrics.UNIVERSAL_ACTIVE_BORDER_WIDTH' (3.0px) quando selecionados ou em foco.
 2. CANCELAMENTO UNIVERSAL: Toque no vazio (espaço em branco) deve SEMPRE cancelar seleções, fechar teclados ou recolher menus. Usar obrigatoriamente '.universalBackgroundDismiss()'.
 3. NAVEGAÇÃO: Seta de voltar deve ser SEMPRE 'chevron.left' (size: 22, semibold) e SEM contentor circular (seta solta).
 4. POSICIONAMENTO: Header deve usar 'top: 5px', 'height: 60px' e 'leading: padding + 5' para alinhamento universal de sistema.
 5. INDICADOR DE ESCRITA: O cursor (tint) deve ser SEMPRE 'GlpiColors.universalBlue'. Aplicado globalmente no root da app.
 =================================================================
*/

extension View {
    /// Aplica a lógica universal de cancelamento ao tocar no fundo (espaço em branco)
    func universalBackgroundDismiss(action: @escaping () -> Void) -> some View {
        self.background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    action()
                }
        )
    }
}

struct GlpiColors {
    static var primary: Color { universalBlue }
    static let secondary = dynamicOffWhite // Unificado para consistência
    static var accent: Color { universalBlue }
    
    static var background: Color {
        @AppStorage("isLightMode_V2") var isLightMode = true
        return isLightMode ? .white : .black
    }
    
    // Tons Premium Universais (Dashboard & Menus) - Agora mais profundos para integrar com fundoIOS
    static let deepPremiumBlue = Color.black
    static var premiumNeonGradient: LinearGradient {
        LinearGradient(
            colors: [universalBlue.opacity(0.8), universalBlue.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Gradiente Universal Premium (Royal a Ciano/Azul Vibrante)
    static let universalGradient = LinearGradient(
        colors: [
            Color(hexString: "0052D4"), // Royal Deep Blue
            Color(hexString: "4364F7"), // Electric Blue
            Color(hexString: "6FB1FC")  // Glowing Sky Blue
        ],
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

    static var dynamicText: Color {
        @AppStorage("isLightMode_V2") var isLightMode = true
        return isLightMode ? .black : .white
    }
    
    static var dynamicOffWhite: Color {
        @AppStorage("isLightMode_V2") var isLightMode = true
        // Fundo dos Cartões (Quadrados/Retângulos): Cinzento Sólido Universal
        return isLightMode ? Color(white: 0.96) : Color(white: 0.12)
    }
    
    static var dynamicBorder: Color {
        @AppStorage("isLightMode_V2") var isLightMode = true
        // Cinzento Sólido com Contraste: Mais visível para definir os cartões
        return isLightMode ? Color(white: 0.85) : Color(white: 0.3)
    }
    
    static let universalBlue = Color(hexString: "0B3CC4") // Azul Real Elétrico Escuro Premium (Vibrante e Profundo)
    static var dynamicBlueText: Color {
        @AppStorage("isLightMode_V2") var isLightMode = true
        return isLightMode ? universalBlue : .white
    }
    static let deleteRed = Color(red: 1.0, green: 0.1, blue: 0.1)       // Vermelho de Alerta Premium
}

struct GlpiMetrics {
    // --- MÉTRICAS DE CABEÇALHO (REGRA ZERO JUMP) ---
    static let topPadding: CGFloat = 5           // Padding superior interno do header
    static let headerHeight: CGFloat = 56        // Altura da barra de pesquisa
    static let navAreaHeight: CGFloat = 60       // Altura total da zona da seta (padding + frame)
    static let searchBarAnchor: CGFloat = 60     // Onde a barra de pesquisa deve SEMPRE começar
    static let universalHeaderLeading: CGFloat = padding + 5 // Alinhamento horizontal da seta
    
    // --- MÉTRICAS DE COMPONENTES ---
    static let iconButtonSize: CGFloat = 52
    static let cornerRadius: CGFloat = 15
    static let padding: CGFloat = 16
    static let ticketHeight: CGFloat = 170       // Altura universal dos tickets premium
    static let actionCardHeight: CGFloat = 100   // Altura dos botões rápidos
    
    // --- MÉTRICAS DE SCROLL ---
    static let scrollIndicatorWidth: CGFloat = 40
    static let scrollIndicatorHeight: CGFloat = 6
    static let actionSpacing: CGFloat = 20
    
    // --- MÉTRICAS DE BORDAS (REGRAS UNIVERSAIS) ---
    static let UNIVERSAL_ACTIVE_BORDER_WIDTH: CGFloat = 3.0
    static let inactiveBorderWidth: CGFloat = 0.5
    
    // --- NAVEGAÇÃO UNIVERSAL (SETAS) ---
    static let universalBackIcon: String = "chevron.left"
    static let universalBackIconSize: CGFloat = 22
    static let universalBackIconWeight: Font.Weight = .semibold
    
    // --- MÉTRICAS DE FORMULÁRIOS (REGRAS UNIVERSAIS) ---
    static let FORM_FIELD_HEIGHT: CGFloat = 56
    static let FORM_FIELD_HPADDING: CGFloat = 16
    static let FORM_LABEL_FONT_SIZE: CGFloat = 11
    static let FORM_VALUE_FONT_SIZE: CGFloat = 14
    static let FORM_LABEL_WEIGHT: Font.Weight = .bold
    static let FORM_VALUE_WEIGHT: Font.Weight = .regular
    static var FORM_LABEL_COLOR: Color { GlpiColors.dynamicText.opacity(0.5) }
    static var FORM_PLACEHOLDER_COLOR: Color { GlpiColors.dynamicBlueText }
    
    // --- COMPONENTES DE SELEÇÃO ---
    static let FORM_CHEVRON_SIZE: CGFloat = 13
    static let FORM_CHEVRON_WEIGHT: Font.Weight = .bold
    static let FORM_CHEVRON_OPACITY: Double = 0.7
    static let FORM_DELETE_ICON_SIZE: CGFloat = 18
    static let FORM_ANIMATION: Animation = .spring()
}

struct PremiumBackgroundView: View {
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    var body: some View {
        ZStack {
            if isLightMode {
                Color.white.ignoresSafeArea()
            } else {
                GlpiColors.deepPremiumBlue.ignoresSafeArea()
            }
        }
    }
}

// Facilitador para usar Color(hex: "...") fora da struct
extension Color {
    init(hexString: String) {
        self = GlpiColors.hex(hexString)
    }
}
extension View {
    /// Aplica o azul elétrico universal sólido como cor de primeiro plano (foreground)
    func universalGradientForeground() -> some View {
        self.foregroundColor(GlpiColors.universalBlue)
    }
    
    // Estilo de Vidro Radicalmente Transparente (ESTRUTURA ORIGINAL)
    func glassStyle(cornerRadius: CGFloat = 16, isSelection: Bool = false, selectionColor: Color = GlpiColors.universalBlue, useWhiteBackground: Bool = false) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius, isSelection: isSelection, selectionColor: selectionColor, useWhiteBackground: useWhiteBackground))
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
    
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            ZStack(alignment: alignment) {
                placeholder().opacity(shouldShow ? 1 : 0)
                self
            }
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
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.amiko(size: 12, weight: .black))
                .foregroundColor(isSelected ? .white : GlpiColors.dynamicText.opacity(0.4))
                .padding(.horizontal, width == nil ? 16 : 4)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: width, height: 44)
                .background(
                    Capsule()
                        .fill(isSelected ? GlpiColors.universalBlue : GlpiColors.dynamicOffWhite)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? GlpiColors.universalBlue : GlpiColors.dynamicBorder,
                            lineWidth: isSelected ? GlpiMetrics.UNIVERSAL_ACTIVE_BORDER_WIDTH : GlpiMetrics.inactiveBorderWidth
                        )
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
    var isSystemIcon: Bool = true
    var activeIcon: String? = nil
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if isSystemIcon {
                Image(systemName: isFocused ? (activeIcon ?? icon) : icon)
                    .foregroundColor(isFocused ? GlpiColors.universalBlue : GlpiColors.dynamicText.opacity(0.6))
                    .font(.system(size: 16, weight: isFocused ? .bold : .regular))
                    .frame(width: 20)
            } else {
                // Suporte para imagens personalizadas (ex: pessoa e pessoa2)
                Image(isFocused ? (activeIcon ?? icon) : icon)
                    .resizable()
                    .renderingMode(.template) // Permite mudar a cor conforme o foco
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(isFocused ? GlpiColors.universalBlue : GlpiColors.dynamicText.opacity(0.6))
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.amiko(size: 16))
                    .foregroundColor(GlpiColors.dynamicText)
                    .focused($isFocused)
                    .tint(GlpiColors.universalBlue)
            } else {
                TextField(placeholder, text: $text)
                    .font(.amiko(size: 16))
                    .foregroundColor(GlpiColors.dynamicText)
                    .autocapitalization(.none)
                    .focused($isFocused)
                    .tint(GlpiColors.universalBlue)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .glassStyle(cornerRadius: 16, isSelection: isFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
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
    var color: Color = GlpiColors.universalBlue
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
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(height: 12, alignment: .center)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: GlpiMetrics.actionCardHeight)
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
    var isSelected: Bool = false
    var action: () -> Void
    
    init(label: String, value: String, icon: String, valueColor: Color? = nil, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                .padding(.leading, 5)
            
            Button(action: action) {
                let finalValueColor = valueColor ?? .white
                
                return HStack(spacing: 0) {
                    if !icon.isEmpty {
                        Image(systemName: icon)
                            .foregroundColor(GlpiColors.dynamicText)
                            .font(.system(size: 16))
                            .frame(width: 24)
                            .padding(.trailing, 10)
                    }
                    
                    Text(value)
                        .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                        .foregroundColor(finalValueColor == .white ? GlpiColors.dynamicText : finalValueColor)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: GlpiMetrics.FORM_CHEVRON_SIZE, weight: GlpiMetrics.FORM_CHEVRON_WEIGHT))
                        .foregroundColor(GlpiColors.universalBlue.opacity(GlpiMetrics.FORM_CHEVRON_OPACITY))
                        .rotationEffect(.degrees(isSelected ? 180 : 0))
                }
                .padding(.horizontal, GlpiMetrics.FORM_FIELD_HPADDING)
                .frame(height: GlpiMetrics.FORM_FIELD_HEIGHT)
                .glassStyle(cornerRadius: 22, isSelection: isSelected)
            }
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
                    .foregroundColor(isSelected ? GlpiColors.dynamicText : GlpiColors.dynamicText.opacity(0.6))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(GlpiColors.universalBlue)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(isSelected ? GlpiColors.dynamicOffWhite : Color.clear)
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
    var color: Color = GlpiColors.universalBlue
    let trigger: Int
    var action: () -> Void = {}
    
    @State private var displayValue: Int = 0
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            VStack(alignment: .center, spacing: 6) {
                Text("\(displayValue)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundColor(GlpiColors.universalBlue)
                
                Text(title)
                    .font(.amiko(size: 10, weight: .black))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .glassStyle(cornerRadius: 22)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            runCountAnimation()
        }
        .onChange(of: trigger) { _, _ in
            runCountAnimation()
        }
        .onChange(of: value) { _, _ in
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
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * interval)) {
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
                    .foregroundColor(GlpiColors.dynamicText)
                Text(activity.desc)
                    .font(.amiko(size: 12))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(activity.status.uppercased())
                .font(.amiko(size: 9, weight: .bold))
                .frame(width: 80)
                .padding(.vertical, 4)
                .background(statusColor(activity.status).opacity(0.1))
                .foregroundColor(statusColor(activity.status))
                .clipShape(Capsule())
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "resolvido": return GlpiColors.dynamicText.opacity(0.4)
        default: return GlpiColors.dynamicBlueText
        }
    }
}

// MARK: - Glass Modifiers with Mode Support

struct GlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isSelection: Bool
    let selectionColor: Color
    var useWhiteBackground: Bool = false
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GlpiColors.dynamicOffWhite)
                    .shadow(color: isLightMode ? Color.clear : Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        isSelection ? selectionColor : (isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.15)),
                        lineWidth: isSelection ? GlpiMetrics.UNIVERSAL_ACTIVE_BORDER_WIDTH : GlpiMetrics.inactiveBorderWidth
                    )
            )
    }
}

struct PremiumGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isCapsule: Bool
    
    func body(content: Content) -> some View {
        @AppStorage("isLightMode_V2") var isLightMode = true
        return content
            .background(
                Group {
                    if isCapsule {
                        Capsule().fill(isLightMode ? Color.white : Color.black)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius).fill(isLightMode ? Color.white : Color.black)
                    }
                }
            )
            .overlay(
                Group {
                    if isCapsule {
                        Capsule().stroke(GlpiColors.dynamicBorder, lineWidth: GlpiMetrics.inactiveBorderWidth)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius).stroke(GlpiColors.dynamicBorder, lineWidth: GlpiMetrics.inactiveBorderWidth)
                    }
                }
            )
    }
}

struct TabBarGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        @AppStorage("isLightMode_V2") var isLightMode = true
        return content
            .background(
                GlpiColors.universalBlue
                    .clipShape(Capsule())
            )
            .shadow(color: Color.black.opacity(isLightMode ? 0.1 : 0.4), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Etiquetas Universais

struct GLPIBadge: View {
    let text: String
    var color: Color = GlpiColors.universalBlue
    
    var body: some View {
        Text(text.uppercased())
            .font(.amiko(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 95)
            .background(color)
            .clipShape(Capsule())
    }
}

struct GLPISearchHeader: View {
    @Binding var searchText: String
    var placeholder: String = "Pesquisar..."
    var leftIcon: String? = nil
    var leftIconAction: (() -> Void)? = nil
    var isLeftSystemIcon: Bool = true
    var rightIcon: String? = nil
    var isSystemIcon: Bool = false
    var isRightIconSelected: Bool = false
    var rightIconAction: (() -> Void)? = nil
    var innerRightIcon: String? = nil
    var innerRightIconAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Botão Opcional à Esquerda (ex: Voltar)
            if let icon = leftIcon {
                Button(action: {
                    leftIconAction?()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Group {
                        if isLeftSystemIcon {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .bold))
                        } else {
                            Image(icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .foregroundColor(GlpiColors.dynamicText)
                    .frame(width: GlpiMetrics.iconButtonSize, height: GlpiMetrics.iconButtonSize)
                    .glassStyle(cornerRadius: GlpiMetrics.cornerRadius, useWhiteBackground: true)
                }
            }
            
            // Barra de Pesquisa
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(GlpiColors.universalBlue)
                
                TextField("", text: $searchText, prompt: Text(placeholder).foregroundColor(GlpiColors.dynamicText.opacity(0.3)))
                    .foregroundColor(GlpiColors.dynamicText)
                    .font(.amiko(size: 16))
                
                if let innerIcon = innerRightIcon {
                    Button(action: {
                        innerRightIconAction?()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Image(systemName: innerIcon)
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: GlpiMetrics.headerHeight)
            .glassStyle(cornerRadius: GlpiMetrics.cornerRadius, useWhiteBackground: true)
            
            // Botão Opcional à Direita (ex: Perfil ou Filtro)
            if let icon = rightIcon {
                Button(action: {
                    rightIconAction?()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Group {
                        if isSystemIcon {
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .semibold))
                        } else {
                            Image(icon)
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .foregroundColor(isRightIconSelected ? GlpiColors.universalBlue : GlpiColors.dynamicText.opacity(0.4))
                    .frame(width: GlpiMetrics.iconButtonSize, height: GlpiMetrics.iconButtonSize)
                    .glassStyle(cornerRadius: GlpiMetrics.cornerRadius, isSelection: isRightIconSelected, useWhiteBackground: true)
                }
            }
        }
        .padding(.horizontal, GlpiMetrics.padding)
        .background(Color.clear)
    }
}

// MARK: - Contentores Universais de Scroll

struct GLPIHorizontalScrollContainer<Content: View>: View {
    let content: Content
    @State private var scrollProgress: CGFloat = 0
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                content
                    .background(
                        GeometryReader { geo in
                            let minX = geo.frame(in: .global).minX
                            Color.clear
                                .onChange(of: minX) { _, newValue in
                                    let screenWidth = UIScreen.screenWidth
                                    let totalWidth = geo.size.width
                                    let scrollableWidth = totalWidth - screenWidth
                                    
                                    if scrollableWidth > 0 {
                                        let offset = -newValue
                                        let progress = max(0, min(1, offset / scrollableWidth))
                                        scrollProgress = progress
                                    }
                                }
                        }
                    )
            }
            
            // Barra de Progresso Universal (Cápsula)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(GlpiColors.universalBlue.opacity(0.1))
                    .frame(width: GlpiMetrics.scrollIndicatorWidth, height: GlpiMetrics.scrollIndicatorHeight)
                
                Capsule()
                    .fill(GlpiColors.universalBlue)
                    .frame(width: (GlpiMetrics.scrollIndicatorWidth * 0.3) + (GlpiMetrics.scrollIndicatorWidth * 0.7 * scrollProgress), height: GlpiMetrics.scrollIndicatorHeight)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Listas Universais com Pull-to-Refresh Premium

struct GLPIList<Content: View>: View {
    let content: Content
    let refreshAction: (() async -> Void)?
    
    init(@ViewBuilder content: () -> Content, refreshAction: (() async -> Void)? = nil) {
        self.content = content()
        self.refreshAction = refreshAction
    }
    
    var body: some View {
        List {
            content
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .background(Color.clear)
        .scrollIndicators(.hidden)
        .onAppear {
            UIRefreshControl.appearance().tintColor = UIColor(GlpiColors.universalBlue)
        }
        .refreshable {
            if let action = refreshAction {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                await action()
            }
        }
    }
}

// MARK: - Componentes de Seleção e Atribuição

struct TechnicianAssignment: Identifiable, Hashable {
    let id = UUID()
    var name: String
}

struct AssignmentRowView: View {
    @Binding var assignment: TechnicianAssignment
    @FocusState.Binding var focusedId: UUID?
    let showDelete: Bool
    let suggestions: [String]
    let onDelete: () -> Void
    
    @State private var startedWithContent: Bool = false
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                // ZONA 1: Campo e Toggle Universal
                HStack(spacing: 8) {
                    TextField("", text: $assignment.name)
                        .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                        .foregroundColor(GlpiColors.dynamicText)
                        .placeholder(when: assignment.name.isEmpty && !isExpanded) {
                            Text("SELECIONAR / ESCREVER")
                                .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                                .foregroundColor(GlpiMetrics.FORM_PLACEHOLDER_COLOR)
                        }
                        .focused($focusedId, equals: assignment.id)
                        .tint(GlpiColors.universalBlue)
                    
                    Spacer()
                }
                .padding(.leading, GlpiMetrics.FORM_FIELD_HPADDING)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture().onEnded {
                        withAnimation(GlpiMetrics.FORM_ANIMATION) {
                            if focusedId == assignment.id {
                                focusedId = nil
                                hideKeyboard()
                            } else {
                                focusedId = assignment.id
                            }
                        }
                    }
                )
                
                // ZONA 2: Botões de Ação e Seta
                HStack(spacing: 12) {
                    if showDelete {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onDelete()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: GlpiMetrics.FORM_DELETE_ICON_SIZE, weight: .bold))
                                .foregroundColor(GlpiColors.deleteRed)
                                .shadow(color: GlpiColors.deleteRed.opacity(0.3), radius: 6)
                        }
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: GlpiMetrics.FORM_CHEVRON_SIZE, weight: GlpiMetrics.FORM_CHEVRON_WEIGHT))
                        .foregroundColor(GlpiColors.universalBlue.opacity(GlpiMetrics.FORM_CHEVRON_OPACITY))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .onTapGesture {
                            withAnimation(GlpiMetrics.FORM_ANIMATION) {
                                if focusedId == assignment.id {
                                    focusedId = nil
                                    hideKeyboard()
                                } else {
                                    focusedId = assignment.id
                                }
                            }
                        }
                }
                .padding(.trailing, GlpiMetrics.FORM_FIELD_HPADDING)
                .padding(.leading, 8)
                .frame(maxHeight: .infinity)
            }
            .frame(height: GlpiMetrics.FORM_FIELD_HEIGHT)
            .glassStyle(cornerRadius: 22, isSelection: isExpanded)
            .onChange(of: focusedId) { oldValue, newValue in
                let shouldExpand = (newValue == assignment.id)
                withAnimation(GlpiMetrics.FORM_ANIMATION) {
                    isExpanded = shouldExpand
                }
                
                // Limpeza Automática: Se perdeu o foco e está vazio (e não é o único), removemos
                if oldValue == assignment.id && newValue != assignment.id && assignment.name.isEmpty && showDelete {
                    onDelete()
                }
                
                if shouldExpand {
                    startedWithContent = !assignment.name.isEmpty
                }
            }
            
            // SUGESTÕES
            if focusedId == assignment.id && (!suggestions.isEmpty || !assignment.name.isEmpty) {
                ScrollablePickerView(
                    options: suggestions,
                    selected: $assignment.name,
                    onSelect: {
                        focusedId = nil
                        hideKeyboard()
                    },
                    showNone: startedWithContent
                )
                .glassStyle(cornerRadius: 22)
                .padding(.top, -5)
            }
        }
    }
}
