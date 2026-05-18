import SwiftUI

struct TicketEditView: View {
    let ticket: GLPITicket
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    @State private var requesterList: [TechnicianAssignment] = []
    @State private var atribuidoList: [TechnicianAssignment]
    
    // Lista de Mock de utilizadores para sugestões
    private let mockUsers = ["Gonçalo Sousa", "Maria Silva", "João Mendes", "Ana Costa", "Pedro Alves", "Sónia Luz", "Rui Santos", "Carla Dias", "Nuno Lima", "Eduardo Lima", "Beatriz Silva", "Carlos Mendes", "Diana Rose"]
    @State private var tipo: String
    @State private var categoria: String
    @State private var fonte: String
    @State private var prioridade: TicketPriority?
    @State private var descricao: String
    
    @State private var tempoAtendimento: String = ""
    @State private var atendimentoDate = Date()
    @State private var tempoSolucao: String = ""
    @State private var solucaoDate = Date()
    
    @State private var isTypeExpanded = false
    @State private var isCategoryExpanded = false
    @State private var isSourceExpanded = false
    @State private var isPriorityExpanded = false
    @State private var isAtendimentoExpanded = false
    @State private var isSolucaoExpanded = false
    
    @FocusState private var focusedId: UUID?
    
    enum Field: Hashable {
        case descricao
    }
    @FocusState private var focusedField: Field?
    
    let ticketTypes = ["Incidente", "Pedido"]
    let categories = ["Geral", "Hardware", "Software", "Rede", "Email"]
    let sources = ["App", "Email", "Telefone", "Direto"]
    
    init(ticket: GLPITicket) {
        self.ticket = ticket
        _requesterList = State(initialValue: [TechnicianAssignment(name: "")])
        
        let assigned = ticket.assignedTo
        if assigned.isEmpty || assigned == "Pendente" {
            _atribuidoList = State(initialValue: [TechnicianAssignment(name: "")])
        } else {
            let names = assigned.components(separatedBy: " & ")
            let list = names.map { TechnicianAssignment(name: $0) }
            _atribuidoList = State(initialValue: list)
        }
        
        _tipo = State(initialValue: "")
        _categoria = State(initialValue: "")
        _fonte = State(initialValue: "")
        _prioridade = State(initialValue: nil)
        _descricao = State(initialValue: "")
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
                }
                .scrollDismissesKeyboard(.immediately)
                .simultaneousGesture(DragGesture().onChanged { _ in
                    withAnimation(.spring()) {
                        closeOtherPickers(except: "")
                        focusedId = nil
                        focusedField = nil
                    }
                })
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
                        suggestions: getRequesterSuggestions(for: req.name),
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
                        suggestions: getAssignmentSuggestions(for: atrib.name),
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
                        options: categories,
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
                // Se um campo de texto ganhar foco, fechamos apenas os seletores manuais (booleanos)
                // NÃO chamamos closeOtherPickers pois ele resetaria o focusedId criando um loop
                withAnimation(.spring()) {
                    isTypeExpanded = false
                    isCategoryExpanded = false
                    isSourceExpanded = false
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
            dismiss()
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
    
    private func getRequesterSuggestions(for text: String) -> [String] {
        let users = text.isEmpty ? mockUsers : mockUsers.filter { $0.localizedCaseInsensitiveContains(text) && $0 != text }
        var result = users
        
        if !ticket.author.isEmpty {
            result.removeAll { $0 == ticket.author }
            if text.isEmpty || ticket.author.localizedCaseInsensitiveContains(text) {
                result.insert(ticket.author, at: 0)
            }
        }
        
        return result
    }
    
    private func getAssignmentSuggestions(for text: String) -> [String] {
        return text.isEmpty ? mockUsers : mockUsers.filter { $0.localizedCaseInsensitiveContains(text) && $0 != text }
    }
    
    private func closeOtherPickers(except: String) {
        if except != "type" { isTypeExpanded = false }
        if except != "category" { isCategoryExpanded = false }
        if except != "source" { isSourceExpanded = false }
        if except != "priority" { isPriorityExpanded = false }
        if except != "atendimento" { isAtendimentoExpanded = false }
        if except != "solucao" { isSolucaoExpanded = false }
        
        // Se except for vazio, estamos a fechar TUDO (clique no fundo)
        // Se except tiver valor, estamos a abrir um seletor específico (limpamos foco para não chocar)
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
}

#Preview {
    TicketEditView(ticket: GLPITicket(id: "1024", name: "Erro Login", requester: "Gonçalo Sousa", author: "Eduardo Lima", assignedTo: "Admin", description: "Desc", date: Date(), priority: .major, status: .new, isMine: true, isAssignedToMe: false))
}
