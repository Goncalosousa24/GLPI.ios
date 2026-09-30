import SwiftUI

struct DeviceQuickActionsOverlay: View {
    let asset: Asset
    let onDismiss: () -> Void
    var onReport: () -> Void
    var onHistory: () -> Void
    var onChangeState: () -> Void
    var onNetworkPorts: (() -> Void)? = nil
    var showReportOption: Bool = true 
    
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    var body: some View {
        ZStack {
            // Fundo com Dimming (Igual ao dos Tickets)
            Color.black.opacity(isLightMode ? 0.25 : 0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 20) {
                // 1. RÉPLICA DO DISPOSITIVO
                AssetRowPreview(asset: asset)
                    .padding(.horizontal, 16)
                    .allowsHitTesting(false)
                
                // 2. QUADRADO DE FUNÇÕES
                VStack(spacing: 0) {
                    if showReportOption {
                        QuickActionItem(
                            title: "REPORTAR",
                            icon: "exclamationmark.triangle.fill",
                            color: .red.opacity(0.8),
                            action: onReport
                        )
                        
                        Divider().background(GlpiColors.dynamicText.opacity(0.05)).padding(.horizontal, 20)
                    }
                    
                    QuickActionItem(
                        title: "HISTÓRICO",
                        icon: "clock.arrow.circlepath",
                        color: GlpiColors.dynamicText.opacity(0.8),
                        action: onHistory
                    )
                    
                    Divider().background(GlpiColors.dynamicText.opacity(0.05)).padding(.horizontal, 20)
                    
                    QuickActionItem(
                        title: "ALTERAR ESTADO",
                        icon: "arrow.triangle.2.circlepath",
                        color: GlpiColors.universalBlue,
                        action: onChangeState
                    )
                    
                    if asset.type == .network {
                        Divider().background(GlpiColors.dynamicText.opacity(0.05)).padding(.horizontal, 20)
                        
                        QuickActionItem(
                            title: "PORTAS DE REDE",
                            icon: "network",
                            color: GlpiColors.universalBlue,
                            action: { onNetworkPorts?() }
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(GlpiColors.dynamicOffWhite)
                        .shadow(color: isLightMode ? Color.black.opacity(0.06) : Color.clear, radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .strokeBorder(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.15), lineWidth: GlpiMetrics.inactiveBorderWidth)
                )
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 50)
            .offset(y: 50) // Desce o menu um pouco conforme pedido
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
        .zIndex(999)
    }
}

// Uma versão do AssetRow para o Preview do Overlay
struct AssetRowPreview: View {
    let asset: Asset
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(asset.name.uppercased())
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(isLightMode ? GlpiColors.universalBlue : .white)
            
            Text(asset.owner?.uppercased() ?? "NÃO ATRIBUÍDO")
                .font(.amiko(size: 12, weight: .black))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
            
            Divider().background(GlpiColors.dynamicText.opacity(0.05))
            
            HStack(alignment: .top, spacing: 0) {
                InfoColumn(label: "TIPO", value: asset.type.displayName.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                InfoColumn(label: "DEPARTAMENTO", value: asset.department?.uppercased() ?? "GERAL")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                InfoColumn(label: "S/N", value: asset.serialNumber.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(height: GlpiMetrics.ticketHeight)
        .background(GlpiColors.dynamicOffWhite)
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.15), lineWidth: GlpiMetrics.inactiveBorderWidth)
        )
    }
}

struct DeviceQuickActionsOverlay_Previews: PreviewProvider {
    static var previews: some View {
        DeviceQuickActionsOverlay(
            asset: Asset(
                realId: 1,
                name: "PC-INFO-01",
                tag: "TAG123",
                icon: "desktopcomputer",
                type: .computer,
                status: "Ativo",
                owner: "Gonçalo Sousa",
                department: "Informática",
                serialNumber: "SN123456"
            ),
            onDismiss: {},
            onReport: {},
            onHistory: {},
            onChangeState: {},
            onNetworkPorts: {}
        )
    }
}
