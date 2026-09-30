import SwiftUI

struct TicketReplyView: View {
    @Environment(\.dismiss) private var dismiss
    let ticket: GLPITicket
    
    @State private var replyText: String = ""
    @State private var isTicketExpanded: Bool = false
    @FocusState private var isFocused: Bool
    @AppStorage("isLightMode_V2") private var isLightMode = true
    
    var body: some View {
        ZStack {
            // 1. FUNDO COM REGRA UNIVERSAL DE CANCELAMENTO
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss {
                    isFocused = false
                }
            
            VStack(spacing: 0) {
                // 2. HEADER
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(GlpiColors.universalBlue)
                    }
                    .padding(.leading, GlpiMetrics.padding + 5)
                    
                    Spacer()
                    
                    Text("RESPONDER")
                        .font(.amiko(size: 16, weight: .black))
                        .foregroundColor(GlpiColors.universalBlue)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                        .padding(.trailing, GlpiMetrics.padding)
                }
                .frame(height: 60)
                .padding(.top, 10)
                
                // 3. CONTEÚDO
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        
                        TicketRowView(
                            ticket: ticket,
                            isSelected: false,
                            isExpanded: isTicketExpanded,
                            onSelect: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    isTicketExpanded.toggle()
                                }
                            },
                            currentY: .constant(0)
                        )
                        .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("A SUA RESPOSTA")
                                .font(.amiko(size: 10, weight: .black))
                                .foregroundColor(isLightMode ? GlpiColors.universalBlue : .white)
                                .padding(.leading, 8)
                            
                            ZStack(alignment: .topLeading) {
                                if replyText.isEmpty {
                                    Text("Escreva aqui a sua mensagem...")
                                        .font(.amiko(size: 16, weight: .regular))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.2))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 20)
                                }
                                
                                TextEditor(text: $replyText)
                                    .font(.amiko(size: 16, weight: .regular))
                                    .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
                                    .scrollContentBackground(.hidden)
                                    .padding(15)
                                    .focused($isFocused)
                                    .tint(GlpiColors.universalBlue)
                            }
                            .frame(minHeight: 250)
                            .glassStyle(cornerRadius: 30, isSelection: isFocused)
                        }
                        .padding(.horizontal, 16)
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                        }) {
                            Text("ENVIAR RESPOSTA")
                                .font(.amiko(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    Capsule()
                                        .fill(replyText.isEmpty ? GlpiColors.universalBlue.opacity(0.3) : GlpiColors.universalBlue)
                                        .shadow(color: GlpiColors.universalBlue.opacity(0.3), radius: 15, y: 8)
                                )
                        }
                        .disabled(replyText.isEmpty)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 50)
                    }
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isFocused = false
                        hideKeyboard()
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
    }
}


