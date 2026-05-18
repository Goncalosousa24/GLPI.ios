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
    
    // Controlo de Calendário
    @State private var currentMonth: Date = Date()
    
    // Novas variáveis para simular reservas existentes
    @State private var selectedExistingReservation: ExistingReservation?
    let mockExistingReservations: [ExistingReservation]
    
    struct ExistingReservation: Identifiable {
        let id = UUID()
        let date: Date
        let user: String
        let comment: String
        let start: String
        let end: String
    }
    
    // Mock de utilizadores para sugestões (Padronizado com Tickets)
    private let mockUsers = ["Gonçalo Sousa", "Maria Silva", "João Mendes", "Ana Costa", "Pedro Alves", "Sónia Luz", "Rui Santos", "Carla Dias", "Nuno Lima", "Eduardo Lima", "Beatriz Silva", "Carlos Mendes", "Diana Rose"]
    
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
        // Queremos Segunda como primeiro dia (2 no sistema US)
        var firstWeekday = calendar.component(.weekday, from: startOfMonth) - 2
        if firstWeekday < 0 { firstWeekday += 7 } // Ajuste para que Segunda seja 0
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // Preencher até 42 dias para manter 6 semanas fixas (evita saltos de tamanho)
        while days.count < 42 {
            days.append(nil)
        }
        
        return days
    }
    
    init(asset: ReservationAsset) {
        self.asset = asset
        
        // Simular algumas reservas já existentes
        let cal = Calendar.current
        self.mockExistingReservations = [
            ExistingReservation(date: cal.date(byAdding: .day, value: 2, to: Date())!, user: "MARIA SILVA", comment: "Necessário para inventário local.", start: "09:00", end: "13:00"),
            ExistingReservation(date: cal.date(byAdding: .day, value: 5, to: Date())!, user: "JOÃO MENDES", comment: "Apresentação na sala de reuniões.", start: "14:30", end: "18:00")
        ]
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
                                            // Espaço vazio para alinhar dias da semana
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
                                        suggestions: getSuggestions(for: requester.name),
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
                            dismiss()
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
                }
            }
        }
        .preferredColorScheme(isLightMode ? .light : .dark)
        .sheet(item: $selectedExistingReservation) { res in
            existingReservationDetailView(res)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
        }
    }
    
    // MARK: - Helpers
    
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
        mockExistingReservations.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
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
                    Text("\(res.start) - \(res.end)")
                        .font(.inconsolata(size: 14, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(GlpiColors.universalBlue.opacity(0.1))
                        .foregroundColor(GlpiColors.universalBlue)
                        .cornerRadius(10)
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
                    
                                // Comentário com estilo de 'citação' elegante
                                HStack(spacing: 15) {
                                    Rectangle()
                                        .fill(GlpiColors.universalBlue.opacity(0.3))
                                        .frame(width: 3)
                                        .cornerRadius(1.5)
                                    
                                    Text(res.comment)
                                        .font(.amiko(size: 13, weight: .regular))
                                        .italic()
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.7))
                                        .lineSpacing(4)
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 5)
                            }
                
                Spacer()
            }
            .padding(25)
        }
    }
    
    private func getSuggestions(for text: String) -> [String] {
        return text.isEmpty ? mockUsers : mockUsers.filter { $0.localizedCaseInsensitiveContains(text) && $0 != text }
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
            // Data à esquerda
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
            
            // Pickers de Hora
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
    
    // MARK: - Helpers
    
    private func isDateSelected(_ date: Date) -> Bool {
        reservations.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    private func toggleDate(_ date: Date) {
        if let index = reservations.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            reservations.remove(at: index)
        } else {
            reservations.append(DayReservation(date: date))
            // Ordenar por data
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
                    .foregroundColor(GlpiColors.dynamicText)
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
