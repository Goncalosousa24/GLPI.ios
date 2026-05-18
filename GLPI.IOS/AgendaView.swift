import SwiftUI

struct AgendaView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLightMode_V2") var isLightMode: Bool = true
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var selectedAgenda: String = "Pessoal"
    
    let agendas = ["Pessoal", "Geral"]
    @Namespace private var toggleNamespace
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 1. TOP TOGGLE (Sincronizado com Barra de Pesquisa do Dashboard/Inventário)
                HStack(spacing: 0) {
                    ForEach(agendas, id: \.self) { agenda in
                        Button(action: { 
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedAgenda = agenda
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }) {
                            Image(agenda == "Pessoal" ? (selectedAgenda == "Pessoal" ? "pessoa" : "pessoa2") : (selectedAgenda == "Geral" ? "grupo" : "grupo2"))
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(selectedAgenda == agenda ? (isLightMode ? .white : GlpiColors.dynamicText) : GlpiColors.dynamicText.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: GlpiMetrics.headerHeight - 8) // Altura interna ajustada
                                .background(
                                    ZStack {
                                        if selectedAgenda == agenda {
                                            Capsule()
                                                .fill(GlpiColors.universalBlue)
                                                .matchedGeometryEffect(id: "TOGGLE", in: toggleNamespace)
                                        }
                                    }
                                )
                        }
                    }
                }
                .padding(4)
                .frame(height: GlpiMetrics.headerHeight)
                .background(Capsule().fill(GlpiColors.dynamicOffWhite))
                .overlay(Capsule().stroke(GlpiColors.dynamicBorder, lineWidth: GlpiMetrics.inactiveBorderWidth))
                .padding(.horizontal, GlpiMetrics.padding)
                .padding(.top, GlpiMetrics.topPadding)
                .padding(.bottom, 5)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        ScrollOffsetTracker()
                        
                        // Modern Calendar
                        VStack(spacing: 20) {
                            CalendarHeader(currentMonth: $currentMonth)
                            
                            CalendarGrid(selectedDate: $selectedDate, currentMonth: currentMonth)
                        }
                        .padding(20)
                        .glassStyle(cornerRadius: 25)
                        .padding(.horizontal, 16)
                        
                        // Events List
                        VStack(alignment: .leading, spacing: 15) {
                            Text("EVENTOS - \(selectedAgenda.uppercased())")
                                .font(.amiko(size: GlpiMetrics.FORM_LABEL_FONT_SIZE, weight: GlpiMetrics.FORM_LABEL_WEIGHT))
                                .foregroundColor(GlpiMetrics.FORM_LABEL_COLOR)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                if mockEvents.isEmpty {
                                    Text("Nenhum evento para este dia")
                                        .font(.amiko(size: 12))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 40)
                                } else {
                                    ForEach(mockEvents) { event in
                                        EventCard(event: event)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 120)
                    }
                }
            }
        }
        .frame(width: UIScreen.main.bounds.width)
        .clipped()
        .preferredColorScheme(isLightMode ? .light : .dark)
        .tint(GlpiColors.universalBlue)
    }
}

// MARK: - Calendar Subviews

struct CalendarHeader: View {
    @Binding var currentMonth: Date
    
    var body: some View {
        HStack {
            Text(monthYearString(from: currentMonth).uppercased())
                .font(.amiko(size: 18, weight: .black))
                .foregroundColor(GlpiColors.dynamicText)
            
            Spacer()
            
            HStack(spacing: 15) {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(GlpiColors.universalBlue)
                        .padding(10)
                        .background(GlpiColors.dynamicOffWhite)
                        .clipShape(Circle())
                }
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(GlpiColors.universalBlue)
                        .padding(10)
                        .background(GlpiColors.dynamicOffWhite)
                        .clipShape(Circle())
                }
            }
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "pt_PT")
        return formatter.string(from: date)
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}

struct CalendarGrid: View {
    @Binding var selectedDate: Date
    let currentMonth: Date
    
    private let calendar = Calendar.current
    private let daysInWeek = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
    
    var body: some View {
        VStack(spacing: 15) {
            // Dias da Semana
            HStack {
                ForEach(daysInWeek, id: \.self) { day in
                    Text(day.uppercased())
                        .font(.amiko(size: 11, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }
            
            let days = generateDays()
            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        // Célula vazia mas com espaço ocupado
                        Color.clear.frame(height: 48)
                    }
                }
            }
            .frame(height: 338, alignment: .top) // Altura fixa para exatamente 6 semanas (48px cada + spacing)
        }
    }
    
    private func generateDays() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        let startOfMonth = calendar.date(from: components)!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        // Calcular o dia da semana do primeiro dia do mês (Ajustado para começar na Segunda se necessário)
        // Por padrão weekday: 1 é Domingo.
        var firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        if firstWeekday < 0 { firstWeekday += 7 }
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // FIX: Preencher até 42 dias para manter 6 semanas fixas (REQUISITO USER)
        while days.count < 42 {
            days.append(nil)
        }
        
        return days
    }
}

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.amiko(size: 14, weight: isSelected ? .black : .bold))
                .foregroundColor(isSelected ? .white : (isCurrentMonth ? GlpiColors.dynamicText : GlpiColors.dynamicText.opacity(0.2)))
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(GlpiColors.universalBlue)
                        } else if Calendar.current.isDateInToday(date) {
                            Circle()
                                .stroke(GlpiColors.universalBlue.opacity(0.5), lineWidth: 2)
                        }
                    }
                )
            
            // Indicadores de Evento (Azul e Vermelho Pulsante)
            HStack(spacing: 3) {
                if hasEvent(on: date) {
                    Circle()
                        .fill(isSelected ? .white : GlpiColors.universalBlue)
                        .frame(width: 4, height: 4)
                }
                
                if hasOverdueEvent(on: date) {
                    PulsingRedDot(isSelected: isSelected)
                }
            }
            .frame(height: 4)
        }
    }
    
    private func hasEvent(on date: Date) -> Bool {
        // Simulação: Dias 15 e 20 têm eventos normais
        let day = Calendar.current.component(.day, from: date)
        return day == 15 || day == 20
    }
    
    private func hasOverdueEvent(on date: Date) -> Bool {
        // Simulação: Dias 10 e 18 têm eventos atrasados (Bolinhas Vermelhas)
        let day = Calendar.current.component(.day, from: date)
        return day == 10 || day == 18
    }
}

struct PulsingRedDot: View {
    let isSelected: Bool
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? .white : GlpiColors.deleteRed)
                .opacity(animate ? 0 : 0.6)
                .scaleEffect(animate ? 3.5 : 1)
            
            Circle()
                .fill(isSelected ? .white : GlpiColors.deleteRed)
                .frame(width: 4, height: 4)
        }
        .frame(width: 4, height: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

struct EventCard: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 20) {
            // Time Indicator (Retângulo Premium)
            VStack(alignment: .center, spacing: 4) {
                Text(event.time)
                    .font(.inconsolata(size: 14, weight: .bold))
                    .foregroundColor(GlpiColors.universalBlue)
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(GlpiColors.universalBlue.opacity(0.3))
                    .frame(width: 2, height: 25)
            }
            .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title.uppercased())
                    .font(.amiko(size: 14, weight: .black))
                    .foregroundColor(GlpiColors.dynamicText)
                
                HStack(spacing: 5) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10))
                    Text(event.location.uppercased())
                        .font(.amiko(size: 10, weight: .bold))
                }
                .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
            }
            
            Spacer()
            
            // Badge de Estado do Evento (Opcional)
            Circle()
                .fill(event.color)
                .frame(width: 8, height: 8)
                .shadow(color: event.color.opacity(0.5), radius: 4)
        }
        .padding(20)
        .glassStyle(cornerRadius: 22)
    }
}

// MARK: - Models

struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let time: String
    let location: String
    let color: Color
}

let mockEvents = [
    CalendarEvent(title: "Reunião de Equipa", time: "09:30", location: "Sala 2 / Teams", color: GlpiColors.universalBlue),
    CalendarEvent(title: "Manutenção Servidor", time: "14:00", location: "Data Center", color: GlpiColors.deleteRed),
    CalendarEvent(title: "Review GLPI Mobile", time: "16:30", location: "Gabinete TI", color: GlpiColors.universalBlue)
]

#Preview {
    AgendaView()
}
