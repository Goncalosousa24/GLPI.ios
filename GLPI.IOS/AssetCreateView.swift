import SwiftUI

struct AssetCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    // Estados para criação do dispositivo
    @State private var deviceName: String = ""
    @State private var deviceType: String = ""
    @State private var location: String = ""
    @State private var assignedTo: String = ""
    @State private var status: String = ""
    @State private var serialNumber: String = ""
    @State private var showScanner: Bool = false
    
    // Foco para bordas azuis
    enum Field: Hashable {
        case name, sn, assignedTo
    }
    @FocusState private var focusedField: Field?
    
    // Estados de expansão
    @State private var isTypeExpanded: Bool = false
    @State private var isLocationExpanded: Bool = false
    @State private var isAssigneeExpanded: Bool = false
    @State private var isStatusExpanded: Bool = false
    
    // Opções para os seletores (Mocks com fallback)
    let types = ["Computador", "Monitor", "Dispositivo de Rede", "Impressora"]
    
    @State private var locationOptions: [String] = [
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
        "  ↳ Ação Social",
        "  ↳ Complexo Lazer V. Verde",
        "  ↳ CPCJ",
        "  ↳ GIF",
        "  ↳ Loja Social",
        "  ↳ Piscinas de Prado",
        "  ↳ SQIP",
        "DRH", 
        "DSI",
        "  ↳ Arquivo",
        "  ↳ Sala Bastidores",
        "  ↳ Arrumos Informática",
        "DUE", 
        "EC Prado", 
        "EXE",
        "  ↳ GRP",
        "Stock",
        "  ↳ Red Tagged",
        "UCP", 
        "UCT", 
        "UIC",
        "  ↳ Casa do Conhecimento",
        "UMAQ"
    ]
    @State private var locationMap: [String: String] = [:]
    
    @State private var staffOptions: [String] = ["glpi", "normal", "post-only", "tech", "Gonçalo Sousa", "Ana Martins", "Pedro Alves", "Sofia Martins", "Ricardo Silva"]
    @State private var staffMap: [String: String] = [:]
    
    @State private var statusOptions: [String] = ["Avariado", "Informado", "Novo", "Usado", "Vigor"]
    @State private var statusMap: [String: String] = [:]

    // Controle de carregamento e submissão
    @State private var isLoadingData: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successAlert: Bool = false
    
    // Erros inline
    @State private var nameError: String? = nil
    @State private var typeError: String? = nil
    @State private var snError: String? = nil
    
    @State private var searchTask: Task<Void, Never>? = nil
    
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
                        
                        // 1. NOME DO DISPOSITIVO
                        VStack(alignment: .leading, spacing: 5) {
                            inputField(label: "ESCREVER NOME", text: $deviceName, placeholder: "INSERIR NOME", focus: .name)
                            if let nameError = nameError {
                                Text(nameError)
                                    .font(.amiko(size: 11, weight: .bold))
                                    .foregroundColor(.red)
                                    .padding(.leading, 15)
                            }
                        }
                        
                        // 2. NÚMERO DE SÉRIE
                        VStack(alignment: .leading, spacing: 5) {
                            inputField(
                                label: "ESCREVER SN", 
                                text: $serialNumber, 
                                placeholder: "INSERIR SN", 
                                focus: .sn,
                                rightIcon: "qrcode.viewfinder",
                                rightIconAction: { showScanner = true }
                            )
                            if let snError = snError {
                                Text(snError)
                                    .font(.amiko(size: 11, weight: .bold))
                                    .foregroundColor(.red)
                                    .padding(.leading, 15)
                            }
                        }
                        
                        // 3. TIPO DE DISPOSITIVO
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 5) {
                                EditFieldCapsule(
                                    label: "TIPO DE DISPOSITIVO", 
                                    value: deviceType.isEmpty ? "SELECIONAR" : deviceType, 
                                    icon: "", 
                                    valueColor: deviceType.isEmpty ? GlpiColors.dynamicBlueText : nil,
                                    isSelected: isTypeExpanded
                                ) {
                                    withAnimation(.spring()) {
                                        isTypeExpanded.toggle()
                                        closeOtherPickers(except: "type")
                                    }
                                }
                                if let typeError = typeError {
                                    Text(typeError)
                                        .font(.amiko(size: 11, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(.leading, 15)
                                }
                            }
                            if isTypeExpanded {
                                VStack(spacing: 4) {
                                    ForEach(types, id: \.self) { type in
                                        OptionRow(title: type, isSelected: deviceType == type) {
                                            deviceType = type
                                            typeError = nil
                                            withAnimation { isTypeExpanded = false }
                                        }
                                    }
                                }
                                .padding(8)
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 4. LOCALIZAÇÃO
                        VStack(spacing: 8) {
                            EditFieldCapsule(
                                label: "LOCALIZAÇÃO", 
                                value: location.isEmpty ? "SELECIONAR" : location.trimmingCharacters(in: .whitespaces), 
                                icon: "", 
                                valueColor: location.isEmpty ? GlpiColors.dynamicBlueText : nil,
                                isSelected: isLocationExpanded
                            ) {
                                withAnimation(.spring()) {
                                    isLocationExpanded.toggle()
                                    closeOtherPickers(except: "location")
                                }
                            }
                            if isLocationExpanded {
                                ScrollablePickerView(
                                    options: locationOptions,
                                    selected: $location,
                                    onSelect: { 
                                        location = location.trimmingCharacters(in: .whitespaces)
                                        withAnimation { isLocationExpanded = false } 
                                    }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 5. ATRIBUIR A
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ATRIBUIR A")
                                    .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                                    .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                                    .padding(.leading, 5)
                                
                                HStack(spacing: 0) {
                                    TextField("", text: $assignedTo)
                                        .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                                        .foregroundColor(GlpiColors.dynamicText)
                                        .placeholder(when: assignedTo.isEmpty && focusedField != .assignedTo) {
                                            Text("SELECIONAR / ESCREVER")
                                                .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                                                .foregroundColor(GlpiMetrics.FORM_PLACEHOLDER_COLOR)
                                        }
                                        .focused($focusedField, equals: .assignedTo)
                                        .tint(GlpiColors.universalBlue)
                                        .onTapGesture {
                                            withAnimation(.spring()) {
                                                isAssigneeExpanded = true
                                                closeOtherPickers(except: "assignee")
                                            }
                                        }
                                        .onChange(of: assignedTo) { _, newValue in
                                            handleAssigneeSearch(newValue)
                                        }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: GlpiMetrics.FORM_CHEVRON_SIZE, weight: GlpiMetrics.FORM_CHEVRON_WEIGHT))
                                        .foregroundColor(GlpiColors.universalBlue.opacity(GlpiMetrics.FORM_CHEVRON_OPACITY))
                                        .rotationEffect(.degrees(isAssigneeExpanded ? 180 : 0))
                                        .onTapGesture {
                                            withAnimation(.spring()) {
                                                isAssigneeExpanded.toggle()
                                                if isAssigneeExpanded {
                                                    focusedField = .assignedTo
                                                    closeOtherPickers(except: "assignee")
                                                } else {
                                                    focusedField = nil
                                                }
                                            }
                                        }
                                }
                                .padding(.horizontal, GlpiMetrics.FORM_FIELD_HPADDING)
                                .frame(height: GlpiMetrics.FORM_FIELD_HEIGHT)
                                .glassStyle(cornerRadius: 22, isSelection: isAssigneeExpanded)
                            }
                            
                            if isAssigneeExpanded {
                                let searchClean = assignedTo.trimmingCharacters(in: .whitespaces)
                                    .folding(options: .diacriticInsensitive, locale: .current)
                                    .lowercased()
                                
                                let filteredStaff = staffOptions.filter { opt in
                                    if searchClean.isEmpty { return true }
                                    let optClean = opt.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                                    return optClean.contains(searchClean)
                                }
                                
                                ScrollablePickerView(
                                    options: filteredStaff,
                                    selected: $assignedTo,
                                    onSelect: { 
                                        withAnimation { 
                                            isAssigneeExpanded = false
                                            focusedField = nil
                                            hideKeyboard()
                                        }
                                    }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 6. ESTADO
                        VStack(spacing: 8) {
                            EditFieldCapsule(
                                label: "ESTADO", 
                                value: status.isEmpty ? "SELECIONAR" : status, 
                                icon: "", 
                                valueColor: status.isEmpty ? GlpiColors.dynamicBlueText : nil,
                                isSelected: isStatusExpanded
                            ) {
                                withAnimation(.spring()) {
                                    isStatusExpanded.toggle()
                                    closeOtherPickers(except: "status")
                                }
                            }
                            if isStatusExpanded {
                                ScrollablePickerView(
                                    options: statusOptions,
                                    selected: $status,
                                    onSelect: { withAnimation { isStatusExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // Erro Geral
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
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
                                Text("Dispositivo adicionado com sucesso!")
                                    .font(.amiko(size: 14, weight: .black))
                                    .foregroundColor(.green)
                            }
                            .padding(15)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            .transition(.scale)
                        }
                        
                        // BOTÃO CRIAR
                        createButton
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
            
            // Indicador de Carregamento Geral/Submissão
            if isLoadingData || isSubmitting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text(isSubmitting ? "A guardar dispositivo..." : "A carregar dados do formulário...")
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
                self.serialNumber = scannedCode
            }
        }
        .onAppear {
            carregarDados()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            withAnimation(.spring()) {
                if newValue == .assignedTo {
                    isAssigneeExpanded = true
                    closeOtherPickers(except: "assignee")
                } else if oldValue == .assignedTo && newValue != .assignedTo {
                    isAssigneeExpanded = false
                }
            }
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
            
            Text("CRIAR DISPOSITIVO")
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
                    .onChange(of: text.wrappedValue) { newValue in
                        if focus == .name {
                            nameError = nil
                        } else if focus == .sn {
                            snError = nil
                        }
                    }
                
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
    
    private var createButton: some View {
        Button(action: {
            validarESubmeter()
        }) {
            Text("CRIAR DISPOSITIVO")
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
    
    private func closeOtherPickers(except: String) {
        if except != "type" { isTypeExpanded = false }
        if except != "location" { isLocationExpanded = false }
        if except != "assignee" { isAssigneeExpanded = false }
        if except != "status" { isStatusExpanded = false }
        
        if except != "assignee" {
            hideKeyboard()
        }
    }
    
    private func carregarDados() {
        isLoadingData = true
        Task {
            do {
                // 1. Carregar localizações
                let locs = try await GLPIClient.shared.getLocations()
                var locOptions: [String] = []
                var locMap: [String: String] = [:]
                
                // Lógica de Hierarquia idêntica ao Android:
                let categoriasNomes = ["DPS", "DSI", "EXE", "Stock", "UIC"]
                let categoriasFilhos = [
                    "DPS": ["Ação Social", "Complexo de Lazer de Vila Verde", "CPCJ", "Loja Social", "Piscinas de Prado", "SQIP", "GIF"],
                    "DSI": ["Arquivo", "Sala Bastidores", "Sala de Arrumos Informática"],
                    "EXE": ["GRP"],
                    "Stock": ["Red Tagged"],
                    "UIC": ["Casa do Conhecimento"]
                ]
                
                var itensNaoMapeados = locs.map { ["name": $0.name, "id": $0.id] }
                
                for catNome in categoriasNomes {
                    if let pai = itensNaoMapeados.first(where: { $0["name"]?.localizedCaseInsensitiveCompare(catNome) == .orderedSame }) {
                        let name = pai["name"] ?? ""
                        locOptions.append(name)
                        locMap[name] = pai["id"]
                        itensNaoMapeados.removeAll(where: { $0["id"] == pai["id"] })
                    }
                    
                    let filhosNomes = categoriasFilhos[catNome] ?? []
                    let filhosEncontrados = itensNaoMapeados.filter { item in
                        filhosNomes.contains { $0.localizedCaseInsensitiveCompare(item["name"] ?? "") == .orderedSame }
                    }
                    
                    for child in filhosEncontrados.sorted(by: { ($0["name"] ?? "") < ($1["name"] ?? "") }) {
                        let childName = child["name"] ?? ""
                        let display = "\(catNome) - \(childName)"
                        locOptions.append(display)
                        locMap[display] = child["id"]
                        locMap[childName] = child["id"]
                        itensNaoMapeados.removeAll(where: { $0["id"] == child["id"] })
                    }
                }
                
                // O resto por ordem alfabética
                for rest in itensNaoMapeados.sorted(by: { ($0["name"] ?? "") < ($1["name"] ?? "") }) {
                    let name = rest["name"] ?? ""
                    locOptions.append(name)
                    locMap[name] = rest["id"]
                }
                
                if !locOptions.isEmpty {
                    self.locationOptions = locOptions
                    self.locationMap = locMap
                }
                
                // 2. Carregar técnicos
                let users = try await GLPIClient.shared.searchUsers(query: "")
                var techOptions = ["glpi", "normal", "post-only", "tech"]
                var techMap: [String: String] = [:]
                
                for user in users {
                    techOptions.append(user.name)
                    techMap[user.name] = user.id
                }
                
                if !users.isEmpty {
                    self.staffOptions = techOptions
                    self.staffMap = techMap
                }
                
                // 3. Carregar estados
                let states = try await GLPIClient.shared.getStates()
                var stateOptions: [String] = []
                var stateMap: [String: String] = [:]
                
                for state in states.sorted(by: { $0.name < $1.name }) {
                    stateOptions.append(state.name)
                    stateMap[state.name] = state.id
                }
                
                if !states.isEmpty {
                    self.statusOptions = stateOptions
                    self.statusMap = stateMap
                }
                
                self.isLoadingData = false
            } catch {
                print("Erro ao carregar dados do formulário: \(error)")
                self.isLoadingData = false
            }
        }
    }
    
    private func handleAssigneeSearch(_ newValue: String) {
        searchTask?.cancel()
        
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                let users = try await GLPIClient.shared.searchUsers(query: trimmed)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    var newOptions = ["glpi", "normal", "post-only", "tech"]
                    var newMap = self.staffMap
                    
                    for u in users {
                        if !newOptions.contains(u.name) {
                            newOptions.append(u.name)
                            newMap[u.name] = u.id
                        }
                    }
                    self.staffOptions = newOptions
                    self.staffMap = newMap
                }
            } catch {
                print("Erro ao pesquisar utilizadores: \(error)")
            }
        }
    }
    
    private func validarESubmeter() {
        nameError = nil
        typeError = nil
        snError = nil
        errorMessage = nil
        
        var hasError = false
        if deviceType.isEmpty {
            typeError = "CAMPO OBRIGATÓRIO (SELECIONE O TIPO)"
            hasError = true
        }
        if deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nameError = "CAMPO OBRIGATÓRIO (DIGITE O NOME)"
            hasError = true
        }
        
        if hasError { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isSubmitting = true
        
        Task {
            do {
                let trimmedName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedSN = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 1. Verificar duplicado de Nome
                let isNameDuplicate = try await GLPIClient.shared.checkDuplicateGlobal(value: trimmedName, field: 1)
                if isNameDuplicate {
                    nameError = "ESTE NOME JÁ EXISTE NO INVENTÁRIO (CHECK GLPI)"
                    isSubmitting = false
                    return
                }
                
                // 2. Verificar duplicado de SN (se preenchido)
                if !trimmedSN.isEmpty {
                    let isSNDuplicate = try await GLPIClient.shared.checkDuplicateGlobal(value: trimmedSN, field: 5)
                    if isSNDuplicate {
                        snError = "ESTE NÚMERO DE SÉRIE JÁ EXISTE NO INVENTÁRIO"
                        isSubmitting = false
                        return
                    }
                }
                
                // 3. Obter os IDs reais
                let technicianId = staffMap[assignedTo]
                let locId = locationMap[location]
                let stateId = statusMap[status]
                
                // 4. Construir input
                var input: [String: Any] = [:]
                input["name"] = trimmedName
                input["comment"] = "Adicionado via GLPI Mobile App (iOS)"
                input["entities_id"] = "0"
                
                if !trimmedSN.isEmpty { input["serial"] = trimmedSN }
                if let locId = locId { input["locations_id"] = locId }
                if let stateId = stateId { input["states_id"] = stateId }
                if let technicianId = technicianId {
                    input["users_id_tech"] = technicianId
                    input["users_id"] = technicianId
                }
                
                let itemtype = {
                    switch deviceType {
                    case "Computador": return "Computer"
                    case "Monitor": return "Monitor"
                    case "Dispositivo de Rede": return "NetworkEquipment"
                    case "Impressora": return "Printer"
                    default: return "Peripheral"
                    }
                }()
                
                // 5. POST addDevice
                guard let newId = try await GLPIClient.shared.addDevice(itemtype: itemtype, input: input) else {
                    throw NSError(domain: "GLPIError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Não foi possível criar o dispositivo no GLPI."])
                }
                
                // 6. PUT updateDevice para garantir consistência (paridade com Android)
                _ = try? await GLPIClient.shared.updateDevice(itemtype: itemtype, id: newId, input: input)
                
                // 7. Sucesso!
                successAlert = true
                isSubmitting = false
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}
