//
//  ProfileStatisticsView.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 27/04/2026.
//

import SwiftUI
import Charts
import Combine

struct ProfileStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    @State private var activeMonthIndex: Int = 0
    @State private var loopProgress: Double = 0.0
    @State private var isPaused: Bool = false
    @State private var pauseTask: Task<Void, Never>? = nil
    @State private var animateCharts: Bool = false
    @State private var isLoading: Bool = true
    @State private var trigger: Int = 0
    
    @State private var countNew: Int = 0
    @State private var countInProgress: Int = 0
    @State private var countResolved: Int = 0
    @State private var countPriority: Int = 0
    
    // Personal performance data (Mock/Fallback)
    @State private var performanceData: [PerformanceStat] = []
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    private var activePoint: PerformanceStat {
        if activeMonthIndex >= 0 && activeMonthIndex < performanceData.count {
            return performanceData[activeMonthIndex]
        }
        return performanceData.isEmpty ? PerformanceStat(month: "", attributed: 0, resolved: 0) : performanceData[0]
    }
    
    private func triggerManualPause() {
        pauseTask?.cancel()
        withAnimation(.easeInOut(duration: 0.5)) {
            loopProgress = 0.0
            isPaused = true
        }
        
        pauseTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation { isPaused = false }
                }
            }
        }
    }
    
    private func selectMonth(index: Int) {
        withAnimation(.easeInOut(duration: 0.5)) {
            activeMonthIndex = index
        }
        triggerManualPause()
    }
    
    func loadPersonalStatistics() async {
        guard !PreferenceManager.shared.isOfflineMode else {
            await MainActor.run {
                self.countNew = 3
                self.countInProgress = 5
                self.countResolved = 12
                self.countPriority = 2
                self.performanceData = [
                    PerformanceStat(month: "JAN", attributed: 2, resolved: 1),
                    PerformanceStat(month: "FEV", attributed: 4, resolved: 3),
                    PerformanceStat(month: "MAR", attributed: 3, resolved: 4),
                    PerformanceStat(month: "ABR", attributed: 6, resolved: 5),
                    PerformanceStat(month: "MAI", attributed: 4, resolved: 6),
                    PerformanceStat(month: "JUN", attributed: 8, resolved: 7)
                ]
                self.isLoading = false
                withAnimation(.spring(response: 1.0, dampingFraction: 1.0)) {
                    self.animateCharts = true
                }
            }
            return
        }
        
        do {
            let userId = PreferenceManager.shared.userId
            let response = try await GLPIClient.shared.getTodosMeusTicketsStats(userId: userId)
            let allTickets = response.data ?? []
            
            let calendar = Calendar.current
            let ptLocale = Locale(identifier: "pt_PT")
            let formatMesCurto = DateFormatter()
            formatMesCurto.dateFormat = "MMM"
            formatMesCurto.locale = ptLocale
            
            // 1. Calcular valores dos cartões KPI
            var newCount = 0
            var inProgressCount = 0
            var resolvedCurrentMonthCount = 0
            var priorityCount = 0
            
            let currentMonthString = {
                let formatApi = DateFormatter()
                formatApi.dateFormat = "yyyy-MM"
                formatApi.locale = Locale(identifier: "en_US_POSIX")
                return formatApi.string(from: Date())
            }()
            
            for ticket in allTickets {
                // A API pode devolver status e priority como Int, Double ou String
                // Usa String(describing:) + remoção de ".0" para lidar com todos os casos (igual ao mapToTickets)
                let statusRaw = String(describing: ticket["12"]?.value ?? "0").replacingOccurrences(of: ".0", with: "")
                let status = Int(statusRaw) ?? 0
                
                let priorityRaw = String(describing: ticket["3"]?.value ?? "0").replacingOccurrences(of: ".0", with: "")
                let priority = Int(priorityRaw) ?? 0
                
                let dateUpdate = ticket["19"]?.value as? String ?? ""
                
                if status == 1 {
                    newCount += 1
                }
                if status == 2 || status == 3 || status == 4 {
                    inProgressCount += 1
                }
                if (status == 5 || status == 6) && dateUpdate.hasPrefix(currentMonthString) {
                    resolvedCurrentMonthCount += 1
                }
                if (priority == 4 || priority == 5 || priority == 6) && (status >= 1 && status <= 4) {
                    priorityCount += 1
                }
            }
            
            // 2. Calcular dados de performance para os últimos 6 meses (excluindo o atual)
            var stats: [PerformanceStat] = []
            for mesesAtras in (1...6).reversed() {
                if let date = calendar.date(byAdding: .month, value: -mesesAtras, to: Date()) {
                    let monthLabel = formatMesCurto.string(from: date).uppercased()
                    let formatterApi = DateFormatter()
                    formatterApi.dateFormat = "yyyy-MM"
                    formatterApi.locale = Locale(identifier: "en_US_POSIX")
                    let mesChave = formatterApi.string(from: date)
                    
                    var contCriados = 0
                    var contFinalizados = 0
                    
                    for ticket in allTickets {
                        let dateCreated = ticket["15"]?.value as? String ?? ""
                        let dateUpdate = ticket["19"]?.value as? String ?? ""
                        let statusRaw = String(describing: ticket["12"]?.value ?? "0").replacingOccurrences(of: ".0", with: "")
                        let status = Int(statusRaw) ?? 0
                        
                        if dateCreated.hasPrefix(mesChave) {
                            contCriados += 1
                        }
                        if (status == 5 || status == 6) && dateUpdate.hasPrefix(mesChave) {
                            contFinalizados += 1
                        }
                    }
                    stats.append(PerformanceStat(month: monthLabel, attributed: contCriados, resolved: contFinalizados))
                }
            }
            
            await MainActor.run {
                if !stats.isEmpty {
                    self.performanceData = stats
                }
                self.countNew = newCount
                self.countInProgress = inProgressCount
                self.countResolved = resolvedCurrentMonthCount
                self.countPriority = priorityCount
                self.trigger += 1
                self.isLoading = false
                withAnimation(.spring(response: 1.0, dampingFraction: 1.0)) {
                    self.animateCharts = true
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                withAnimation(.spring(response: 1.0, dampingFraction: 1.0)) {
                    self.animateCharts = true
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            (isLightMode ? Color.white : Color.black).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Sincronizado com Imagem 2)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(GlpiColors.universalBlue)
                    }
                    Spacer()
                    Text("ESTATÍSTICAS")
                        .font(.amiko(size: 18, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText)
                    Spacer()
                    Color.clear.frame(width: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .frame(height: 60)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        
                        // MARK: - Summary Grid (Cards)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            DashboardStatCard(title: "NOVOS", value: countNew, color: .white, trigger: trigger)
                            DashboardStatCard(title: "EM PROGRESSO", value: countInProgress, color: .blue, trigger: trigger)
                            DashboardStatCard(title: "FINALIZADOS", value: countResolved, color: .green, trigger: trigger)
                            DashboardStatCard(title: "PRIORITÁRIOS", value: countPriority, color: .yellow, trigger: trigger)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        // MARK: - Performance Chart (Twin Style from Image 2)
                        VStack(alignment: .leading, spacing: 15) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DESEMPENHO INDIVIDUAL")
                                        .font(.amiko(size: 14, weight: .black))
                                        .foregroundColor(GlpiColors.dynamicBlueText)
                                    Text("ÚLTIMOS 6 MESES")
                                        .font(.amiko(size: 9, weight: .bold))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                                }
                                
                                Spacer()
                                
                                // Barra de Progresso
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(GlpiColors.dynamicText.opacity(0.1))
                                        .frame(width: 60, height: 4)
                                    
                                    if !isPaused {
                                        Capsule()
                                            .fill(GlpiColors.universalBlue)
                                            .frame(width: 60 * loopProgress, height: 4)
                                    }
                                }
                                .padding(.top, 6)
                            }
                            
                            if !performanceData.isEmpty {
                                let maxVal = performanceData.map { Double($0.attributed + $0.resolved) }.max() ?? 100
                                Chart {
                                    ForEach(performanceData) { point in
                                        let total = Double(point.attributed + point.resolved)
                                        LineMark(
                                            x: .value("Mês", point.month),
                                            y: .value("Tickets", animateCharts ? total : 0)
                                        )
                                        .foregroundStyle(GlpiColors.universalBlue)
                                        .interpolationMethod(.catmullRom)
                                        
                                        AreaMark(
                                            x: .value("Mês", point.month),
                                            y: .value("Tickets", animateCharts ? total : 0)
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [GlpiColors.universalBlue.opacity(0.3), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .interpolationMethod(.catmullRom)
                                    }
                                    
                                    PointMark(
                                        x: .value("Mês", activePoint.month),
                                        y: .value("Tickets", animateCharts ? Double(activePoint.attributed + activePoint.resolved) : 0)
                                    )
                                    .foregroundStyle(GlpiColors.universalBlue)
                                    .symbolSize(150)
                                }
                                .frame(height: 120)
                                .chartYAxis(.hidden)
                                .chartXAxis(.hidden)
                                .chartYScale(domain: 0 ... (maxVal > 0 ? maxVal * 1.15 : 10))
                            }
                            
                            // Eixo de Meses
                            HStack {
                                ForEach(Array(performanceData.enumerated()), id: \.offset) { index, point in
                                    let isActive = index == activeMonthIndex
                                    Button(action: { selectMonth(index: index) }) {
                                        Text(point.month)
                                            .font(.amiko(size: 10, weight: isActive ? .black : .regular))
                                            .foregroundColor(isActive ? GlpiColors.dynamicBlueText : GlpiColors.dynamicText.opacity(0.2))
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                            .padding(.top, 5)
                            
                            Spacer()
                            
                            // Footer de Dados (XX TICKETS)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ATRIBUÍDOS")
                                        .font(.amiko(size: 10, weight: .bold))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.6))
                                    Text("\(activePoint.attributed) TICKETS")
                                        .font(.amiko(size: 12, weight: .black))
                                        .foregroundColor(GlpiColors.dynamicText)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("FINALIZADOS")
                                        .font(.amiko(size: 10, weight: .bold))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.6))
                                    Text("\(activePoint.resolved) TICKETS")
                                        .font(.amiko(size: 12, weight: .black))
                                        .foregroundColor(GlpiColors.dynamicText)
                                }
                            }
                        }
                        .padding(20)
                        .frame(height: 280)
                        .background(GlpiColors.dynamicOffWhite)
                        .cornerRadius(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .strokeBorder(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.15), lineWidth: GlpiMetrics.inactiveBorderWidth)
                        )
                        .padding(.horizontal, 16)
                        .onTapGesture { triggerManualPause() }
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 10)
                }
                .scrollDismissesKeyboard(.immediately)
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
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            Task {
                await loadPersonalStatistics()
            }
        }
        .onReceive(timer) { _ in
            guard animateCharts && !performanceData.isEmpty else { return }
            if !isPaused {
                loopProgress += 0.05 / 3.0
                if loopProgress >= 1.0 {
                    loopProgress = 0.0
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        activeMonthIndex = (activeMonthIndex + 1) % performanceData.count
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileStatisticsView()
}
