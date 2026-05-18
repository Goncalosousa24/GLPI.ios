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
    let categories = ["Geral", "Hardware", "Software", "Rede", "Email"]
    let sources = ["App", "Email", "Telefone", "Direto"]
    
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
                            .foregroundColor(GlpiColors.dynamicText)
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
                                    options: categories,
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
                            EditFieldCapsule(label: "PRIORIDADE", value: prioridade?.rawValue ?? "SELECIONAR", icon: "", valueColor: prioridade == nil ? GlpiColors.dynamicBlueText : prioridade?.color, isSelected: isPriorityExpanded) {
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
                            dismiss()
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
        .onTapGesture {
            hideKeyboard()
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
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
}

#Preview {
    TicketCreateView()
}
