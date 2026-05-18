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
        case name, sn
    }
    @FocusState private var focusedField: Field?
    
    // Estados de expansão
    @State private var isTypeExpanded: Bool = false
    @State private var isLocationExpanded: Bool = false
    @State private var isAssigneeExpanded: Bool = false
    @State private var isStatusExpanded: Bool = false
    
    // Opções para os seletores (Mocks)
    let types = ["Computador", "Monitor", "Dispositivo de Rede", "Impressora"]
    let locations = [
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
    let staff = ["Gonçalo Sousa", "Ana Martins", "Pedro Alves", "Sofia Martins", "Ricardo Silva"]
    let statuses = ["Avariado", "Informado", "Novo", "Usado", "Vigor"]
    
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
                        inputField(label: "ESCREVER NOME", text: $deviceName, placeholder: "INSERIR NOME", focus: .name)
                        
                        // 2. NÚMERO DE SÉRIE
                        inputField(
                            label: "ESCREVER SN", 
                            text: $serialNumber, 
                            placeholder: "INSERIR SN", 
                            focus: .sn,
                            rightIcon: "qrcode.viewfinder",
                            rightIconAction: { showScanner = true }
                        )
                        
                        // 3. TIPO DE DISPOSITIVO
                        VStack(spacing: 8) {
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
                            if isTypeExpanded {
                                VStack(spacing: 4) {
                                    ForEach(types, id: \.self) { type in
                                        OptionRow(title: type, isSelected: deviceType == type) {
                                            deviceType = type
                                            withAnimation { isTypeExpanded = false }
                                        }
                                    }
                                }
                                .padding(8)
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 3. LOCALIZAÇÃO
                        VStack(spacing: 8) {
                            EditFieldCapsule(
                                label: "LOCALIZAÇÃO", 
                                value: location.isEmpty ? "SELECIONAR" : location, 
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
                                    options: locations,
                                    selected: $location,
                                    onSelect: { withAnimation { isLocationExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 4. ATRIBUIR A
                        VStack(spacing: 8) {
                            EditFieldCapsule(
                                label: "ATRIBUIR A", 
                                value: assignedTo.isEmpty ? "SELECIONAR" : assignedTo, 
                                icon: "", 
                                valueColor: assignedTo.isEmpty ? GlpiColors.dynamicBlueText : nil,
                                isSelected: isAssigneeExpanded
                            ) {
                                withAnimation(.spring()) {
                                    isAssigneeExpanded.toggle()
                                    closeOtherPickers(except: "assignee")
                                }
                            }
                            if isAssigneeExpanded {
                                ScrollablePickerView(
                                    options: staff,
                                    selected: $assignedTo,
                                    onSelect: { withAnimation { isAssigneeExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // 5. ESTADO
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
                                    options: statuses,
                                    selected: $status,
                                    onSelect: { withAnimation { isStatusExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                            }
                        }
                        
                        // BOTÃO CRIAR
                        createButton
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
                self.serialNumber = scannedCode
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
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
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
        .padding(.top, 20)
        .padding(.bottom, 60)
    }
    
    private func closeOtherPickers(except: String) {
        if except != "type" { isTypeExpanded = false }
        if except != "location" { isLocationExpanded = false }
        if except != "assignee" { isAssigneeExpanded = false }
        if except != "status" { isStatusExpanded = false }
        
        hideKeyboard()
    }
}

#Preview {
    AssetCreateView()
}
