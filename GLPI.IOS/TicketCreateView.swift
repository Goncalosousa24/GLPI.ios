import SwiftUI

struct TicketCreateView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLightMode") var isLightMode: Bool = false
    
    @State private var assunto: String = ""
    @State private var tipo: String = "Incidente"
    @State private var categoria: String = "Geral"
    @State private var fonte: String = "App"
    @State private var prioridade: TicketPriority? = .medium
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
    
    let ticketTypes = ["Incidente", "Pedido"]
    let categories = ["Geral", "Hardware", "Software", "Rede", "Email"]
    let sources = ["App", "Email", "Telefone", "Direto"]
    
    var body: some View {
        ZStack {
            // Fundo
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Só X para fechar)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isLightMode ? .black.opacity(0.6) : .white.opacity(0.6))
                            .padding(12)
                            .glassStyle(cornerRadius: 18)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // 1. ASSUNTO
                        HStack(spacing: 15) {
                            Image(systemName: "pencil")
                                .foregroundColor(isLightMode ? .black.opacity(0.8) : .white.opacity(0.8))
                                .font(.system(size: 16))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ASSUNTO")
                                    .font(.amiko(size: 9, weight: .bold))
                                    .foregroundColor(isLightMode ? .black.opacity(0.8) : .white.opacity(0.8))
                                
                                TextField("", text: $assunto, prompt: Text("").foregroundColor(isLightMode ? .black.opacity(0.7) : .white.opacity(0.7)))
                                    .font(.amiko(size: 15))
                                    .foregroundColor(isLightMode ? .black : .white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .glassStyle(cornerRadius: 22)
                        
                        // 2. SELETORES
                        Group {
                            // TIPO
                            VStack(spacing: 8) {
                                EditFieldCapsule(label: "TIPO", value: tipo, icon: "tag.fill") {
                                    withAnimation(.spring()) {
                                        isTypeExpanded.toggle()
                                        if isTypeExpanded {
                                            isCategoryExpanded = false
                                            isSourceExpanded = false
                                            isPriorityExpanded = false
                                        }
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
                                EditFieldCapsule(label: "CATEGORIA", value: categoria, icon: "folder.fill") {
                                    withAnimation(.spring()) {
                                        isCategoryExpanded.toggle()
                                        if isCategoryExpanded {
                                            isTypeExpanded = false
                                            isSourceExpanded = false
                                            isPriorityExpanded = false
                                        }
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
                                EditFieldCapsule(label: "FONTE DO PEDIDO", value: fonte, icon: "globe") {
                                    withAnimation(.spring()) {
                                        isSourceExpanded.toggle()
                                        if isSourceExpanded {
                                            isTypeExpanded = false
                                            isCategoryExpanded = false
                                            isPriorityExpanded = false
                                        }
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
                                EditFieldCapsule(label: "PRIORIDADE", value: prioridade?.rawValue ?? "", icon: "exclamationmark.triangle.fill", valueColor: prioridade?.color ?? (isLightMode ? .black.opacity(0.8) : .white.opacity(0.8))) {
                                    withAnimation(.spring()) {
                                        isPriorityExpanded.toggle()
                                        if isPriorityExpanded {
                                            isTypeExpanded = false
                                            isCategoryExpanded = false
                                            isSourceExpanded = false
                                            isAtendimentoExpanded = false
                                            isSolucaoExpanded = false
                                        }
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
                            
                            // TEMPO ATENDIMENTO
                            VStack(spacing: 8) {
                                EditFieldCapsule(label: "TEMPO ATENDIMENTO", value: tempoAtendimento.isEmpty ? "" : tempoAtendimento, icon: "clock") {
                                    withAnimation(.spring()) {
                                        isAtendimentoExpanded.toggle()
                                        if isAtendimentoExpanded {
                                            // Atribui data atual se estiver vazio ao abrir
                                            if tempoAtendimento.isEmpty {
                                                atendimentoDate = Date()
                                                let formatter = DateFormatter()
                                                formatter.locale = Locale(identifier: "pt_PT")
                                                formatter.dateFormat = "dd/MM/yyyy HH:mm"
                                                tempoAtendimento = formatter.string(from: atendimentoDate)
                                            }
                                            
                                            isTypeExpanded = false
                                            isCategoryExpanded = false
                                            isSourceExpanded = false
                                            isPriorityExpanded = false
                                            isSolucaoExpanded = false
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
                                            .tint(GlpiColors.primary)
                                            .onChange(of: atendimentoDate) { oldDate, newDate in
                                                let formatter = DateFormatter()
                                                formatter.locale = Locale(identifier: "pt_PT")
                                                formatter.dateFormat = "dd/MM/yyyy HH:mm"
                                                tempoAtendimento = formatter.string(from: newDate)
                                            }
                                        
                                        Button(action: {
                                            tempoAtendimento = ""
                                            withAnimation { isAtendimentoExpanded = false }
                                        }) {
                                            Text("Nenhum")
                                                .font(.amiko(size: 14, weight: .bold))
                                                .foregroundColor(isLightMode ? .black.opacity(0.6) : .white.opacity(0.6))
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity)
                                                .background(isLightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
                                                .cornerRadius(12)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .glassStyle(cornerRadius: 22)
                                }
                            }
                            
                            // TEMPO SOLUÇÃO
                            VStack(spacing: 8) {
                                EditFieldCapsule(label: "TEMPO SOLUÇÃO", value: tempoSolucao.isEmpty ? "" : tempoSolucao, icon: "clock.fill") {
                                    withAnimation(.spring()) {
                                        isSolucaoExpanded.toggle()
                                        if isSolucaoExpanded {
                                            // Atribui data atual se estiver vazio ao abrir
                                            if tempoSolucao.isEmpty {
                                                solucaoDate = Date()
                                                let formatter = DateFormatter()
                                                formatter.locale = Locale(identifier: "pt_PT")
                                                formatter.dateFormat = "dd/MM/yyyy HH:mm"
                                                tempoSolucao = formatter.string(from: solucaoDate)
                                            }
                                            
                                            isTypeExpanded = false
                                            isCategoryExpanded = false
                                            isSourceExpanded = false
                                            isPriorityExpanded = false
                                            isAtendimentoExpanded = false
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
                                            .tint(GlpiColors.primary)
                                            .onChange(of: solucaoDate) { oldDate, newDate in
                                                let formatter = DateFormatter()
                                                formatter.locale = Locale(identifier: "pt_PT")
                                                formatter.dateFormat = "dd/MM/yyyy HH:mm"
                                                tempoSolucao = formatter.string(from: newDate)
                                            }
                                        
                                        Button(action: {
                                            tempoSolucao = ""
                                            withAnimation { isSolucaoExpanded = false }
                                        }) {
                                            Text("Nenhum")
                                                .font(.amiko(size: 14, weight: .bold))
                                                .foregroundColor(isLightMode ? .black.opacity(0.6) : .white.opacity(0.6))
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity)
                                                .background(isLightMode ? Color.black.opacity(0.05) : Color.white.opacity(0.05))
                                                .cornerRadius(12)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .glassStyle(cornerRadius: 22)
                                }
                            }
                        }
                        
                        // 3. DESCRIÇÃO
                        VStack(alignment: .leading, spacing: 5) {
                            Text("DESCRIÇÃO DETALHADA")
                                .font(.amiko(size: 9, weight: .bold))
                                .foregroundColor(isLightMode ? .black.opacity(0.8) : .white.opacity(0.8))
                                .padding(.horizontal, 16)
                                .padding(.top, 15)
                            
                            TextEditor(text: $descricao)
                                .frame(minHeight: 120)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 15)
                                .font(.amiko(size: 14))
                                .foregroundColor(isLightMode ? .black : .white)
                                .scrollContentBackground(.hidden)
                        }
                        .glassStyle(cornerRadius: 22)
                        
                        // BOTÃO CRIAR (Agora dentro do scroll, debaixo das opções)
                        Button(action: { dismiss() }) {
                            Text("CRIAR TICKET")
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(isLightMode ? .black.opacity(0.8) : .white.opacity(0.8))
                                .frame(width: 240, height: 52)
                                .glassStyle(cornerRadius: 22)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 60)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
    }
}

#Preview {
    TicketCreateView()
}
