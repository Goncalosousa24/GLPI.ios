import SwiftUI

struct TicketEditView: View {
    let ticket: GLPITicket
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    @State private var requesterList: [TechnicianAssignment] = []
    @State private var atribuidoList: [TechnicianAssignment] = []
    
    // Lista de Mock de utilizadores para sugestões
    private let mockUsers = ["Gonçalo Sousa", "Maria Silva", "João Mendes", "Ana Costa", "Pedro Alves", "Sónia Luz", "Rui Santos", "Carla Dias", "Nuno Lima", "Eduardo Lima", "Beatriz Silva", "Carlos Mendes", "Diana Rose"]
    
    @State private var tipo: String = ""
    @State private var categoria: String = ""
    @State private var fonte: String = ""
    @State private var estado: String = ""
    @State private var prioridade: TicketPriority? = nil
    @State private var descricao: String = ""
    
    @State private var tempoAtendimento: String = ""
    @State private var atendimentoDate = Date()
    @State private var tempoSolucao: String = ""
    @State private var solucaoDate = Date()
    
    @State private var isTypeExpanded = false
    @State private var isCategoryExpanded = false
    @State private var isSourceExpanded = false
    @State private var isStatusExpanded = false
    @State private var isPriorityExpanded = false
    @State private var isAtendimentoExpanded = false
    @State private var isSolucaoExpanded = false
    
    @FocusState private var focusedId: UUID?
    
    enum Field: Hashable {
        case descricao
    }
    @FocusState private var focusedField: Field?
    
    let ticketTypes = ["Incidente", "Pedido"]
    @State private var categoriesList: [String] = ["Geral", "Hardware", "Software", "Rede", "Email"]
    @State private var categoryMap: [String: String] = [:] // maps category completename -> id
    let sources = ["Direto", "E-Mail", "Formcreator", "Helpdesk", "Telefone", "Escrito", "Outro"]
    
    // Novas variáveis de estado para busca e sincronização
    @State private var suggestedUsers: [String] = []
    @State private var userIdsMap: [String: String] = [:] // maps name -> user id
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var showConfirmAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    init(ticket: GLPITicket) {
        self.ticket = ticket
        
        // Inicializar com os dados básicos vindos do ticket
        _prioridade = State(initialValue: ticket.priority)
        _descricao = State(initialValue: ticket.description)
        
        let statusMap = [
            "1": "Novo",
            "2": "A processar (atribuído)",
            "3": "A processar (planeado)",
            "4": "Aguardando",
            "5": "Finalizado",
            "6": "Encerrado"
        ]
        let currentStatus = statusMap[ticket.rawStatus] ?? "Novo"
        _estado = State(initialValue: currentStatus)
        
        // Valores iniciais de fallback para requesters/technicians
        let reqName = ticket.requester
        let reqList: [TechnicianAssignment]
        if reqName.isEmpty || reqName == "Pendente" {
            reqList = [TechnicianAssignment(name: "")]
        } else {
            let names = reqName.components(separatedBy: " & ")
            reqList = names.map { TechnicianAssignment(name: $0) }
        }
        _requesterList = State(initialValue: reqList)
        
        let assigned = ticket.assignedTo
        let assignedList: [TechnicianAssignment]
        if assigned.isEmpty || assigned == "Pendente" {
            assignedList = [TechnicianAssignment(name: "")]
        } else {
            let names = assigned.components(separatedBy: " & ")
            assignedList = names.map { TechnicianAssignment(name: $0) }
        }
        _atribuidoList = State(initialValue: assignedList)
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss {
                    withAnimation(.spring()) {
                        closeOtherPickers(except: "")
                    }
                }
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        ticketIdView
                        creatorSection
                        // 1. Requerentes (Multi)
                        requesterSection
                        
                        // 2. Atribuído a (Multi)
                        assignmentSection
                        selectorsSection
                        datePickersSection
                        editButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            closeOtherPickers(except: "")
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
            
            if isLoading || isSaving {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 15) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text(isSaving ? "A gravar alterações..." : "A carregar dados...")
                            .font(.amiko(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                }
            }
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
        .alert("CONFIRMAR EDIÇÃO", isPresented: $showConfirmAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Confirmar") {
                saveChanges()
            }
        } message: {
            Text("Tem a certeza que deseja atualizar este ticket com as novas alterações?")
        }
        .onAppear {
            loadInitialData()
        }
        .onChange(of: focusedId) { oldValue, newValue in
            if let newId = newValue {
                let currentName = (requesterList.first(where: { $0.id == newId })?.name ?? 
                                   atribuidoList.first(where: { $0.id == newId })?.name ?? "")
                handleNameChange(for: newId, newName: currentName)
            } else {
                self.suggestedUsers = []
            }
        }
        .onChange(of: requesterList) { oldValue, newValue in
            // Atualizar IDs correspondentes aos nomes se existirem no mapa
            for i in 0..<requesterList.count {
                let name = requesterList[i].name
                if let id = userIdsMap[name], requesterList[i].userId != id {
                    requesterList[i].userId = id
                }
            }
            if let focused = focusedId,
               let item = newValue.first(where: { $0.id == focused }),
               let oldItem = oldValue.first(where: { $0.id == focused }),
               item.name != oldItem.name {
                handleNameChange(for: focused, newName: item.name)
            }
        }
        .onChange(of: atribuidoList) { oldValue, newValue in
            // Atualizar IDs correspondentes aos nomes se existirem no mapa
            for i in 0..<atribuidoList.count {
                let name = atribuidoList[i].name
                if let id = userIdsMap[name], atribuidoList[i].userId != id {
                    atribuidoList[i].userId = id
                }
            }
            if let focused = focusedId,
               let item = newValue.first(where: { $0.id == focused }),
               let oldItem = oldValue.first(where: { $0.id == focused }),
               item.name != oldItem.name {
                handleNameChange(for: focused, newName: item.name)
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
            
            Text("EDITAR TICKET")
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicBlueText)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 5)
        .frame(height: GlpiMetrics.navAreaHeight - 5)
    }
    
    private var ticketIdView: some View {
        HStack {
            Text("ID: \(ticket.id)")
                .font(.inconsolata(size: 14, weight: .bold))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
            Spacer()
        }
        .padding(.horizontal, 8)
    }
    
    private var creatorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CRIADO POR")
                .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                .padding(.leading, 5)
            
            HStack(spacing: 0) {
                Text(ticket.author.isEmpty ? "DESCONHECIDO" : ticket.author.uppercased())
                    .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                    .foregroundColor(GlpiColors.dynamicBlueText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .glassStyle(cornerRadius: 22)
        }
    }
    
    private var requesterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("REQUERENTE")
                    .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                    .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring()) {
                        let newReq = TechnicianAssignment(name: "")
                        requesterList.append(newReq)
                        focusedId = newReq.id
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(GlpiColors.universalBlue)
                        Text("ADICIONAR")
                            .foregroundColor(GlpiColors.dynamicBlueText)
                            .font(.amiko(size: 11, weight: .bold))
                    }
                }
                .padding(.trailing, 5)
            }
            .padding(.leading, 5)
            
            VStack(spacing: 12) {
                ForEach($requesterList) { $req in
                    AssignmentRowView(
                        assignment: $req,
                        focusedId: $focusedId,
                        showDelete: requesterList.count > 1,
                        suggestions: (focusedId == req.id) ? suggestedUsers : [],
                        onDelete: {
                            withAnimation {
                                requesterList.removeAll { $0.id == req.id }
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ATRIBUÍDO A")
                    .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                    .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                    .padding(.leading, 5)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring()) {
                        let newAssignment = TechnicianAssignment(name: "")
                        atribuidoList.append(newAssignment)
                        focusedId = newAssignment.id
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(GlpiColors.universalBlue)
                        Text("ADICIONAR")
                            .foregroundColor(GlpiColors.dynamicBlueText)
                            .font(.amiko(size: 11, weight: .bold))
                    }
                }
                .padding(.trailing, 5)
            }
            
            VStack(spacing: 12) {
                ForEach($atribuidoList) { $atrib in
                    AssignmentRowView(
                        assignment: $atrib,
                        focusedId: $focusedId,
                        showDelete: atribuidoList.count > 1,
                        suggestions: (focusedId == atrib.id) ? suggestedUsers : [],
                        onDelete: {
                            withAnimation {
                                atribuidoList.removeAll { $0.id == atrib.id }
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var selectorsSection: some View {
        VStack(spacing: 25) {
            // ESTADO
            VStack(spacing: 8) {
                EditFieldCapsule(label: "ESTADO", value: estado.isEmpty ? "SELECIONAR" : estado, icon: "", valueColor: estado.isEmpty ? GlpiColors.dynamicBlueText : nil, isSelected: isStatusExpanded) {
                    withAnimation(.spring()) {
                        isStatusExpanded.toggle()
                        closeOtherPickers(except: "status")
                    }
                }
                if isStatusExpanded {
                    ScrollablePickerView(
                        options: ["Novo", "A processar (atribuído)", "A processar (planeado)", "Aguardando", "Finalizado", "Encerrado"],
                        selected: $estado,
                        onSelect: { withAnimation { isStatusExpanded = false } }
                    )
                    .glassStyle(cornerRadius: 22)
                }
            }
            
            // TIPO
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
            
            // CATEGORIA
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
            
            // FONTE DO PEDIDO
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
            
            // PRIORIDADE
            VStack(spacing: 8) {
                EditFieldCapsule(label: "PRIORIDADE", value: prioridade?.rawValue ?? "SELECIONAR", icon: "", valueColor: prioridade == nil ? GlpiColors.dynamicBlueText : nil, isSelected: isPriorityExpanded) {
                    withAnimation(.spring()) {
                        isPriorityExpanded.toggle()
                        closeOtherPickers(except: "priority")
                    }
                }
                if isPriorityExpanded {
                    VStack(spacing: 4) {
                        ForEach(TicketPriority.allCases, id: \.self) { prio in
                            OptionRow(title: prio.rawValue, isSelected: prioridade == prio) {
                                prioridade = prio
                                withAnimation { isPriorityExpanded = false }
                            }
                        }
                    }
                    .padding(8)
                    .glassStyle(cornerRadius: 22)
                }
            }
        }
    }
    
    private var datePickersSection: some View {
        VStack(spacing: 25) {
            // ATENDIMENTO
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
            
            // SOLUÇÃO
            VStack(spacing: 8) {
                EditFieldCapsule(label: "TEMPO DE SOLUÇÃO", value: tempoSolucao.isEmpty ? "SELECIONAR" : tempoSolucao, icon: "", valueColor: tempoSolucao.isEmpty ? GlpiColors.dynamicBlueText : nil, isSelected: isSolucaoExpanded) {
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
        }
        .onChange(of: focusedId) { _, newValue in
            if newValue != nil {
                withAnimation(.spring()) {
                    isTypeExpanded = false
                    isCategoryExpanded = false
                    isSourceExpanded = false
                    isStatusExpanded = false
                    isPriorityExpanded = false
                    isAtendimentoExpanded = false
                    isSolucaoExpanded = false
                }
            }
        }
    }
    
    private var editButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showConfirmAlert = true
        }) {
            Text("EDITAR TICKET")
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
    
    // MARK: - Logic & Actions
    
    private func loadInitialData() {
        isLoading = true
        Task {
            do {
                // 1. Carregar Categorias
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
                
                // 2. Carregar Detalhes do Ticket
                let fullTicket = try await GLPIClient.shared.getTicketById(id: ticket.id)
                
                var resolvedType = ""
                if let typeInt = fullTicket["type"] as? Int ?? (fullTicket["type"] as? String).flatMap(Int.init) {
                    resolvedType = (typeInt == 2) ? "Pedido" : "Incidente"
                }
                
                var resolvedFonte = ""
                if let sourceVal = fullTicket["requesttypes_id"] {
                    var sourceName = "Direto"
                    if let sourceDict = sourceVal as? [String: Any], let name = sourceDict["name"] as? String {
                        sourceName = name
                    } else if let sourceStr = sourceVal as? String {
                        sourceName = sourceStr
                    } else if let sourceInt = sourceVal as? Int {
                        sourceName = String(sourceInt)
                    }
                    resolvedFonte = resolveSourceName(sourceName)
                }
                
                var resolvedCategory = ""
                if let catVal = fullTicket["itilcategories_id"] {
                    if let catDict = catVal as? [String: Any], let name = catDict["completename"] as? String ?? catDict["name"] as? String {
                        resolvedCategory = GlpiHtmlFixer.unescapeHtml(name)
                    } else if let catStr = catVal as? String {
                        resolvedCategory = GlpiHtmlFixer.unescapeHtml(catStr)
                    }
                }
                
                var resolvedTto = ""
                var ttoDate = Date()
                if let tto = fullTicket["time_to_own"] as? String, tto != "null", !tto.isEmpty {
                    resolvedTto = formatGLPIDateToDisplay(tto)
                    if let d = parseGLPIDate(tto) {
                        ttoDate = d
                    }
                }
                
                var resolvedTtr = ""
                var ttrDate = Date()
                if let ttr = fullTicket["time_to_resolve"] as? String, ttr != "null", !ttr.isEmpty {
                    resolvedTtr = formatGLPIDateToDisplay(ttr)
                    if let d = parseGLPIDate(ttr) {
                        ttrDate = d
                    }
                }
                
                // 3. Carregar Atores do Ticket (requerentes e técnicos)
                let actors = try await GLPIClient.shared.getTicketActors(ticketId: ticket.id)
                var newReqList: [TechnicianAssignment] = []
                var newTechList: [TechnicianAssignment] = []
                var tempUsersMap: [String: String] = [:]
                
                for actor in actors {
                    guard let type = actor["type"] as? Int ?? (actor["type"] as? String).flatMap(Int.init) else { continue }
                    
                    var userIdStr = ""
                    var resolvedName = ""
                    
                    if let userDict = actor["users_id"] as? [String: Any] {
                        if let uid = userDict["id"] as? Int { userIdStr = String(uid) }
                        else if let uid = userDict["id"] as? String { userIdStr = uid }
                        
                        let fname = userDict["firstname"] as? String ?? ""
                        let rname = userDict["realname"] as? String ?? ""
                        let uname = userDict["name"] as? String ?? ""
                        
                        resolvedName = fname.isEmpty && rname.isEmpty ? uname : "\(fname) \(rname)".trimmingCharacters(in: .whitespaces)
                    }
                    
                    if userIdStr.isEmpty {
                        let userIdVal = actor["users_id"]
                        if let idInt = userIdVal as? Int { userIdStr = String(idInt) }
                        else if let idStr = userIdVal as? String { userIdStr = idStr }
                    }
                    
                    if resolvedName.isEmpty && !userIdStr.isEmpty {
                        resolvedName = await UserNameResolver.shared.resolve(
                            id: userIdStr,
                            baseURL: PreferenceManager.shared.baseURL,
                            sessionToken: PreferenceManager.shared.sessionToken,
                            appToken: PreferenceManager.shared.appToken
                        )
                    }
                    
                    if !resolvedName.isEmpty {
                        tempUsersMap[resolvedName] = userIdStr
                        let assignment = TechnicianAssignment(name: resolvedName, userId: userIdStr)
                        if type == 1 {
                            newReqList.append(assignment)
                        } else if type == 2 {
                            newTechList.append(assignment)
                        }
                    }
                }
                
                await MainActor.run {
                    if !newCats.isEmpty {
                        self.categoriesList = newCats.sorted()
                        self.categoryMap = newMap
                    }
                    if !resolvedType.isEmpty { self.tipo = resolvedType }
                    if !resolvedFonte.isEmpty { self.fonte = resolvedFonte }
                    if !resolvedCategory.isEmpty { self.categoria = resolvedCategory }
                    
                    if !resolvedTto.isEmpty {
                        self.tempoAtendimento = resolvedTto
                        self.atendimentoDate = ttoDate
                    }
                    if !resolvedTtr.isEmpty {
                        self.tempoSolucao = resolvedTtr
                        self.solucaoDate = ttrDate
                    }
                    
                    for (k, v) in tempUsersMap {
                        self.userIdsMap[k] = v
                    }
                    
                    if !newReqList.isEmpty {
                        self.requesterList = newReqList
                    } else {
                        let reqName = ticket.requester
                        if reqName.isEmpty || reqName == "Pendente" {
                            self.requesterList = [TechnicianAssignment(name: "")]
                        } else {
                            let names = reqName.components(separatedBy: " & ")
                            self.requesterList = names.map { TechnicianAssignment(name: $0) }
                        }
                    }
                    
                    if !newTechList.isEmpty {
                        self.atribuidoList = newTechList
                    } else {
                        let assigned = ticket.assignedTo
                        if assigned.isEmpty || assigned == "Pendente" {
                            self.atribuidoList = [TechnicianAssignment(name: "")]
                        } else {
                            let names = assigned.components(separatedBy: " & ")
                            self.atribuidoList = names.map { TechnicianAssignment(name: $0) }
                        }
                    }
                    
                    self.isLoading = false
                }
            } catch {
                print("Erro ao carregar dados iniciais: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func handleNameChange(for id: UUID, newName: String) {
        searchTask?.cancel()
        
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            self.suggestedUsers = mockUsers.filter { $0.localizedCaseInsensitiveContains(newName) && $0 != newName }
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            do {
                let users = try await GLPIClient.shared.searchUsers(query: trimmed)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    var names: [String] = []
                    for u in users {
                        names.append(u.name)
                        self.userIdsMap[u.name] = u.id
                    }
                    
                    if !ticket.author.isEmpty && ticket.author.localizedCaseInsensitiveContains(trimmed) && !names.contains(ticket.author) {
                        names.insert(ticket.author, at: 0)
                    }
                    
                    self.suggestedUsers = names
                }
            } catch {
                print("Erro ao pesquisar utilizadores: \(error)")
            }
        }
    }
    
    private func saveChanges() {
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
                
                let selectedStatusId: Int
                switch estado {
                case "Novo": selectedStatusId = 1
                case "A processar (atribuído)": selectedStatusId = 2
                case "A processar (planeado)": selectedStatusId = 3
                case "Aguardando": selectedStatusId = 4
                case "Finalizado": selectedStatusId = 5
                case "Encerrado": selectedStatusId = 6
                default: selectedStatusId = 1
                }
                
                var input: [String: Any] = [
                    "id": ticket.id,
                    "type": selectedType,
                    "requesttypes_id": selectedSourceId,
                    "priority": selectedPriorityId,
                    "status": selectedStatusId,
                    "content": descricao
                ]
                
                if let catId = categoryMap[categoria] {
                    input["itilcategories_id"] = catId
                }
                
                if !tempoAtendimento.isEmpty {
                    input["time_to_own"] = formatDisplayToGLPIDate(tempoAtendimento)
                } else {
                    input["time_to_own"] = "null"
                }
                
                if !tempoSolucao.isEmpty {
                    input["time_to_resolve"] = formatDisplayToGLPIDate(tempoSolucao)
                } else {
                    input["time_to_resolve"] = "null"
                }
                
                // Gravar alterações no ticket
                let success = try await GLPIClient.shared.updateTicket(id: ticket.id, input: input)
                
                if success {
                    // Sincronizar Atores
                    try await syncActors(
                        ticketId: ticket.id,
                        currentRequesters: requesterList,
                        currentTechnicians: atribuidoList
                    )
                    
                    await MainActor.run {
                        self.isSaving = false
                        self.isSuccess = true
                        self.alertMessage = "Ticket atualizado com sucesso!"
                        self.showAlert = true
                        
                        NotificationCenter.default.post(name: NSNotification.Name("TicketUpdated"), object: nil)
                    }
                } else {
                    throw NSError(domain: "GLPIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Não foi possível gravar as alterações do ticket no servidor."])
                }
                
            } catch {
                print("Erro ao salvar ticket: \(error)")
                await MainActor.run {
                    self.isSaving = false
                    self.isSuccess = false
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
                }
            }
        }
    }
    
    private func syncActors(ticketId: String, currentRequesters: [TechnicianAssignment], currentTechnicians: [TechnicianAssignment]) async throws {
        let serverActors = try await GLPIClient.shared.getTicketActors(ticketId: ticketId)
        
        var serverReqs: [String: Int] = [:]
        var serverTechs: [String: Int] = [:]
        
        for actor in serverActors {
            guard let relId = actor["id"] as? Int ?? (actor["id"] as? String).flatMap(Int.init),
                  let type = actor["type"] as? Int ?? (actor["type"] as? String).flatMap(Int.init) else { continue }
            
            let userIdVal = actor["users_id"]
            var userIdStr = ""
            if let userDict = userIdVal as? [String: Any], let id = userDict["id"] as? Int {
                userIdStr = String(id)
            } else if let userDict = userIdVal as? [String: Any], let idStr = userDict["id"] as? String {
                userIdStr = idStr
            } else if let idInt = userIdVal as? Int {
                userIdStr = String(idInt)
            } else if let idStr = userIdVal as? String {
                userIdStr = idStr
            }
            
            if !userIdStr.isEmpty {
                if type == 1 {
                    serverReqs[userIdStr] = relId
                } else if type == 2 {
                    serverTechs[userIdStr] = relId
                }
            }
        }
        
        let newReqUserIds = Set(currentRequesters.compactMap { $0.userId }.filter { !$0.isEmpty })
        for (userId, relId) in serverReqs {
            if !newReqUserIds.contains(userId) {
                _ = try await GLPIClient.shared.deleteTicketActor(relationshipId: relId)
            }
        }
        
        for req in currentRequesters {
            if let userId = req.userId, !userId.isEmpty {
                if serverReqs[userId] == nil {
                    _ = try await GLPIClient.shared.addTicketActor(ticketId: ticketId, userId: userId, type: 1)
                }
            }
        }
        
        let newTechUserIds = Set(currentTechnicians.compactMap { $0.userId }.filter { !$0.isEmpty })
        for (userId, relId) in serverTechs {
            if !newTechUserIds.contains(userId) {
                _ = try await GLPIClient.shared.deleteTicketActor(relationshipId: relId)
            }
        }
        
        for tech in currentTechnicians {
            if let userId = tech.userId, !userId.isEmpty {
                if serverTechs[userId] == nil {
                    _ = try await GLPIClient.shared.addTicketActor(ticketId: ticketId, userId: userId, type: 2)
                }
            }
        }
    }
    
    private func closeOtherPickers(except: String) {
        if except != "type" { isTypeExpanded = false }
        if except != "category" { isCategoryExpanded = false }
        if except != "source" { isSourceExpanded = false }
        if except != "status" { isStatusExpanded = false }
        if except != "priority" { isPriorityExpanded = false }
        if except != "atendimento" { isAtendimentoExpanded = false }
        if except != "solucao" { isSolucaoExpanded = false }
        
        focusedId = nil
        focusedField = nil
        hideKeyboard()
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
    
    private func parseGLPIDate(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: str)
    }

    private func formatGLPIDateToDisplay(_ str: String) -> String {
        guard let date = parseGLPIDate(str) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
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
    
    private func resolveSourceName(_ value: String) -> String {
        let str = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.isEmpty || str == "null" || str == "0" { return "Direto" }
        
        if str.localizedCaseInsensitiveContains("Helpdesk") || str == "1" { return "Helpdesk" }
        if str.localizedCaseInsensitiveContains("Email") || str.localizedCaseInsensitiveContains("E-Mail") || str == "2" { return "E-Mail" }
        if str.localizedCaseInsensitiveContains("Phone") || str.localizedCaseInsensitiveContains("Telefone") || str == "3" { return "Telefone" }
        if str.localizedCaseInsensitiveContains("Direct") || str.localizedCaseInsensitiveContains("Direto") || str == "4" { return "Direto" }
        if str.localizedCaseInsensitiveContains("Written") || str.localizedCaseInsensitiveContains("Escrito") || str == "5" { return "Escrito" }
        if str.localizedCaseInsensitiveContains("Other") || str.localizedCaseInsensitiveContains("Outro") || str == "6" { return "Outro" }
        if str.localizedCaseInsensitiveContains("Formcreator") || str == "7" { return "Formcreator" }
        
        return str
    }
}

#Preview {
    TicketEditView(ticket: GLPITicket(id: "1024", name: "Erro Login", requester: "Gonçalo Sousa", author: "Eduardo Lima", assignedTo: "Admin", description: "Desc", date: Date(), priority: .major, status: .new, rawStatus: "1", isMine: true, isAssignedToMe: false))
}
