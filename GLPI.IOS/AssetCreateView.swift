import SwiftUI

struct AssetCreateView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Estados para criação do dispositivo
    @State private var deviceName: String = ""
    @State private var deviceType: String = ""
    @State private var location: String = ""
    @State private var assignedTo: String = ""
    @State private var status: String = ""
    @State private var serialNumber: String = ""
    
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
            // Fundo Premium
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            // Camada de fecho (Só ativa se algo estiver aberto)
            if isTypeExpanded || isLocationExpanded || isAssigneeExpanded || isStatusExpanded {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                        withAnimation {
                            isTypeExpanded = false
                            isLocationExpanded = false
                            isAssigneeExpanded = false
                            isStatusExpanded = false
                        }
                    }
            }
            
            VStack(spacing: 0) {
                // Header (Botão fechar)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(12)
                            .glassStyle(cornerRadius: 18)
                    }
                    Spacer()
                    Spacer()
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 25) {
                        
                        // 1. NOME DO DISPOSITIVO
                        HStack(spacing: 15) {
                            Image(systemName: "pencil")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 16))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NOME DO DISPOSITIVO")
                                    .font(.amiko(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                TextField("", text: $deviceName, prompt: Text("").foregroundColor(.white.opacity(0.3)))
                                    .font(.amiko(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .glassStyle(cornerRadius: 22)
                        
                        // 2. TIPO DE DISPOSITIVO
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "TIPO DE DISPOSITIVO", value: deviceType, icon: "desktopcomputer") {
                                withAnimation(.spring()) {
                                    isTypeExpanded.toggle()
                                    if isTypeExpanded {
                                        isLocationExpanded = false
                                        isAssigneeExpanded = false
                                        isStatusExpanded = false
                                    }
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
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        
                        // 3. LOCALIZAÇÃO
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "LOCALIZAÇÃO", value: location, icon: "mappin.and.ellipse") {
                                withAnimation(.spring()) {
                                    isLocationExpanded.toggle()
                                    if isLocationExpanded {
                                        isTypeExpanded = false
                                        isAssigneeExpanded = false
                                        isStatusExpanded = false
                                    }
                                }
                            }
                            if isLocationExpanded {
                                ScrollablePickerView(
                                    options: locations,
                                    selected: $location,
                                    onSelect: { withAnimation { isLocationExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        
                        // 4. ATRIBUIR A
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "ATRIBUIR A", value: assignedTo, icon: "person.fill") {
                                withAnimation(.spring()) {
                                    isAssigneeExpanded.toggle()
                                    if isAssigneeExpanded {
                                        isTypeExpanded = false
                                        isLocationExpanded = false
                                        isStatusExpanded = false
                                    }
                                }
                            }
                            if isAssigneeExpanded {
                                ScrollablePickerView(
                                    options: staff,
                                    selected: $assignedTo,
                                    onSelect: { withAnimation { isAssigneeExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        
                        // 5. ESTADO
                        VStack(spacing: 8) {
                            EditFieldCapsule(label: "ESTADO", value: status, icon: "checkmark.circle.fill") {
                                withAnimation(.spring()) {
                                    isStatusExpanded.toggle()
                                    if isStatusExpanded {
                                        isTypeExpanded = false
                                        isLocationExpanded = false
                                        isAssigneeExpanded = false
                                    }
                                }
                            }
                            if isStatusExpanded {
                                ScrollablePickerView(
                                    options: statuses,
                                    selected: $status,
                                    onSelect: { withAnimation { isStatusExpanded = false } }
                                )
                                .glassStyle(cornerRadius: 22)
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                            }
                        }
                        
                        // 6. NÚMERO DE SÉRIE
                        HStack(spacing: 15) {
                            Image(systemName: "number")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 16))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NÚMERO DE SÉRIE (SN)")
                                    .font(.amiko(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                TextField("", text: $serialNumber, prompt: Text("").foregroundColor(.white.opacity(0.3)))
                                    .font(.amiko(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .glassStyle(cornerRadius: 22)
                        
                        // BOTÃO CRIAR
                        Button(action: { dismiss() }) {
                            Text("CRIAR DISPOSITIVO")
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 240, height: 52)
                                .glassStyle(cornerRadius: 22)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 60)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
        }
    }
}

#Preview {
    AssetCreateView()
}
