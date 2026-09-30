import SwiftUI

struct DayReservation: Identifiable {
    let id: Date
    var date: Date
    var startTime: Date
    var endTime: Date
    
    init(date: Date) {
        self.id = date
        self.date = date
        self.startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        self.endTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? date
    }
}

struct AssetReservationView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    
    let asset: ReservationAsset
    
    @State private var reservations: [DayReservation] = []
    @State private var requester = TechnicianAssignment(name: "")
    @State private var reservationComment = ""
    @State private var isLoading = true
    
    // Controlo de Calendário
    @State private var currentMonth: Date = Date()
    
    // Reservas existentes carregadas do GLPI
    @State private var existingReservations: [ExistingReservation] = []
    @State private var selectedExistingReservation: ExistingReservation?
    @State private var showDeleteConfirmation = false
    
    struct ExistingReservation: Identifiable {
        let id: Int // ID da reserva no GLPI
        let date: Date
        let user: String
        let comment: String
        let start: String
        let end: String
    }
    
    // Mock de utilizadores para sugestões
    private let mockUsers = ["Gonçalo Sousa", "Maria Silva", "João Mendes", "Ana Costa", "Pedro Alves", "Sónia Luz", "Rui Santos", "Carla Dias", "Nuno Lima", "Eduardo Lima", "Beatriz Silva", "Carlos Mendes", "Diana Rose"]
    @State private var usersSuggestions: [String] = []
    @State private var allUsers: [(id: String, name: String)] = []
    
    @FocusState private var focusedField: Field?
    @FocusState private var focusedId: UUID?
    
    enum Field {
        case comment
    }
    
    // Auxiliares para o Calendário
    let calendar = Calendar.current
    private var calendarDays: [Date?] {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let startOfMonth = calendar.date(from: components)!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        // Calcular o dia da semana do primeiro dia do mês (1 = Domingo, 2 = Segunda...)
        var firstWeekday = calendar.component(.weekday, from: startOfMonth) - 2
        if firstWeekday < 0 { firstWeekday += 7 } // Ajuste para que Segunda seja 0
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        while days.count < 42 {
            days.append(nil)
        }
        
        return days
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
                .universalBackgroundDismiss { hideKeyboard() }
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        
                        // 1. Mini Card do Ativo
                        assetMiniCard
                        
                        // 2. Calendário Interativo
                        VStack(alignment: .leading, spacing: 15) {
                            Text("SELECIONE OS DIAS")
                                .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                                .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                                .padding(.leading, 5)
                            
                            VStack(spacing: 20) {
                                // CABEÇALHO DO MÊS
                                HStack {
                                    Button(action: { changeMonth(by: -1) }) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(GlpiColors.universalBlue)
                                            .padding(10)
                                            .background(GlpiColors.dynamicOffWhite)
                                            .clipShape(Circle())
                                    }
                                    
                                    Spacer()
                                    
                                    Text(monthYearString(for: currentMonth))
                                        .font(.amiko(size: 16, weight: .black))
                                        .foregroundColor(GlpiColors.dynamicText)
                                    
                                    Spacer()
                                    
                                    Button(action: { changeMonth(by: 1) }) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(GlpiColors.universalBlue)
                                            .padding(10)
                                            .background(GlpiColors.dynamicOffWhite)
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.bottom, 10)
                                
                                let columns = Array(repeating: GridItem(.flexible()), count: 7)
                                
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(Array(["S", "T", "Q", "Q", "S", "S", "D"].enumerated()), id: \.offset) { _, day in
                                        Text(day)
                                            .font(.amiko(size: 11, weight: .black))
                                            .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                                            .frame(width: 32, height: 32)
                                    }
                                    
                                    ForEach(0..<calendarDays.count, id: \.self) { index in
                                        if let date = calendarDays[index] {
                                            let isSelected = isDateSelected(date)
                                            let existing = getExistingReservation(for: date)
                                            
                                            Button(action: {
                                                if let existing = existing {
                                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                                    selectedExistingReservation = existing
                                                } else {
                                                    toggleDate(date)
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                }
                                            }) {
                                                ZStack {
                                                    if isSelected {
                                                        Circle().fill(GlpiColors.universalBlue)
                                                    } else if existing != nil {
                                                        Circle().fill(GlpiColors.dynamicOffWhite)
                                                        Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                    }
                                                    
                                                    Text("\(calendar.component(.day, from: date))")
                                                        .font(.amiko(size: 13, weight: isSelected || existing != nil ? .black : .bold))
                                                        .foregroundColor(isSelected ? .white : (existing != nil ? GlpiColors.dynamicText.opacity(0.4) : GlpiColors.dynamicText))
                                                        .multilineTextAlignment(.center)
                                                }
                                                .frame(width: 32, height: 32)
                                            }
                                        } else {
                                            Color.clear
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 20)
                            .glassStyle(cornerRadius: 25)
                        }
                        
                        // 3. Detalhes de Horário por Dia
                        if !reservations.isEmpty {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("DEFINIR HORÁRIOS POR DIA")
                                    .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                                    .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                                    .padding(.leading, 5)
                                
                                VStack(spacing: 12) {
                                    ForEach($reservations) { $res in
                                        dayTimePickerRow(reservation: $res)
                                    }
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // 4. Dados Adicionais (Requerente e Comentário)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("DADOS DA RESERVA")
                                .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                                .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                                .padding(.leading, 5)
                            
                            VStack(spacing: 15) {
                                // Requerente com Autocomplete
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("RESERVADO POR")
                                        .font(.amiko(size: 9, weight: .bold))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                        .padding(.leading, 5)
                                    
                                    AssignmentRowView(
                                        assignment: $requester,
                                        focusedId: $focusedId,
                                        showDelete: false,
                                        suggestions: usersSuggestions,
                                        onDelete: {}
                                    )
                                }
                                
                                // Comentário
                                inputField(
                                    placeholder: "COMENTÁRIO ADICIONAL (OPCIONAL)",
                                    text: $reservationComment,
                                    focus: .comment
                                )
                            }
                        }
                        
                        // 5. Botão Reservar
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                await confirmarReservas()
                            }
                        }) {
                            Text(reservations.isEmpty ? "SELECIONE UM DIA" : (requester.name.isEmpty ? "FALTA O NOME" : "CONFIRMAR \(reservations.count) RESERVAS"))
                                .font(.amiko(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    Capsule()
                                        .fill(reservations.isEmpty || requester.name.isEmpty ? GlpiColors.universalBlue.opacity(0.3) : GlpiColors.universalBlue)
                                        .shadow(color: GlpiColors.universalBlue.opacity(0.3), radius: 15, y: 8)
                                )
                        }
                        .disabled(reservations.isEmpty || requester.name.isEmpty)
                        .padding(.top, 10)
                        .padding(.bottom, 60)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            focusedField = nil
                            focusedId = nil
                            hideKeyboard()
                        }
                    }
                }
            }
            
            if isLoading {
                ZStack {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                        .scaleEffect(1.5)
                }
            }
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
        .onAppear {
            let uName = PreferenceManager.shared.userName ?? "Gonçalo Sousa"
            let formattedName = formatarStringNome(uName) ?? uName
            requester = TechnicianAssignment(name: formattedName, userId: String(PreferenceManager.shared.userId))
            
            isLoading = true
            Task {
                await carregarReservasExistentes()
                updateSuggestions(query: "")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
        .onChange(of: requester.name) { newValue in
            if focusedId == requester.id {
                updateSuggestions(query: newValue)
            }
        }
        .sheet(item: $selectedExistingReservation) { res in
            existingReservationDetailView(res)
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.hidden)
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("ELIMINAR RESERVA"),
                message: Text("Tem a certeza que deseja eliminar esta reserva definitivamente?"),
                primaryButton: .destructive(Text("ELIMINAR")) {
                    if let res = selectedExistingReservation {
                        Task {
                            await eliminarReserva(id: res.id)
                        }
                    }
                },
                secondaryButton: .cancel(Text("CANCELAR"))
            )
        }
    }
    
    // MARK: - API / Logic Methods
    
    private func changeMonth(by amount: Int) {
        if let newDate = calendar.date(byAdding: .month, value: amount, to: currentMonth) {
            withAnimation {
                currentMonth = newDate
            }
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date).uppercased()
    }
    
    private func getExistingReservation(for date: Date) -> ExistingReservation? {
        existingReservations.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func carregarReservasExistentes() async {
        do {
            let resList = try await GLPIClient.shared.getReservationsForItem(resItemId: asset.reservationItemsId)
            
            let sdf = DateFormatter()
            sdf.dateFormat = "yyyy-MM-dd HH:mm:ss"
            sdf.timeZone = TimeZone(secondsFromGMT: 0)
            
            let timeSdf = DateFormatter()
            timeSdf.dateFormat = "HH:mm"
            
            var loaded: [ExistingReservation] = []
            for res in resList {
                guard let id = res["id"] as? Int ?? (res["id"] as? String).flatMap(Int.init),
                      let beginStr = res["begin"] as? String,
                      let endStr = res["end"] as? String else { continue }
                
                let beginDate = sdf.date(from: beginStr) ?? Date()
                let endDate = sdf.date(from: endStr) ?? Date()
                
                var userName = "N/A"
                if let uField = res["users_id"] {
                    if let uArr = uField as? [Any], uArr.count > 1, let uName = uArr[1] as? String {
                        userName = uName
                    } else if let uDict = uField as? [String: Any], let uName = uDict["name"] as? String {
                        userName = uName
                    } else {
                        userName = String(describing: uField)
                    }
                }
                
                let formattedName = formatarStringNome(userName) ?? userName
                let comment = res["comment"] as? String ?? ""
                
                let startStr = timeSdf.string(from: beginDate)
                let endStrTime = timeSdf.string(from: endDate)
                
                loaded.append(ExistingReservation(
                    id: id,
                    date: beginDate,
                    user: formattedName,
                    comment: comment,
                    start: startStr,
                    end: endStrTime
                ))
            }
            
            await MainActor.run {
                self.existingReservations = loaded
            }
        } catch {
            print("Erro ao carregar reservas existentes: \(error)")
        }
    }
    
    private func eliminarReserva(id: Int) async {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let success = try await GLPIClient.shared.deleteReservation(id: id)
            if success {
                await carregarReservasExistentes()
            }
        } catch {
            print("Erro ao eliminar reserva: \(error)")
        }
        
        await MainActor.run {
            self.selectedExistingReservation = nil
            self.isLoading = false
        }
    }
    
    private func confirmarReservas() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        let sdf = DateFormatter()
        sdf.dateFormat = "yyyy-MM-dd HH:mm:ss"
        sdf.timeZone = TimeZone(secondsFromGMT: 0)
        
        let userId = Int(requester.userId ?? "") ?? PreferenceManager.shared.userId
        
        var allSucceeded = true
        for res in reservations {
            let calendar = Calendar.current
            
            let startComponents = calendar.dateComponents([.hour, .minute], from: res.startTime)
            let endComponents = calendar.dateComponents([.hour, .minute], from: res.endTime)
            
            guard let finalStart = calendar.date(bySettingHour: startComponents.hour ?? 9, minute: startComponents.minute ?? 0, second: 0, of: res.date),
                  let finalEnd = calendar.date(bySettingHour: endComponents.hour ?? 18, minute: endComponents.minute ?? 0, second: 0, of: res.date) else {
                continue
            }
            
            let startStr = sdf.string(from: finalStart)
            let endStr = sdf.string(from: finalEnd)
            
            do {
                let success = try await GLPIClient.shared.createReservation(
                    reservationItemsId: asset.reservationItemsId,
                    begin: startStr,
                    end: endStr,
                    comment: reservationComment,
                    userId: userId
                )
                if !success {
                    allSucceeded = false
                }
            } catch {
                print("Erro ao criar reserva: \(error)")
                allSucceeded = false
            }
        }
        
        await MainActor.run {
            self.isLoading = false
            if allSucceeded {
                dismiss()
            } else {
                dismiss()
            }
        }
    }
    
    private func updateSuggestions(query: String) {
        Task {
            do {
                let results = try await GLPIClient.shared.searchUsers(query: query)
                await MainActor.run {
                    self.allUsers = results.map { (id: $0.id, name: formatarStringNome($0.name) ?? $0.name) }
                    self.usersSuggestions = self.allUsers.map { $0.name }
                    
                    if let matched = self.allUsers.first(where: { $0.name.lowercased() == query.lowercased() }) {
                        self.requester.userId = matched.id
                    }
                }
            } catch {
                print("Erro a pesquisar utilizadores: \(error)")
            }
        }
    }
    
    // MARK: - Subcomponents
    
    private func existingReservationDetailView(_ res: ExistingReservation) -> some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RESERVA EXISTENTE")
                            .font(.amiko(size: 11, weight: .black))
                            .foregroundColor(GlpiColors.dynamicBlueText)
                        Text(formatDate(res.date))
                            .font(.amiko(size: 18, weight: .black))
                            .foregroundColor(GlpiColors.dynamicText)
                    }
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image("pessoa")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundColor(GlpiColors.universalBlue)
                        Text(res.user)
                            .font(.amiko(size: 14, weight: .black))
                    }
                    
                    HStack(spacing: 15) {
                        Rectangle()
                            .fill(GlpiColors.universalBlue)
                            .frame(width: 3)
                            .cornerRadius(1.5)
                        
                        Text(res.comment.isEmpty ? "Sem comentário." : res.comment)
                            .font(.amiko(size: 13, weight: .regular))
                            .italic()
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.7))
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 5)
                }
                
                Spacer()
                
                // Botão de Eliminar Reserva
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("ELIMINAR RESERVA")
                    }
                    .font(.amiko(size: 13, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red)
                    .cornerRadius(15)
                }
            }
            .padding(25)
        }
    }
    
    private func inputField(placeholder: String, text: Binding<String>, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                TextField("", text: text)
                    .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                    .foregroundColor(GlpiColors.dynamicText)
                    .focused($focusedField, equals: focus)
                    .tint(GlpiColors.universalBlue)
                    .placeholder(when: text.wrappedValue.isEmpty && focusedField != focus) {
                        Text(placeholder)
                            .font(.amiko(size: GlpiMetrics.FORM_VALUE_FONT_SIZE, weight: GlpiMetrics.FORM_VALUE_WEIGHT))
                            .foregroundColor(GlpiMetrics.FORM_PLACEHOLDER_COLOR)
                    }
            }
            .padding(.horizontal, 20)
            .frame(height: 54)
            .glassStyle(cornerRadius: 15, isSelection: focusedField == focus)
        }
    }
    
    private func dayTimePickerRow(reservation: Binding<DayReservation>) -> some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(reservation.wrappedValue.date))
                    .font(.amiko(size: 14, weight: .black))
                    .foregroundColor(GlpiColors.universalBlue)
                Text("DIA SELECIONADO")
                    .font(.amiko(size: 9, weight: .bold))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
            }
            .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("INÍCIO")
                        .font(.amiko(size: 8, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                    DatePicker("", selection: reservation.startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(GlpiColors.universalBlue)
                        .scaleEffect(0.9)
                }
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.2))
                    .padding(.top, 10)
                
                VStack(spacing: 2) {
                    Text("FIM")
                        .font(.amiko(size: 8, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                    DatePicker("", selection: reservation.endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(GlpiColors.universalBlue)
                        .scaleEffect(0.9)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .glassStyle(cornerRadius: 18)
    }
    
    private func isDateSelected(_ date: Date) -> Bool {
        reservations.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func toggleDate(_ date: Date) {
        if let index = reservations.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            reservations.remove(at: index)
        } else {
            reservations.append(DayReservation(date: date))
            reservations.sort { $0.date < $1.date }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: GlpiMetrics.universalBackIcon)
                    .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                    .foregroundColor(GlpiColors.universalBlue)
            }
            .padding(.leading, GlpiMetrics.padding + 5)
            
            Spacer()
            
            Text("DETALHES DE RESERVA")
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicBlueText)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 5)
        .frame(height: GlpiMetrics.navAreaHeight - 5)
    }
    
    private var assetMiniCard: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(GlpiColors.universalBlue.opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: asset.type.rawValue)
                    .foregroundColor(GlpiColors.universalBlue)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name.uppercased())
                    .font(.amiko(size: 15, weight: .black))
                    .foregroundColor(GlpiColors.dynamicText)
                Text(asset.serial.uppercased())
                    .font(.amiko(size: 12, weight: .bold))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(15)
        .glassStyle(cornerRadius: 22)
    }
}
