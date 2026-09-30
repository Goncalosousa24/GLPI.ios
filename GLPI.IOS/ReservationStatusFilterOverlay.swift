//
//  ReservationStatusFilterOverlay.swift
//  GLPI.IOS
//

import SwiftUI

struct ReservationStatusFilterOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedStatus: String
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    @State private var contentOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    
    private let statuses = [
        "Geral",
        "Livres",
        "Reservados"
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
                // Título Centrado
                HStack {
                    Spacer()
                    Text("Filtrar por Estado")
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
                            ForEach(statuses, id: \.self) { status in
                                filterMenuItem(title: status, isSelected: selectedStatus.lowercased() == status.lowercased()) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedStatus = status
                                        isPresented = false
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .overlay(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: ReservationFilterOffsetKey.self,
                                    value: proxy.frame(in: .named("reservationFilterScroll")).minY
                                )
                            },
                            alignment: .top
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ReservationFilterContentHeightKey.self,
                                    value: geo.size.height
                                )
                            }
                        )
                    }
                    .coordinateSpace(name: "reservationFilterScroll")
                    .onPreferenceChange(ReservationFilterOffsetKey.self) { value in
                        contentOffset = max(0, -value)
                    }
                    .onPreferenceChange(ReservationFilterContentHeightKey.self) { value in
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
                .frame(height: 155) // Reduced from 190
                
                Spacer().frame(height: 15)
            }
            .frame(height: 220) // Reduced from 260
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
private struct ReservationFilterOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ReservationFilterContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
