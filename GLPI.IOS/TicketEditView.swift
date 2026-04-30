import SwiftUI

struct TicketEditView: View {
    let ticket: GLPITicket
    @Environment(\.dismiss) var dismiss
    
    @State private var requerente: String
    @State private var atribuidoA: String
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
    @State private var isRequesterExpanded = false
    @State private var isAssigneeExpanded = false
    @State private var isCategoryExpanded = false
    @State private var isSourceExpanded = false
    @State private var isPriorityExpanded = false
    @State private var isAtendimentoExpanded = false
    @State private var isSolucaoExpanded = false
    
    let ticketTypes = ["Incidente", "Pedido"]
    let categories = ["Geral", "Hardware", "Software", "Rede", "Email"]
    let sources = ["App", "Email", "Telefone", "Direto"]
    
    init(ticket: GLPITicket) {
        self.ticket = ticket
        _requerente = State(initialValue: ticket.requester)
        _atribuidoA = State(initialValue: ticket.assignedTo)
        _tipo = State(initialValue: "Incidente")
        _categoria = State(initialValue: "Geral")
        _fonte = State(initialValue: "App")
        _prioridade = State(initialValue: ticket.priority)
        _descricao = State(initialValue: ticket.description)
    }
    
    var body: some View {
        ZStack {
            // Fundo
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Customizado
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(12)
                            .glassStyle(cornerRadius: 18)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        
                        // ID do Ticket (Elegante)
                        HStack {
                            Text("TICKET \(ticket.id)")
                                .font(.amiko(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.3))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        // LISTA DE PÍLULAS
                        VStack(spacing: 25) {
                            EditFieldCapsule(label: "REQUERENTE", value: requerente, icon: "person.fill") { }
                            EditFieldCapsule(label: "ATRIBUIR", value: atribuidoA, icon: "person.badge.plus") { }
                            
                            // TIPO
                            VStack(spacing: 8) {
                                EditFieldCapsule(label: "TIPO", value: tipo, icon: "tag.fill") {
                                    withAnimation(.spring()) {
                                        isTypeExpanded.toggle()
                                        if isTypeExpanded {
                                            isRequesterExpanded = false
                                            isAssigneeExpanded = false
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
                                            isRequesterExpanded = false
                                            isAssigneeExpanded = false
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
                            
                            // FONTE
                            VStack(spacing: 8) {
                                EditFieldCapsule(label: "FONTE DO PEDIDO", value: fonte, icon: "globe") {
                                    withAnimation(.spring()) {
                                        isSourceExpanded.toggle()
                                        if isSourceExpanded {
                                            isRequesterExpanded = false
                                            isAssigneeExpanded = false
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
                                EditFieldCapsule(label: "PRIORIDADE", value: prioridade?.rawValue ?? "", icon: "exclamationmark.triangle.fill", valueColor: prioridade?.color ?? .white.opacity(0.4)) {
                                    withAnimation(.spring()) {
                                        isPriorityExpanded.toggle()
                                        if isPriorityExpanded {
                                            isRequesterExpanded = false
                                            isAssigneeExpanded = false
                                            isTypeExpanded = false
                                            isCategoryExpanded = false
                                            isSourceExpanded = false
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
                        }
                        .padding(.horizontal, 16)
                        
                        // BOTÃO EDITAR
                        Button(action: { dismiss() }) {
                            Text("SALVAR ALTERAÇÕES")
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 240, height: 52)
                                .glassStyle(cornerRadius: 22)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 60)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
}

#Preview {
    TicketEditView(ticket: GLPITicket(id: "#1024", name: "Erro Login", requester: "Gonçalo Sousa", assignedTo: "Admin", description: "Desc", date: Date(), priority: .major, status: .new, isMine: true, isAssignedToMe: false))
}
