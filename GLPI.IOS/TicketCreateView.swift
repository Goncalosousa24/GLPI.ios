import SwiftUI

struct TicketCreateView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    @State private var assunto: String = ""
    @State private var tipo: String = ""
    @State private var categoria: String = ""
    @State private var fonte: String = ""
    @State private var prioridade: TicketPriority? = nil
    @State private var descricao: String = ""
    
    @State private var tempoAtendimento: String = ""
    @State private var atendimentoDate = Date()
    @State private var tempoSolucao: String = ""
    @State private var solucaoDate = Date()
    
    @State private var categoriesList: [String] = ["Geral", "Hardware", "Software", "Rede", "Email"]
    @State private var categoryMap: [String: String] = [:] // maps category completename -> id
    
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    @State private var isTypeExpanded = false
    @State private var isCategoryExpanded = false
    @State private var isSourceExpanded = false
    @State private var isPriorityExpanded = false
    @State private var isAtendimentoExpanded = false
    @State private var isSolucaoExpanded = false
    
    enum Field {
        case assunto, descricao
    }
    @FocusState private var focusedField: Field?
    
    let ticketTypes = ["Incidente", "Pedido"]
    let sources = ["Direto", "E-Mail", "Formcreator", "Helpdesk", "Telefone", "Escrito", "Outro"]
    
    var body: some View {
        ZStack {
            // 1. FUNDO PREMIUM
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss {
                    withAnimation(.spring()) {
                        closeOtherPickers(except: "")
                        hideKeyboard()
                    }
                }
            
            VStack(spacing: 0) {
                // 2. HEADER (SETAS UNIVERSAIS E POSICIONAMENTO)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: GlpiMetrics.universalBackIcon)
                            .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                            .foregroundColor(GlpiColors.universalBlue)
                    }
                    .padding(.leading, GlpiMetrics.universalHeaderLeading)
                    
                    Spacer()
                    
                    Text("NOVO TICKET")
                        .font(.amiko(size: 16, weight: .black))
                        .foregroundColor(GlpiColors.dynamicBlueText)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.top, GlpiMetrics.topPadding)
                .frame(height: GlpiMetrics.navAreaHeight)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // 1. ASSUNTO (RETÂNGULO DE ESCRITA)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ASSUNTO")
                                .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                                .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                                .padding(.leading, 5)
                            
                            HStack(spacing: 0) {
                                TextField("", text: $assunto)
                                    .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                                    .foregroundColor(GlpiColors.dynamicText)
                                    .placeholder(when: assunto.isEmpty && focusedField != .assunto) {
                                        Text("ESCREVER")
                                            .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                                            .foregroundColor(GlpiMetrics.FORM_PLACEHOLDER_COLOR)
                                    }
                                    .focused($focusedField, equals: .assunto)
                                    .tint(GlpiColors.universalBlue)
                                    .onChange(of: focusedField) { newValue in
                                        if newValue == .assunto {
                                            withAnimation { closeOtherPickers(except: "") }
                                        }
                                    }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .glassStyle(cornerRadius: 22, isSelection: focusedField == .assunto)
                        }
                        
                        // 2. TIPO (RETÂNGULO DE SELECÇÃO)
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "TIPO", value: tipo.isEmpty ? "SELECIONAR" : tipo, icon: "", valueColor: tipo.isEmpty ? GlpiColors.dynamicBlueText : nil, isSelected: isTypeExpanded) {
                                withAnimation(.spring()) {
                                    isTypeExpanded.toggle()
                                    closeOtherPickers(except: "type")
                                }
                            }
                            if isTypeExpanded {
                                VStack(spacing: 4) {
                                    ForEach(ticketTypes, id: \.self) { type in
                                        OptionRow(title: type, isSelected: tipo == type) {
                                            tipo = type
                                            withAnimation { isTypeExpanded = false }
                                        }
                                    }
                                }
                                .padding(8)
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 3. CATEGORIA (RETÂNGULO DE SELECÇÃO)
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "CATEGORIA", value: categoria.isEmpty ? "SELECIONAR" : categoria, icon: "", valueColor: categoria.isEmpty ? GlpiColors.dynamicBlueText : nil, isSelected: isCategoryExpanded) {
                                withAnimation(.spring()) {
                                    isCategoryExpanded.toggle()
                                    closeOtherPickers(except: "category")
                                }
                            }
                            if isCategoryExpanded {
                                ScrollablePickerView(
                                    options: categoriesList,
                                    selected: $categoria,
                                    onSelect: { withAnimation { isCategoryExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 4. FONTE DO PEDIDO (RETÂNGULO DE SELECÇÃO)
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "FONTE DO PEDIDO", value: fonte.isEmpty ? "SELECIONAR" : fonte, icon: "", valueColor: fonte.isEmpty ? GlpiColors.dynamicBlueText : nil, isSelected: isSourceExpanded) {
                                withAnimation(.spring()) {
                                    isSourceExpanded.toggle()
                                    closeOtherPickers(except: "source")
                                }
                            }
                            if isSourceExpanded {
                                ScrollablePickerView(
                                    options: sources,
                                    selected: $fonte,
                                    onSelect: { withAnimation { isSourceExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 5. PRIORIDADE (RETÂNGULO DE SELECÇÃO)
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "PRIORIDADE", value: prioridade?.rawValue ?? "SELECIONAR", icon: "", valueColor: prioridade == nil ? GlpiColors.dynamicBlueText : nil, isSelected: isPriorityExpanded) {
                                withAnimation(.spring()) {
                                    isPriorityExpanded.toggle()
                                    closeOtherPickers(except: "priority")
                                }
                            }
                            if isPriorityExpanded {
                                ScrollablePickerView(
                                    options: TicketPriority.allCases.map { $0.rawValue },
                                    selected: Binding(
                                        get: { prioridade?.rawValue ?? "" },
                                        set: { newValue in
                                            if newValue.isEmpty {
                                                prioridade = nil
                                            } else if let newPriority = TicketPriority(rawValue: newValue) {
                                                prioridade = newPriority
                                            }
                                        }
                                    ),
                                    onSelect: { withAnimation { isPriorityExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 6. TEMPO PARA ATENDIMENTO (DATA + HORAS)
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "TEMPO PARA ATENDIMENTO", value: tempoAtendimento.isEmpty ? "SELECIONAR" : tempoAtendimento, icon: "", valueColor: tempoAtendimento.isEmpty ? GlpiColors.dynamicBlueText : nil, isSelected: isAtendimentoExpanded) {
                                withAnimation(.spring()) {
                                    isAtendimentoExpanded.toggle()
                                    if isAtendimentoExpanded {
                                        closeOtherPickers(except: "atendimento")
                                        if tempoAtendimento.isEmpty {
                                            atendimentoDate = Date()
                                            updateAtendimentoString(atendimentoDate)
                                        }
                                    }
                                }
                            }
                            if isAtendimentoExpanded {
                                VStack {
                                    DatePicker("", selection: $atendimentoDate)
                                        .datePickerStyle(.wheel)
                                        .labelsHidden()
                                        .preferredColorScheme(isLightMode ? .light : .dark)
                                        .environment(\.locale, Locale(identifier: "pt_PT"))
                                        .onChange(of: atendimentoDate) { _, newDate in
                                            updateAtendimentoString(newDate)
                                        }
                                    
                                    Button(action: {
                                        tempoAtendimento = ""
                                        withAnimation { isAtendimentoExpanded = false }
                                    }) {
                                        Text("Nenhum")
                                            .font(.amiko(size: 14, weight: .bold))
                                            .foregroundColor(GlpiColors.dynamicBlueText)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(GlpiColors.dynamicOffWhite)
                                            .cornerRadius(12)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 7. TEMPO PARA SOLUÇÃO (DATA + HORAS)
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "TEMPO PARA SOLUÇÃO", value: tempoSolucao.isEmpty ? "SELECIONAR" : tempoSolucao, icon: "", valueColor: tempoSolucao.isEmpty ? GlpiColors.dynamicBlueText : nil, isSelected: isSolucaoExpanded) {
                                withAnimation(.spring()) {
                                    isSolucaoExpanded.toggle()
                                    if isSolucaoExpanded {
                                        closeOtherPickers(except: "solucao")
                                        if tempoSolucao.isEmpty {
                                            solucaoDate = Date()
                                            updateSolucaoString(solucaoDate)
                                        }
                                    }
                                }
                            }
                            if isSolucaoExpanded {
                                VStack {
                                    DatePicker("", selection: $solucaoDate)
                                        .datePickerStyle(.wheel)
                                        .labelsHidden()
                                        .preferredColorScheme(isLightMode ? .light : .dark)
                                        .environment(\.locale, Locale(identifier: "pt_PT"))
                                        .onChange(of: solucaoDate) { _, newDate in
                                            updateSolucaoString(newDate)
                                        }
                                    
                                    Button(action: {
                                        tempoSolucao = ""
                                        withAnimation { isSolucaoExpanded = false }
                                    }) {
                                        Text("Nenhum")
                                            .font(.amiko(size: 14, weight: .bold))
                                            .foregroundColor(GlpiColors.dynamicBlueText)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(GlpiColors.dynamicOffWhite)
                                            .cornerRadius(12)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 8. DESCRIÇÃO DETALHADA
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DESCRIÇÃO DETALHADA")
                                .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                                .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                                .padding(.leading, 5)
                            
                            ZStack(alignment: .topLeading) {
                                if descricao.isEmpty && focusedField != .descricao {
                                    Text("ESCREVER")
                                        .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                                        .foregroundColor(GlpiMetrics.FORM_PLACEHOLDER_COLOR)
                                        .padding(.top, 2)
                                }
                                
                                TextEditor(text: $descricao)
                                    .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                                    .foregroundColor(GlpiColors.dynamicText)
                                    .frame(minHeight: 120)
                                    .scrollContentBackground(.hidden)
                                    .focused($focusedField, equals: .descricao)
                                    .tint(GlpiColors.universalBlue)
                                    .onChange(of: focusedField) { newValue in
                                        if newValue == .descricao {
                                            withAnimation { closeOtherPickers(except: "") }
                                        }
                                    }
                            }
                            .padding(16)
                            .glassStyle(cornerRadius: 22, isSelection: focusedField == .descricao)
                        }
                        
                        // 9. BOTÃO CRIAR TICKET (AZUL UNIVERSAL)
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            criarTicket()
                        }) {
                            Text("CRIAR TICKET")
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
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            closeOtherPickers(except: "")
                            hideKeyboard()
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            
            if isLoading || isSaving {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text(isSaving ? "A criar ticket..." : "A carregar dados...")
                        .font(.amiko(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(30)
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
        .alert(isSuccess ? "SUCESSO" : "ERRO", isPresented: $showAlert) {
            Button("OK") {
                if isSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    private func closeOtherPickers(except: String) {
        if except != "type" { isTypeExpanded = false }
        if except != "category" { isCategoryExpanded = false }
        if except != "source" { isSourceExpanded = false }
        if except != "priority" { isPriorityExpanded = false }
        if except != "atendimento" { isAtendimentoExpanded = false }
        if except != "solucao" { isSolucaoExpanded = false }
        
        // Se estivermos a abrir um picker, tiramos o foco dos campos de texto
        if !except.isEmpty {
            focusedField = nil
        }
    }
    
    private func updateAtendimentoString(_ date: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        tempoAtendimento = formatter.string(from: date)
    }
    
    private func updateSolucaoString(_ date: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        tempoSolucao = formatter.string(from: date)
    }
    
    private func loadInitialData() {
        isLoading = true
        Task {
            do {
                let cats = try await GLPIClient.shared.getITILCategories()
                var newCats: [String] = []
                var newMap: [String: String] = [:]
                for cat in cats {
                    if let id = cat["id"] as? Int ?? (cat["id"] as? String).flatMap(Int.init),
                       let nameRaw = cat["completename"] as? String ?? cat["name"] as? String {
                        let name = GlpiHtmlFixer.unescapeHtml(nameRaw)
                        newCats.append(name)
                        newMap[name] = String(id)
                    }
                }
                await MainActor.run {
                    self.isLoading = false
                    if !newCats.isEmpty {
                        self.categoriesList = newCats.sorted()
                        self.categoryMap = newMap
                    }
                }
            } catch {
                print("Erro ao carregar categorias: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func formatDisplayToGLPIDate(_ str: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        guard let date = formatter.date(from: str) else { return "" }
        
        let glpiFormatter = DateFormatter()
        glpiFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        glpiFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        glpiFormatter.locale = Locale(identifier: "en_US_POSIX")
        return glpiFormatter.string(from: date)
    }
    
    private func criarTicket() {
        let assuntoTrimmed = assunto.trimmingCharacters(in: .whitespacesAndNewlines)
        let descricaoTrimmed = descricao.trimmingCharacters(in: .whitespacesAndNewlines)
        if assuntoTrimmed.isEmpty || descricaoTrimmed.isEmpty {
            alertMessage = "Por favor, preencha o assunto e a descrição detalhada."
            isSuccess = false
            showAlert = true
            return
        }
        
        isSaving = true
        Task {
            do {
                let selectedType = (tipo == "Pedido") ? 2 : 1
                
                let selectedSourceId: Int
                switch fonte {
                case "Helpdesk": selectedSourceId = 1
                case "E-Mail": selectedSourceId = 2
                case "Telefone": selectedSourceId = 3
                case "Direto": selectedSourceId = 4
                case "Escrito": selectedSourceId = 5
                case "Outro": selectedSourceId = 6
                case "Formcreator": selectedSourceId = 7
                default: selectedSourceId = 4
                }
                
                let selectedPriorityId: Int
                switch prioridade {
                case .veryLow: selectedPriorityId = 1
                case .low: selectedPriorityId = 2
                case .medium: selectedPriorityId = 3
                case .high: selectedPriorityId = 4
                case .veryHigh: selectedPriorityId = 5
                case .major: selectedPriorityId = 6
                default: selectedPriorityId = 3
                }
                
                var input: [String: Any] = [
                    "name": assuntoTrimmed,
                    "content": descricaoTrimmed,
                    "status": 1, // Novo
                    "type": selectedType,
                    "requesttypes_id": selectedSourceId,
                    "priority": selectedPriorityId
                ]
                
                if let catId = categoryMap[categoria] {
                    input["itilcategories_id"] = catId
                }
                
                if !tempoAtendimento.isEmpty {
                    input["time_to_own"] = formatDisplayToGLPIDate(tempoAtendimento)
                }
                
                if !tempoSolucao.isEmpty {
                    input["time_to_resolve"] = formatDisplayToGLPIDate(tempoSolucao)
                }
                
                let createdId = try await GLPIClient.shared.createTicket(input: input)
                
                await MainActor.run {
                    self.isSaving = false
                    if createdId != nil {
                        self.isSuccess = true
                        self.alertMessage = "Ticket criado com sucesso!"
                        self.showAlert = true
                        
                        NotificationCenter.default.post(name: NSNotification.Name("TicketUpdated"), object: nil)
                    } else {
                        self.isSuccess = false
                        self.alertMessage = "Não foi possível criar o ticket no servidor."
                        self.showAlert = true
                    }
                }
            } catch {
                print("Erro ao criar ticket: \(error)")
                await MainActor.run {
                    self.isSaving = false
                    self.isSuccess = false
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
}

#Preview {
    TicketCreateView()
}
