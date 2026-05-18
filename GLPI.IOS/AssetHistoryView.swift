import SwiftUI

struct AssetHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    @State private var searchText = ""
    
    let mockHistory = [
        (device: "MacBook Pro M3", id: "1024", action: "Atribuído", user: "Gonçalo Sousa", desc: "Equipamento entregue para trabalho remoto."),
        (device: "Dell UltraSharp", id: "852", action: "Manutenção", user: "Suporte Técnico", desc: "Limpeza interna e upgrade de RAM."),
        (device: "iPhone 15 Pro", id: "941", action: "Novo", user: "Stock", desc: "Entrada em stock via fornecedor."),
        (device: "Lenovo ThinkPad", id: "732", action: "Reparação", user: "Ana Martins", desc: "Troca de teclado e limpeza.")
    ]
    
    var filteredHistory: [(device: String, id: String, action: String, user: String, desc: String)] {
        if searchText.isEmpty { return mockHistory }
        return mockHistory.filter { $0.device.localizedCaseInsensitiveContains(searchText) || $0.desc.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss { hideKeyboard() }
            
            VStack(spacing: 0) {
                headerView
                
                // 1. Pesquisa (Standard)
                GLPISearchHeader(
                    searchText: $searchText,
                    placeholder: "Pesquisar no histórico..."
                )
                .padding(.top, 5)
                .padding(.bottom, 10)
                
                // 2. Lista de Histórico
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 15) {
                        ScrollOffsetTracker()
                        
                        VStack(spacing: 12) {
                            ForEach(0..<filteredHistory.count, id: \.self) { index in
                                let item = filteredHistory[index]
                                HistoryRow(item: item)
                            }
                        }
                        .padding(.horizontal, GlpiMetrics.padding)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 60)
                }
            }
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: GlpiMetrics.universalBackIcon)
                    .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                    .foregroundColor(GlpiColors.dynamicText)
            }
            .padding(.leading, GlpiMetrics.padding + 5)
            
            Spacer()
            
            Text("HISTÓRICO")
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicBlueText)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 5)
        .frame(height: GlpiMetrics.navAreaHeight - 5)
    }
}

struct HistoryRow: View {
    let item: (device: String, id: String, action: String, user: String, desc: String)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // 1. Nome do Dispositivo (Azul)
                Text(item.device.uppercased())
                    .font(.amiko(size: 15, weight: .black))
                    .foregroundColor(GlpiColors.dynamicBlueText)
                
                // 2. Nome do Utilizador
                Text(item.user.uppercased())
                    .font(.amiko(size: 12, weight: .black))
                    .foregroundColor(GlpiColors.dynamicText)
                
                // 3. Título do Ticket (Maiúsculas)
                Text(item.desc.uppercased())
                    .font(.amiko(size: 11, weight: .bold))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
                    .lineLimit(2)
            }
            
            // ID do Ticket à direita (Azul, sem #)
            HStack {
                Spacer()
                Text(item.id)
                    .font(.inconsolata(size: 12, weight: .bold))
                    .foregroundColor(GlpiColors.universalBlue)
            }
        }
        .padding(20)
        .glassStyle(cornerRadius: 22)
    }
}

#Preview {
    AssetHistoryView()
}

#Preview {
    AssetHistoryView()
}
