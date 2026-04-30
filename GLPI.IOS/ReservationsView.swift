
import SwiftUI

struct ReservationAsset: Identifiable {
    let id = UUID()
    let name: String
    let serial: String
    let type: AssetType
    var isReserved: Bool
    var reservedBy: String?
    var reservationDate: String?
}

struct ReservationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedStatus = "Geral"
    @State private var showFilterMenu = false
    let categoryOptions = ["Computadores", "Periféricos"]
    let statusOptions = ["Geral", "Livres", "Reservados"]
    
    private var pillWidth: CGFloat {
        let screenWidth = UIScreen.screenWidth
        let padding: CGFloat = 32
        let spacing: CGFloat = 12
        return (screenWidth - padding - spacing) / 2
    }
    
    
    @State private var reservations: [ReservationAsset] = [
        ReservationAsset(name: "MacBook Air M2", serial: "SN: MBA-9102", type: .computer, isReserved: true, reservedBy: "Gonçalo Sousa", reservationDate: "24/04/2026 - 28/04/2026"),
        ReservationAsset(name: "Projector Epson X41", serial: "SN: EP-4412", type: .network, isReserved: false),
        ReservationAsset(name: "iPad Pro 12.9\"", serial: "SN: IP-7788", type: .computer, isReserved: true, reservedBy: "Ana Martins", reservationDate: "23/04/2026 - 25/04/2026"),
        ReservationAsset(name: "Monitor Portátil ASUS", serial: "SN: AS-1122", type: .monitor, isReserved: false),
        ReservationAsset(name: "Kit WebCam + Tripé", serial: "SN: WC-3344", type: .network, isReserved: false)
    ]
    
    var filteredReservations: [ReservationAsset] {
        reservations.filter { asset in
            let matchesSearch = searchText.isEmpty || asset.name.lowercased().contains(searchText.lowercased()) || asset.serial.lowercased().contains(searchText.lowercased())
            
            let matchesCategory: Bool
            if let selected = selectedCategory {
                switch selected {
                case "Computadores": matchesCategory = asset.type == .computer
                case "Periféricos": matchesCategory = asset.type != .computer
                default: matchesCategory = true
                }
            } else {
                matchesCategory = true
            }
            
            let matchesStatus: Bool
            switch selectedStatus {
            case "Livres": matchesStatus = !asset.isReserved
            case "Reservados": matchesStatus = asset.isReserved
            default: matchesStatus = true
            }
            
            return matchesSearch && matchesCategory && matchesStatus
        }
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .glassStyle(cornerRadius: 12)
                    }
                    
                    Spacer()
                    
                    Spacer()
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                VStack(spacing: 0) {
                    // Search Bar & Filter Button
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.4))
                            TextField("", text: $searchText, prompt: 
                                Text("Procurar equipamento...")
                                    .foregroundColor(.white.opacity(0.3))
                                    .font(.amiko(size: 14))
                            )
                            .foregroundColor(.white)
                            .font(.amiko(size: 14))
                        }
                        .padding()
                        .glassStyle(cornerRadius: 18)
                        .frame(height: 55)
                        
                        Button(action: { 
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showFilterMenu.toggle() 
                            }
                        }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(width: 55, height: 55)
                                .glassStyle(cornerRadius: 18)
                        }
                    }
                    
                    Spacer().frame(height: 24) // Espaçamento equilibrado (cima)
                    
                    HStack {
                        Spacer()
                        HStack(spacing: 12) {
                            ForEach(categoryOptions, id: \.self) { option in
                                FilterPill(title: option, isSelected: selectedCategory == option, width: pillWidth) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if selectedCategory == option {
                                            selectedCategory = nil
                                        } else {
                                            selectedCategory = option
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    
                    Spacer().frame(height: 12) // Espaçamento equilibrado (12 + 12 do ScrollView = 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 25)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ScrollOffsetTracker()
                        ForEach(filteredReservations) { asset in
                            ReservationRow(asset: asset)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                }
            }
            .blur(radius: showFilterMenu ? 20 : 0)
            .animation(.spring(), value: showFilterMenu)
            
            // Overlay de Filtros (Estilo Tickets)
            if showFilterMenu {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) { showFilterMenu = false }
                    }
                
                VStack(spacing: 0) {
                    Text("FILTRAR POR ESTADO")
                        .font(.amiko(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 25)
                        .padding(.bottom, 12)
                    
                    ForEach(statusOptions, id: \.self) { option in
                        filterMenuItem(title: option, isSelected: selectedStatus == option) {
                            withAnimation(.spring()) {
                                selectedStatus = option
                                showFilterMenu = false
                            }
                        }
                        if option != statusOptions.last {
                            Divider().background(Color.white.opacity(0.1)).padding(.horizontal, 16)
                        }
                    }
                    
                    Spacer().frame(height: 15)
                }
                .frame(maxWidth: .infinity)
                .glassStyle(cornerRadius: 30)
                .padding(.horizontal, 16)
                .shadow(color: .blue.opacity(0.2), radius: 40)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .navigationBarHidden(true)
    }
    
    private func filterMenuItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.amiko(size: 14, weight: isSelected ? .bold : .regular))
                Spacer()
                if isSelected { Image(systemName: "checkmark").foregroundColor(.blue) }
            }
            .foregroundColor(.white)
            .padding(16)
        }
    }
}

struct ReservationRow: View {
    let asset: ReservationAsset
    @State private var showInfo = false
    @State private var showReserveSheet = false
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 15) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 45, height: 45)
                    
                    Image(systemName: asset.type.rawValue)
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name)
                        .font(.amiko(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(asset.serial)
                        .font(.amiko(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Status Badge
                Text(asset.isReserved ? "RESERVADO" : "LIVRE")
                    .font(.amiko(size: 9, weight: .bold))
                    .frame(width: 85, height: 24) // Tamanho fixo para consistência
                    .background(asset.isReserved ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundColor(asset.isReserved ? .red : .green)
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 12) {
                // Botão Mais Info
                Button(action: { showInfo = true }) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("MAIS INFO")
                    }
                    .font(.amiko(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .glassStyle(cornerRadius: 12)
                }
                
                // Botão Reservar
                Button(action: { showReserveSheet = true }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text(asset.isReserved ? "ALTERAR" : "RESERVAR")
                    }
                    .font(.amiko(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.white)
                    .cornerRadius(12)
                }
                .disabled(asset.isReserved) // Opcional: Desativar se já estiver reservado, ou permitir "Alterar"
                .opacity(asset.isReserved ? 0.5 : 1.0)
            }
        }
        .padding(18)
        .glassStyle(cornerRadius: 22)
        .sheet(isPresented: $showInfo) {
            ReservationDetailView(asset: asset)
        }
    }
}

struct ReservationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let asset: ReservationAsset
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Handle de fecho
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 6)
                    .padding(.top, 15)
                
                Text("DETALHES DA RESERVA")
                    .font(.amiko(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 20) {
                    InfoField(label: "EQUIPAMENTO", value: asset.name, icon: "desktopcomputer")
                    InfoField(label: "SÉRIE", value: asset.serial, icon: "barcode")
                    
                    if asset.isReserved {
                        InfoField(label: "RESERVADO POR", value: asset.reservedBy ?? "N/A", icon: "person.fill")
                        InfoField(label: "PERÍODO", value: asset.reservationDate ?? "N/A", icon: "calendar")
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Disponível para reserva imediata")
                                .font(.amiko(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(25)
                .glassStyle(cornerRadius: 22)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("FECHAR")
                        .font(.amiko(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .glassStyle(cornerRadius: 22)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 16)
        }
    }
}

struct InfoField: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.amiko(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                Text(value)
                    .font(.amiko(size: 15))
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }
}

#Preview {
    ReservationsView()
}
