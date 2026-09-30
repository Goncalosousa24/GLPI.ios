//
//  DeviceStateChangeOverlay.swift
//  GLPI.IOS
//

import SwiftUI

struct GLPIDeviceState: Identifiable {
    let id: String
    let name: String
}

struct DeviceStateChangeOverlay: View {
    let asset: Asset
    @Binding var isPresented: Bool
    var onStateChanged: (() -> Void)? = nil
    
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    @State private var states: [GLPIDeviceState] = []
    @State private var isLoading = true
    @State private var contentOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    
    // Simular carregamento e alteração
    @State private var isApplying = false
    
    // Alerta nativo de confirmação
    @State private var showConfirmAlert = false
    @State private var stateToConfirm: GLPIDeviceState? = nil
    
    var body: some View {
        ZStack {
            // Escurecimento
            Color.black.opacity(isLightMode ? 0.25 : 0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isApplying {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isPresented = false
                        }
                    }
                }
            
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Alterar Estado")
                        .font(.amiko(size: 16, weight: .bold))
                        .foregroundColor(isLightMode ? .black : .white)
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                            .scaleEffect(1.2)
                        Spacer()
                    }
                    .frame(height: 190)
                } else if isApplying {
                    VStack(spacing: 15) {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                            .scaleEffect(1.5)
                        Text("A atualizar estado...")
                            .font(.amiko(size: 12, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.6))
                        Spacer()
                    }
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                } else {
                    ZStack(alignment: .trailing) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 4) {
                                ForEach(states) { state in
                                    let isSelected = (asset.status.isEmpty && state.name == "Nenhum") || asset.status.caseInsensitiveCompare(state.name) == .orderedSame
                                    stateMenuItem(title: state.name, isSelected: isSelected) {
                                        if !isSelected {
                                            stateToConfirm = state
                                            showConfirmAlert = true
                                        } else {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isPresented = false
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .overlay(
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: DeviceStateFilterOffsetKey.self,
                                        value: proxy.frame(in: .named("stateFilterScroll")).minY
                                    )
                                },
                                alignment: .top
                            )
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: DeviceStateFilterContentHeightKey.self,
                                        value: geo.size.height
                                    )
                                }
                            )
                        }
                        .coordinateSpace(name: "stateFilterScroll")
                        .onPreferenceChange(DeviceStateFilterOffsetKey.self) { value in
                            contentOffset = max(0, -value)
                        }
                        .onPreferenceChange(DeviceStateFilterContentHeightKey.self) { value in
                            if value > 0 { contentHeight = value }
                        }
                        
                        // Scrollbar Customizada
                        if contentHeight > 190 {
                            let insetTop: CGFloat = 4
                            let insetBottom: CGFloat = 4
                            let available = 190 - insetTop - insetBottom
                            let barH = max(30, (190 / contentHeight) * available)
                            let maxScroll = contentHeight - 190
                            let travel = available - barH
                            let progress = maxScroll > 0 ? min(max(contentOffset / maxScroll, 0), 1) : 0
                            
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
                }
                
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
        .onAppear {
            fetchStates()
        }
        .alert("Confirmar Alteração", isPresented: $showConfirmAlert, presenting: stateToConfirm) { state in
            Button("Cancelar", role: .cancel) {
                stateToConfirm = nil
            }
            Button("Confirmar", role: .none) {
                applyState(state)
            }
        } message: { state in
            Text("Tem a certeza que pretende alterar o estado do dispositivo para '\(state.name)'?")
        }
    }
    
    private func fetchStates() {
        Task {
            do {
                let fetchedStates = try await GLPIClient.shared.getStates()
                let mappedStates = fetchedStates.map { GLPIDeviceState(id: $0.id, name: $0.name) }
                await MainActor.run {
                    self.states = [GLPIDeviceState(id: "0", name: "Nenhum")] + mappedStates
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    // Tratar erro se necessário
                }
            }
        }
    }
    
    private func mapAssetTypeToItemtype(_ type: AssetType) -> String {
        switch type {
        case .computer: return "Computer"
        case .monitor: return "Monitor"
        case .printer: return "Printer"
        case .network: return "NetworkEquipment"
        }
    }
    
    private func applyState(_ state: GLPIDeviceState) {
        if asset.status.caseInsensitiveCompare(state.name) == .orderedSame {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPresented = false
            }
            return
        }
        
        isApplying = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task {
            do {
                if !PreferenceManager.shared.isOfflineMode {
                    let input: [String: Any] = [
                        "states_id": Int(state.id) ?? 0
                    ]
                    let itemtype = mapAssetTypeToItemtype(asset.type)
                    _ = try await GLPIClient.shared.updateDevice(itemtype: itemtype, id: asset.realId, input: input)
                } else {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                await MainActor.run {
                    isApplying = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                    onStateChanged?()
                }
            } catch {
                await MainActor.run {
                    isApplying = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func stateMenuItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

private struct DeviceStateFilterOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
private struct DeviceStateFilterContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
