import SwiftUI

struct AssetReportView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    // Estados para o Reporte
    @State private var numeroSerie: String = ""
    @State private var categoria: String = ""
    @State private var localizacao: String = ""
    @State private var motivo: String = ""
    @State private var motivoPersonalizado: String = ""
    @State private var descricao: String = ""
    
    // Foco para bordas azuis
    enum Field: Hashable {
        case sn, customReason, description
    }
    @FocusState private var focusedField: Field?
    
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
    
    @State private var showScanner: Bool = false
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss {
                    withAnimation(.spring()) {
                        closeOtherPickers(except: "")
                        focusedField = nil
                    }
                }
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // 1. NÚMERO DE SÉRIE
                        inputField(
                            label: "ESCREVER SN / SCAN", 
                            text: $numeroSerie, 
                            placeholder: "INSERIR SN", 
                            focus: .sn,
                            rightIcon: "qrcode.viewfinder",
                            rightIconAction: { showScanner = true }
                        )
                        
                        // 2. CATEGORIA DO EQUIPAMENTO
                        VStack(spacing: 8) {
                            EditFieldCapsule(
                                label: "CATEGORIA DO EQUIPAMENTO", 
                                value: categoria.isEmpty ? "SELECIONAR" : categoria, 
                                icon: "", 
                                valueColor: categoria.isEmpty ? GlpiColors.dynamicBlueText : nil,
                                isSelected: isCategoriaExpanded
                            ) {
                                withAnimation(.spring()) {
                                    isCategoriaExpanded.toggle()
                                    closeOtherPickers(except: "categoria")
                                }
                            }
                            
                            if isCategoriaExpanded {
                                ScrollablePickerView(
                                    options: categorias,
                                    selected: $categoria,
                                    onSelect: { withAnimation { isCategoriaExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 3. LOCALIZAÇÃO
                        VStack(spacing: 8) {
                            EditFieldCapsule(
                                label: "LOCALIZAÇÃO", 
                                value: localizacao.isEmpty ? "SELECIONAR" : localizacao, 
                                icon: "", 
                                valueColor: localizacao.isEmpty ? GlpiColors.dynamicBlueText : nil,
                                isSelected: isLocalExpanded
                            ) {
                                withAnimation(.spring()) {
                                    isLocalExpanded.toggle()
                                    closeOtherPickers(except: "local")
                                }
                            }
                            
                            if isLocalExpanded {
                                ScrollablePickerView(
                                    options: locais,
                                    selected: $localizacao,
                                    onSelect: { withAnimation { isLocalExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 4. MOTIVO DO PROBLEMA
                        VStack(spacing: 8) {
                            EditFieldCapsule(
                                label: "MOTIVO DO PROBLEMA", 
                                value: motivo.isEmpty ? "SELECIONAR" : motivo, 
                                icon: "", 
                                valueColor: motivo.isEmpty ? GlpiColors.dynamicBlueText : nil,
                                isSelected: isMotivoExpanded
                            ) {
                                withAnimation(.spring()) {
                                    isMotivoExpanded.toggle()
                                    closeOtherPickers(except: "motivo")
                                }
                            }
                            
                            if isMotivoExpanded {
                                ScrollablePickerView(
                                    options: motivosComuns,
                                    selected: $motivo,
                                    onSelect: { withAnimation { isMotivoExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // Campo extra para motivo personalizado
                        if motivo == "Outro..." {
                            inputField(label: "ESPECIFIQUE O MOTIVO", text: $motivoPersonalizado, placeholder: "DESCREVER MOTIVO", focus: .customReason)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // 5. DESCRIÇÃO DETALHADA
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DESCRIÇÃO DETALHADA")
                                .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                                .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                                .padding(.leading, 5)
                            
                            ZStack(alignment: .topLeading) {
                                if descricao.isEmpty && focusedField != .description {
                                    Text("DESCREVA O PROBLEMA EM DETALHE...")
                                        .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                                        .foregroundColor(GlpiMetrics.FORM_PLACEHOLDER_COLOR)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                }
                                
                                TextEditor(text: $descricao)
                                    .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                                    .foregroundColor(GlpiColors.dynamicText)
                                    .frame(minHeight: 120)
                                    .padding(12)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .focused($focusedField, equals: .description)
                                    .tint(GlpiColors.universalBlue)
                            }
                            .glassStyle(cornerRadius: 22, isSelection: focusedField == .description)
                        }
                        
                        // BOTÃO REPORTAR
                        reportButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                .scrollDismissesKeyboard(.immediately)
                .simultaneousGesture(DragGesture().onChanged { _ in
                    withAnimation(.spring()) {
                        closeOtherPickers(except: "")
                        focusedField = nil
                    }
                })
            }
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
        .sheet(isPresented: $showScanner) {
            ScannerView { scannedCode in
                self.numeroSerie = scannedCode
            }
        }
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
            
            Text("REPORTAR PROBLEMA")
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicBlueText)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 5)
        .frame(height: GlpiMetrics.navAreaHeight - 5)
    }
    
    private func inputField(label: String, text: Binding<String>, placeholder: String, focus: Field, rightIcon: String? = nil, rightIconAction: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                .padding(.leading, 5)
            
            HStack(spacing: 0) {
                TextField("", text: text)
                    .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                    .foregroundColor(GlpiColors.dynamicText)
                    .placeholder(when: text.wrappedValue.isEmpty && focusedField != focus) {
                        Text(placeholder)
                            .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                            .foregroundColor(GlpiMetrics.FORM_PLACEHOLDER_COLOR)
                    }
                    .focused($focusedField, equals: focus)
                    .tint(GlpiColors.universalBlue)
                
                if let icon = rightIcon {
                    Button(action: {
                        rightIconAction?()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Image(systemName: icon)
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .padding(.horizontal, GlpiMetrics.FORM_FIELD_HPADDING)
            .frame(height: GlpiMetrics.FORM_FIELD_HEIGHT)
            .glassStyle(cornerRadius: 22, isSelection: focusedField == focus)
        }
    }
    
    private var reportButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        }) {
            Text("ENVIAR REPORTE")
                .font(.amiko(size: 15, weight: .black))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    Capsule()
                        .fill(GlpiColors.universalBlue)
                        .shadow(color: GlpiColors.universalBlue.opacity(0.4), radius: 15, y: 8)
                )
        }
        .padding(.top, 20)
        .padding(.bottom, 60)
    }
    
    private func closeOtherPickers(except: String) {
        if except != "categoria" { isCategoriaExpanded = false }
        if except != "local" { isLocalExpanded = false }
        if except != "motivo" { isMotivoExpanded = false }
        
        hideKeyboard()
    }
}

#Preview {
    AssetReportView()
}

#Preview {
    AssetReportView()
}
