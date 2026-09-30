//
//  InventoryLocationFilterOverlay.swift
//  GLPI.IOS
//

import SwiftUI

struct InventoryLocationFilterOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedLocation: String?
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    @State private var contentOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    
    private let locations: [String] = [
        "Todas as Localizações",
        "Biblioteca", 
        "Casa do Conhecimento", 
        "DAEF", 
        "DAF", 
        "DAO", 
        "DAS", 
        "DE", 
        "DJ", 
        "DOT", 
        "DPO", 
        "DPS",
        "DPS - Ação Social",
        "DPS - Complexo Lazer V. Verde",
        "DPS - CPCJ",
        "DPS - GIF",
        "DPS - Loja Social",
        "DPS - Piscinas de Prado",
        "DPS - SQIP",
        "DRH", 
        "DSI",
        "DSI - Arquivo",
        "DSI - Sala Bastidores",
        "DSI - Arrumos Informática",
        "DUE", 
        "EC Prado", 
        "EXE",
        "EXE - GRP",
        "Stock",
        "Stock - Red Tagged",
        "UCP", 
        "UCT", 
        "UIC",
        "UIC - Casa do Conhecimento",
        "UMAQ"
    ]
    
    var body: some View {
        ZStack {
            // Camada de Escurecimento do Fundo (Dimming)
            Color.black.opacity(isLightMode ? 0.25 : 0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }
            
            // Modal Retangular Flutuante Centralizado
            VStack(alignment: .leading, spacing: 0) {
                // Título Centrado (Sem linha divisória)
                HStack {
                    Spacer()
                    Text("Filtrar por Localização")
                        .font(.amiko(size: 16, weight: .bold))
                        .foregroundColor(isLightMode ? .black : .white)
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                // ScrollView com Scrollbar Customizado
                ZStack(alignment: .trailing) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(locations, id: \.self) { location in
                                let currentLoc = selectedLocation ?? "Todas as Localizações"
                                filterMenuItem(title: location, isSelected: currentLoc == location) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if location == "Todas as Localizações" {
                                            selectedLocation = nil
                                        } else {
                                            selectedLocation = location
                                        }
                                        isPresented = false
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .overlay(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: FilterOffsetKey.self,
                                    value: proxy.frame(in: .named("filterScroll")).minY
                                )
                            },
                            alignment: .top
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: FilterContentHeightKey.self,
                                    value: geo.size.height
                                )
                            }
                        )
                    }
                    .coordinateSpace(name: "filterScroll")
                    .onPreferenceChange(FilterOffsetKey.self) { value in
                        contentOffset = max(0, -value)
                    }
                    .onPreferenceChange(FilterContentHeightKey.self) { value in
                        if value > 0 { contentHeight = value }
                    }
                    
                    // Barra do Scroll Customizada com o Azul Típico da App
                    if contentHeight > 190 {
                        let insetTop: CGFloat = 4
                        let insetBottom: CGFloat = 4
                        let available = 190 - insetTop - insetBottom
                        let barH = max(30, (190 / contentHeight) * available)
                        let maxScroll = contentHeight - 190
                        let travel = available - barH
                        let progress = min(max(contentOffset / maxScroll, 0), 1)
                        
                        Capsule()
                            .fill(GlpiColors.universalBlue)
                            .frame(width: 4, height: barH)
                            .padding(.trailing, 6)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, insetTop + progress * travel)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 190)
                
                Spacer().frame(height: 15)
            }
            .frame(height: 260)
            .background(isLightMode ? Color.white : Color(hexString: "1C1C1E"))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(GlpiColors.dynamicBorder, lineWidth: 1)
            )
            .padding(.horizontal, GlpiMetrics.padding)
            .shadow(color: Color.black.opacity(isLightMode ? 0.15 : 0.45), radius: 25, x: 0, y: 10)
            .transition(.scale.combined(with: .opacity))
        }
        .zIndex(15)
    }
    
    private func filterMenuItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.amiko(size: 15, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isLightMode ? .black : .white.opacity(0.8)))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? GlpiColors.universalBlue : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(NoHighlightButtonStyle())
        .padding(.horizontal, 12)
    }
}

// PreferenceKeys para Scroll Tracking
private struct FilterOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct FilterContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
