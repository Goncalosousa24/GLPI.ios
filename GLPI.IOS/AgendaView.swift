import SwiftUI

struct AgendaView: View {
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var selectedAgenda: String = "Pessoal"
    
    let agendas = ["Pessoal", "Global", "Equipa"]
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Alinhado com Dashboard)
                HStack {
                    Text("AGENDA")
                        .font(.inconsolata(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    
                    HStack(spacing: 0) {
                        ForEach(agendas, id: \.self) { agenda in
                            Button(action: { 
                                withAnimation(.spring()) {
                                    selectedAgenda = agenda
                                }
                            }) {
                                Text(agenda.uppercased())
                                    .font(.amiko(size: 10, weight: .bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundColor(selectedAgenda == agenda ? .white : .white.opacity(0.4))
                                    .background(
                                        ZStack {
                                            if selectedAgenda == agenda {
                                                Capsule()
                                                    .fill(Color.white.opacity(0.15))
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                                            }
                                        }
                                    )
                            }
                        }
                    }
                    .padding(4)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                }
                .padding(.horizontal, 16)
                .padding(.top, 60) 
                .padding(.bottom, 15)
                
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
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                if mockEvents.isEmpty {
                                    Text("Nenhum evento para este dia")
                                        .font(.amiko(size: 12))
                                        .foregroundColor(.white.opacity(0.4))
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
        .ignoresSafeArea(.all, edges: .bottom)
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}

// MARK: - Calendar Subviews

struct CalendarHeader: View {
    @Binding var currentMonth: Date
    
    var body: some View {
        HStack {
            Text(monthYearString(from: currentMonth).uppercased())
                .font(.amiko(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 20) {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
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
                        .font(.amiko(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
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
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
    }
    
    private func generateDays() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthInterval.start)) else {
            return []
        }
        
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        let numberOfEmptyDays = weekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: numberOfEmptyDays)
        
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
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
                .font(.amiko(size: 14, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : (isCurrentMonth ? .white : .white.opacity(0.2)))
                .frame(width: 36, height: 36)
                .background(
                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(Color.blue)
                                .shadow(color: .blue.opacity(0.5), radius: 8)
                        } else if Calendar.current.isDateInToday(date) {
                            Circle()
                                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                        }
                    }
                )
            
            // Indicador de evento
            if hasEvent(on: date) {
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .frame(width: 4, height: 4)
            } else {
                Spacer().frame(height: 4)
            }
        }
    }
    
    private func hasEvent(on date: Date) -> Bool {
        // Simulação de eventos (15 e 20 de cada mês têm eventos)
        let day = Calendar.current.component(.day, from: date)
        return day == 15 || day == 20
    }
}

struct EventCard: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 15) {
            // Time Indicator
            VStack(alignment: .center, spacing: 2) {
                Text(event.time)
                    .font(.inconsolata(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Rectangle()
                    .fill(event.color)
                    .frame(width: 2, height: 20)
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.amiko(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(event.location)
                    .font(.amiko(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(15)
        .glassStyle(cornerRadius: 18)
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
    CalendarEvent(title: "Reunião de Equipa", time: "09:30", location: "Sala 2 / Teams", color: .blue),
    CalendarEvent(title: "Manutenção Servidor", time: "14:00", location: "Data Center", color: .orange),
    CalendarEvent(title: "Review GLPI Mobile", time: "16:30", location: "Gabinete TI", color: .purple)
]

#Preview {
    AgendaView()
}
