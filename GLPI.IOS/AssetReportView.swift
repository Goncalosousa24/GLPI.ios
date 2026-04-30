
import SwiftUI

struct AssetReportView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Estados para o Reporte
    @State private var numeroSerie: String = ""
    @State private var categoria: String = ""
    @State private var localizacao: String = ""
    @State private var motivo: String = ""
    @State private var motivoPersonalizado: String = ""
    @State private var descricao: String = ""
    
    // Estados de Expansão
    @State private var isCategoriaExpanded: Bool = false
    @State private var isLocalExpanded: Bool = false
    @State private var isMotivoExpanded: Bool = false
    
    let categorias = ["Computador", "Monitor", "Rede", "Impressora"]
    let locais = [
        "Biblioteca", "Casa do Conhecimento", "DAEF", "DAF", "DAO", "DAS", "DE", "DJ", "DOT", "DPO", "DPS",
        "  ↳ Ação Social", "  ↳ Complexo Lazer V. Verde", "  ↳ CPCJ", "  ↳ GIF", "  ↳ Loja Social", "  ↳ Piscinas de Prado", "  ↳ SQIP",
        "DRH", "DSI", "  ↳ Arquivo", "  ↳ Sala Bastidores", "  ↳ Arrumos Informática", "DUE", "EC Prado", "EXE",
        "  ↳ GRP", "Stock", "  ↳ Red Tagged", "UCP", "UCT", "UIC", "  ↳ Casa do Conhecimento", "UMAQ"
    ]
    let motivosComuns = ["Não liga", "Ecrã partido", "Lento / Bloqueia", "Erro de Software", "Problema de Rede", "Outro..."]
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            // Camada de fecho
            if isCategoriaExpanded || isLocalExpanded || isMotivoExpanded {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isCategoriaExpanded = false
                            isLocalExpanded = false
                            isMotivoExpanded = false
                        }
                    }
            }
            
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
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // 1. NÚMERO DE SÉRIE
                        HStack(spacing: 15) {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 16))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NÚMERO DE SÉRIE")
                                    .font(.amiko(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                TextField("", text: $numeroSerie, prompt: Text("").foregroundColor(.white.opacity(0.3)))
                                    .font(.amiko(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .glassStyle(cornerRadius: 22)
                        
                        // 2. CATEGORIA
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "CATEGORIA DO EQUIPAMENTO", value: categoria, icon: "square.grid.2x2.fill") {
                                withAnimation(.spring()) {
                                    isCategoriaExpanded.toggle()
                                    if isCategoriaExpanded {
                                        isLocalExpanded = false
                                        isMotivoExpanded = false
                                    }
                                }
                            }
                            
                            if isCategoriaExpanded {
                                VStack(spacing: 4) {
                                    ForEach(categorias, id: \.self) { cat in
                                        OptionRow(title: cat, isSelected: categoria == cat) {
                                            categoria = cat
                                            withAnimation { isCategoriaExpanded = false }
                                        }
                                    }
                                }
                                .padding(8)
                                .glassStyle(cornerRadius: 22)
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        
                        // 3. LOCALIZAÇÃO
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "LOCALIZAÇÃO", value: localizacao, icon: "mappin.and.ellipse") {
                                withAnimation(.spring()) {
                                    isLocalExpanded.toggle()
                                    if isLocalExpanded {
                                        isCategoriaExpanded = false
                                        isMotivoExpanded = false
                                    }
                                }
                            }
                            
                            if isLocalExpanded {
                                ScrollablePickerView(
                                    options: locais,
                                    selected: $localizacao,
                                    onSelect: { withAnimation { isLocalExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        
                        // 4. MOTIVO DO PROBLEMA
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "MOTIVO DO PROBLEMA", value: motivo, icon: "exclamationmark.triangle.fill") {
                                withAnimation(.spring()) {
                                    isMotivoExpanded.toggle()
                                    if isMotivoExpanded {
                                        isCategoriaExpanded = false
                                        isLocalExpanded = false
                                    }
                                }
                            }
                            
                            if isMotivoExpanded {
                                ScrollablePickerView(
                                    options: motivosComuns,
                                    selected: $motivo,
                                    onSelect: { withAnimation { isMotivoExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        
                        // Campo extra para motivo personalizado
                        if motivo == "Outro..." {
                            HStack(spacing: 15) {
                                Image(systemName: "pencil.line")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.system(size: 16))
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ESPECIFIQUE O MOTIVO")
                                        .font(.amiko(size: 9, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    TextField("", text: $motivoPersonalizado, prompt: Text("").foregroundColor(.white.opacity(0.3)))
                                        .font(.amiko(size: 15))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .glassStyle(cornerRadius: 22)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // 5. DESCRIÇÃO DETALHADA
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESCRIÇÃO DETALHADA")
                                .font(.amiko(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 16)
                            
                            TextEditor(text: $descricao)
                                .frame(minHeight: 120)
                                .padding(12)
                                .font(.amiko(size: 14))
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .glassStyle(cornerRadius: 22)
                        }
                        
                        // BOTÃO REPORTAR
                        Button(action: { dismiss() }) {
                            Text("ENVIAR REPORTE")
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 240, height: 52)
                                .glassStyle(cornerRadius: 22)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 60)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
        }
    }
}

#Preview {
    AssetReportView()
}
