
import SwiftUI

struct AssetHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    
    let mockHistory = [
        (device: "MacBook Pro M3", date: "24/04/2026", action: "Atribuído", user: "Gonçalo Sousa", desc: "Equipamento entregue para trabalho remoto."),
        (device: "Dell UltraSharp", date: "15/03/2026", action: "Manutenção", user: "Suporte Técnico", desc: "Limpeza interna e upgrade de RAM."),
        (device: "iPhone 15 Pro", date: "10/01/2026", action: "Novo", user: "Stock", desc: "Entrada em stock via fornecedor."),
        (device: "Lenovo ThinkPad", date: "05/01/2026", action: "Reparação", user: "Ana Martins", desc: "Troca de teclado e limpeza.")
    ]
    
    var filteredHistory: [(device: String, date: String, action: String, user: String, desc: String)] {
        if searchText.isEmpty { return mockHistory }
        return mockHistory.filter { $0.device.localizedCaseInsensitiveContains(searchText) || $0.desc.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(12)
                            .glassStyle(cornerRadius: 18)
                    }
                    Spacer()
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 15)
                
                // Barra de Pesquisa Universal
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    TextField("", text: $searchText, prompt: 
                        Text("Pesquisar no histórico...")
                            .foregroundColor(.white.opacity(0.3))
                            .font(.amiko(size: 14))
                    )
                    .font(.amiko(size: 14))
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 15)
                .frame(height: 54)
                .glassStyle(cornerRadius: 15)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ForEach(0..<filteredHistory.count, id: \.self) { index in
                            let item = filteredHistory[index]
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.device)
                                            .font(.amiko(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(item.date)
                                            .font(.amiko(size: 12))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    Spacer()
                                    Text(item.action.uppercased())
                                        .font(.amiko(size: 10, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.1))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                Divider().background(Color.white.opacity(0.05))
                                
                                Text(item.desc)
                                    .font(.amiko(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(2)
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 10))
                                    Text(item.user)
                                        .font(.amiko(size: 12))
                                    Spacer()
                                }
                                .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(18)
                            .glassStyle(cornerRadius: 22)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
            }
        }
    }
}

#Preview {
    AssetHistoryView()
}
