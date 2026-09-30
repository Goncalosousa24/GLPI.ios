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
    @State private var isAutofilling: Bool = false
    
    // Foco para bordas azuis
    enum Field: Hashable {
        case sn, customReason, description
    }
    @FocusState private var focusedField: Field?
    
    // Estados de Expansão
    @State private var isSerialExpanded: Bool = false
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
    
    // Carregamento de Seriais da API
    @State private var allSerials: [String] = []
    @State private var isLoadingSerials: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var successAlert: Bool = false
    
    // Erros inline
    @State private var snError: String? = nil
    @State private var categoriaError: String? = nil
    @State private var localizacaoError: String? = nil
    @State private var generalErrorMessage: String? = nil
    
    // Debounce Task
    @State private var searchTask: Task<Void, Never>? = nil
    
    // Asset para preenchimento automático
    var prefilledAsset: Asset? = nil
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss {
                    withAnimation(.spring()) {
                        closeOtherPickers(except: "")
                        focusedField = nil
                    }
                }
                .onAppear {
                    if let asset = prefilledAsset {
                        numeroSerie = asset.serialNumber
                        categoria = asset.type.displayName
                        if let dept = asset.department {
                            localizacao = dept
                        }
                    }
                }
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // 1. NÚMERO DE SÉRIE (SELECIONAR / ESCREVER)
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 5) {
                                inputField(
                                    label: "SELECIONAR / ESCREVER NÚMERO DE SÉRIE", 
                                    text: $numeroSerie, 
                                    placeholder: "SELECIONAR/ESCREVER", 
                                    focus: .sn,
                                    rightIcon: "qrcode.viewfinder",
                                    rightIconAction: { showScanner = true }
                                )
                                .onChange(of: numeroSerie) { newValue in
                                    onSerialChanged(newValue)
                                    snError = nil
                                }
                                .onChange(of: focusedField) { newValue in
                                    if newValue == .sn {
                                        withAnimation(.spring()) {
                                            isSerialExpanded = true
                                            closeOtherPickers(except: "serial", hideKey: false)
                                        }
                                    }
                                }
                                
                                if let snError = snError {
                                    Text(snError)
                                        .font(.amiko(size: 11, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(.leading, 15)
                                }
                            }
                            
                            // Mostrar sugestões apenas se expandido
                            if isSerialExpanded {
                                let isFullySelected = allSerials.contains(numeroSerie)
                                let filteredSerials = allSerials.filter {
                                    numeroSerie.isEmpty || isFullySelected || $0.localizedCaseInsensitiveContains(numeroSerie)
                                }
                                ScrollablePickerView(
                                    options: filteredSerials,
                                    selected: $numeroSerie,
                                    onSelect: {
                                        withAnimation { isSerialExpanded = false }
                                        focusedField = nil
                                        buscarDadosAutomaticos($numeroSerie.wrappedValue)
                                    },
                                    showNone: true
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 2. CATEGORIA DO EQUIPAMENTO (Restrita às 4)
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 5) {
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
                                
                                if let categoriaError = categoriaError {
                                    Text(categoriaError)
                                        .font(.amiko(size: 11, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(.leading, 15)
                                }
                            }
                            
                            if isCategoriaExpanded {
                                ScrollablePickerView(
                                    options: categorias,
                                    selected: $categoria,
                                    onSelect: { 
                                        categoriaError = nil
                                        withAnimation { isCategoriaExpanded = false } 
                                    },
                                    showNone: true
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 3. LOCALIZAÇÃO
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 5) {
                                EditFieldCapsule(
                                    label: "LOCALIZAÇÃO", 
                                    value: localizacao.isEmpty ? "SELECIONAR" : localizacao.trimmingCharacters(in: .whitespaces), 
                                    icon: "", 
                                    valueColor: localizacao.isEmpty ? GlpiColors.dynamicBlueText : nil,
                                    isSelected: isLocalExpanded
                                ) {
                                    withAnimation(.spring()) {
                                        isLocalExpanded.toggle()
                                        closeOtherPickers(except: "local")
                                    }
                                }
                                
                                if let localizacaoError = localizacaoError {
                                    Text(localizacaoError)
                                        .font(.amiko(size: 11, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(.leading, 15)
                                }
                            }
                            
                            if isLocalExpanded {
                                ScrollablePickerView(
                                    options: locais,
                                    selected: $localizacao,
                                    onSelect: { 
                                        localizacao = $localizacao.wrappedValue.trimmingCharacters(in: .whitespaces)
                                        localizacaoError = nil
                                        withAnimation { isLocalExpanded = false } 
                                    },
                                    showNone: true
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
                                    onSelect: { withAnimation { isMotivoExpanded = false } },
                                    showNone: true
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
                        
                        // Mensagem de Erro Geral
                        if let generalErrorMessage = generalErrorMessage {
                            Text(generalErrorMessage)
                                .font(.amiko(size: 13, weight: .bold))
                                .foregroundColor(.red)
                                .padding(15)
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        // Alerta de sucesso
                        if successAlert {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Ticket enviado!")
                                    .font(.amiko(size: 14, weight: .black))
                                    .foregroundColor(.green)
                            }
                            .padding(15)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            .transition(.scale)
                        }
                        
                        // BOTÃO REPORTAR
                        reportButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .background(isLightMode ? Color.white : Color.black)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            closeOtherPickers(except: "")
                            focusedField = nil
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .simultaneousGesture(DragGesture().onChanged { _ in
                    withAnimation(.spring()) {
                        closeOtherPickers(except: "")
                        focusedField = nil
                    }
                })
                .background(isLightMode ? Color.white : Color.black)
            }
            
            // Indicador de Carregamento/Submissão
            if isLoadingSerials || isSubmitting || isAutofilling {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        let loadingText: String = {
                            if isSubmitting { return "A enviar reporte..." }
                            if isLoadingSerials { return "A obter números de série..." }
                            return "A procurar dados do equipamento..."
                        }()
                        
                        Text(loadingText)
                            .font(.amiko(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(25)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                }
            }
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
        .sheet(isPresented: $showScanner) {
            ScannerView { scannedCode in
                self.numeroSerie = scannedCode
                buscarDadosAutomaticos(scannedCode)
            }
        }
        .onAppear {
            carregarSugestoesSeriais()
        }
    }
    
    // MARK: - Components
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: GlpiMetrics.universalBackIcon)
                    .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                    .foregroundColor(GlpiColors.universalBlue)
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
            enviarTicket()
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
        .disabled(isSubmitting)
        .padding(.top, 20)
        .padding(.bottom, 60)
    }
    
    private func closeOtherPickers(except: String, hideKey: Bool = true) {
        if except != "serial" { isSerialExpanded = false }
        if except != "categoria" { isCategoriaExpanded = false }
        if except != "local" { isLocalExpanded = false }
        if except != "motivo" { isMotivoExpanded = false }
        
        if hideKey {
            hideKeyboard()
        }
    }
    
    private func carregarSugestoesSeriais() {
        isLoadingSerials = true
        Task {
            do {
                let serials = try await GLPIClient.shared.loadAllSerialNumbers()
                await MainActor.run {
                    self.allSerials = serials
                    self.isLoadingSerials = false
                }
            } catch {
                print("Erro ao carregar números de série do sistema: \(error)")
                await MainActor.run {
                    self.isLoadingSerials = false
                }
            }
        }
    }
    
    private func onSerialChanged(_ newValue: String) {
        searchTask?.cancel()
        
        
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 4 {
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 600_000_000) // 600ms debounce
                if Task.isCancelled { return }
                await buscarDadosAutomaticos(trimmed)
            }
        }
    }
    
    private func buscarDadosAutomaticos(_ sn: String) {
        if sn.isEmpty {
            categoria = ""
            localizacao = ""
            return
        }
        
        // Limpar imediatamente antes de cada nova busca (conforme comportamento Android)
        categoria = ""
        localizacao = ""
        
        isAutofilling = true
        
        Task {
            // Simular tempo de pensamento (800ms)
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            let apiTypes = ["Computer", "Monitor", "NetworkEquipment", "Printer"]
            var found = false
            
            for type in apiTypes {
                do {
                    if let item = try await GLPIClient.shared.searchBySerialWithLocation(itemtype: type, serial: sn) {
                        let locName = item["3"] as? String ?? ""
                        
                        let mappedCategory = {
                            switch type {
                            case "Computer": return "Computador"
                            case "Monitor": return "Monitor"
                            case "NetworkEquipment": return "Rede"
                            case "Printer": return "Impressora"
                            default: return ""
                            }
                        }()
                        
                        await MainActor.run {
                            self.categoria = mappedCategory
                            self.localizacao = locName.trimmingCharacters(in: .whitespaces)
                            self.isAutofilling = false
                        }
                        found = true
                        break // Encontrou o item correspondente, encerra a busca
                    }
                } catch {
                    print("Erro ao buscar dados automáticos para \(type): \(error)")
                }
            }
            
            if !found {
                await MainActor.run {
                    self.isAutofilling = false
                }
            }
        }
    }
    
    private func enviarTicket() {
        snError = nil
        categoriaError = nil
        localizacaoError = nil
        generalErrorMessage = nil
        
        var hasError = false
        if numeroSerie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            snError = "CAMPO OBRIGATÓRIO (DIGITE OU SELECIONE O SN)"
            hasError = true
        }
        if categoria.isEmpty {
            categoriaError = "CAMPO OBRIGATÓRIO (SELECIONE A CATEGORIA)"
            hasError = true
        }
        if localizacao.isEmpty {
            localizacaoError = "CAMPO OBRIGATÓRIO (SELECIONE A LOCALIZAÇÃO)"
            hasError = true
        }
        
        if hasError { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isSubmitting = true
        
        // Simulação de submissão do ticket
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            await MainActor.run {
                successAlert = true
                isSubmitting = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
}
