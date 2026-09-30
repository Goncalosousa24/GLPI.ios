import SwiftUI
import Charts
import Combine

struct CategoryStat: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let color: Color
}

struct StatisticsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var activeMonthIndex: Int = 0
    @State private var loopProgress: Double = 0.0
    @State private var isPaused: Bool = false
    @State private var pauseTask: Task<Void, Never>? = nil
    @State private var animateCharts: Bool = false
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    // Mock Data para os últimos 6 meses completos (Nov-Abr)
    @State private var performanceData: [PerformanceStat] = []
    
    @State private var categoryData: [CategoryStat] = []
    
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
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 segundos
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
    
    func loadStatistics() async {
        guard !PreferenceManager.shared.isOfflineMode else {
            await MainActor.run {
                self.performanceData = [
                    PerformanceStat(month: "NOV", attributed: 45, resolved: 38),
                    PerformanceStat(month: "DEZ", attributed: 52, resolved: 44),
                    PerformanceStat(month: "JAN", attributed: 38, resolved: 41),
                    PerformanceStat(month: "FEV", attributed: 61, resolved: 55),
                    PerformanceStat(month: "MAR", attributed: 48, resolved: 50),
                    PerformanceStat(month: "ABR", attributed: 55, resolved: 53)
                ]
                self.categoryData = [
                    CategoryStat(name: "SOFTWARE", count: 124, color: GlpiColors.universalBlue),
                    CategoryStat(name: "HARDWARE", count: 89, color: Color(red: 0.2, green: 0.4, blue: 0.8)),
                    CategoryStat(name: "REDE", count: 65, color: Color(red: 0.4, green: 0.6, blue: 0.95)),
                    CategoryStat(name: "OUTROS", count: 42, color: Color(red: 0.7, green: 0.8, blue: 1.0))
                ]
                self.isLoading = false
                withAnimation(.spring(response: 1.0, dampingFraction: 1.0)) {
                    self.animateCharts = true
                }
            }
            return
        }
        
        do {
            let calendar = Calendar.current
            let ptLocale = Locale(identifier: "pt_PT")
            
            let formatApi = DateFormatter()
            formatApi.dateFormat = "yyyy-MM"
            formatApi.locale = Locale(identifier: "en_US_POSIX")
            
            let formatFull = DateFormatter()
            formatFull.dateFormat = "yyyy-MM-dd"
            formatFull.locale = Locale(identifier: "en_US_POSIX")
            
            let formatMesCurto = DateFormatter()
            formatMesCurto.dateFormat = "MMM"
            formatMesCurto.locale = ptLocale
            
            // 1. Buscar dados de performance dos últimos 6 meses (excluindo o atual)
            var stats: [PerformanceStat] = []
            for mesesAtras in (1...6).reversed() {
                if let date = calendar.date(byAdding: .month, value: -mesesAtras, to: Date()) {
                    let yearMonth = formatApi.string(from: date)
                    let monthLabel = formatMesCurto.string(from: date).uppercased()
                    
                    let attributed = try await GLPIClient.shared.getEstatisticasMensais(fieldDate: 15, yearMonth: yearMonth)
                    let resolved = try await GLPIClient.shared.getEstatisticasMensais(fieldDate: 17, yearMonth: yearMonth)
                    
                    stats.append(PerformanceStat(month: monthLabel, attributed: attributed, resolved: resolved))
                }
            }
            
            // 2. Buscar categorias
            if let dateLimite = calendar.date(byAdding: .month, value: -6, to: Date()) {
                let dateLimiteStr = formatFull.string(from: dateLimite)
                let response = try await GLPIClient.shared.getCategoriasEstatisticas(dataLimite: dateLimiteStr)
                let tickets = response.data ?? []
                
                var counts: [String: Int] = [:]
                for ticket in tickets {
                    if let categoryName = ticket["7"]?.value as? String {
                        counts[categoryName, default: 0] += 1
                    }
                }
                
                let sortedCategories = counts.sorted { $0.value > $1.value }.prefix(4)
                
                let colors: [Color] = [
                    GlpiColors.universalBlue,
                    Color(red: 0.2, green: 0.4, blue: 0.8),
                    Color(red: 0.4, green: 0.6, blue: 0.95),
                    Color(red: 0.6, green: 0.75, blue: 0.98)
                ]
                
                var catStats: [CategoryStat] = []
                for (index, item) in sortedCategories.enumerated() {
                    let color = colors[index % colors.count]
                    catStats.append(CategoryStat(name: item.key.uppercased(), count: item.value, color: color))
                }
                
                await MainActor.run {
                    if !stats.isEmpty {
                        self.performanceData = stats
                    }
                    if !catStats.isEmpty {
                        self.categoryData = catStats
                    }
                    self.isLoading = false
                    withAnimation(.spring(response: 1.0, dampingFraction: 1.0)) {
                        self.animateCharts = true
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                withAnimation(.spring(response: 1.0, dampingFraction: 1.0)) {
                    self.animateCharts = true
                }
            }
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
                    VStack(spacing: 25) {
                        
                        // 1. Gráfico de Performance
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("TOTAL DE TICKETS")
                                        .font(.amiko(size: 14, weight: .black))
                                        .foregroundColor(GlpiColors.universalBlue)
                                    Text("ÚLTIMOS 6 MESES")
                                        .font(.amiko(size: 9, weight: .bold))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                                }
                                
                                Spacer()
                                
                                // BARRA DE PROGRESSO DO LOOP
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
                                .drawingGroup() // MAX FLUIDEZ
                                .frame(height: 120)
                                .chartYAxis(.hidden)
                                .chartXAxis(.hidden)
                                .chartYScale(domain: 0 ... (maxVal > 0 ? maxVal * 1.15 : 10))
                            }
                            
                            // EIXO DE MESES CLICÁVEIS
                            HStack {
                                ForEach(Array(performanceData.enumerated()), id: \.offset) { index, point in
                                    let isActive = index == activeMonthIndex
                                    Button(action: { selectMonth(index: index) }) {
                                        Text(point.month)
                                            .font(.amiko(size: 10, weight: isActive ? .black : .regular))
                                            .foregroundColor(isActive ? GlpiColors.universalBlue : GlpiColors.dynamicText.opacity(0.2))
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                            .padding(.top, 5)
                            
                            Spacer()
                            
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
                        .glassStyle(cornerRadius: 30)
                        .onTapGesture {
                            triggerManualPause()
                        }
                        
                        // 2. Categorias
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CATEGORIAS MAIS SOLICITADAS")
                                .font(.amiko(size: 14, weight: .black))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
                            
                            Spacer()
                            
                            HStack(spacing: 20) {
                                if !categoryData.isEmpty {
                                    Chart(categoryData) { item in
                                        SectorMark(
                                            angle: .value("Quantidade", animateCharts ? item.count : 0),
                                            innerRadius: .ratio(0.65),
                                            angularInset: 2
                                        )
                                        .cornerRadius(5)
                                        .foregroundStyle(item.color)
                                    }
                                    .frame(width: 150, height: 150)
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(categoryData) { item in
                                        HStack(spacing: 8) {
                                            Circle().fill(item.color).frame(width: 8, height: 8)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name)
                                                    .font(.amiko(size: 10, weight: .bold))
                                                    .foregroundColor(GlpiColors.dynamicText.opacity(0.6))
                                                Text("\(item.count) TICKETS")
                                                    .font(.amiko(size: 12, weight: .black))
                                                    .foregroundColor(GlpiColors.dynamicText)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(20)
                        .frame(height: 280)
                        .glassStyle(cornerRadius: 30)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
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
        .onAppear {
            Task {
                await loadStatistics()
            }
        }
        .onReceive(timer) { _ in
            // Só inicia o loop automático 3 segundos após o onAppear (dando tempo à animação)
            guard animateCharts && !performanceData.isEmpty else { return }
            
            if !isPaused {
                loopProgress += 0.05 / 3.0 // Revertido para os 3 segundos originais
                
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
    StatisticsView()
}
