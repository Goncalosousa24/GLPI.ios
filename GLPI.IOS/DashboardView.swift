import SwiftUI
import Combine
import Charts

enum DashboardChartType {
    case performance, categories
}

struct DashboardView: View {
    @Binding var isLoggedIn: Bool
    
    @StateObject private var dashViewModel = DashboardViewModel()
    @State private var searchText: String = ""
    @State private var showCreateTicket = false
    @State private var selectedMonth: String? = "Abr"
    
    @State private var activityIndex = 0
    @State private var progress: Double = 0
    @State private var isPaused = false
    @State private var selectedChartType: DashboardChartType = .performance
    let pageDuration: Double = 5.0
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private var selectedStat: PerformanceStat {
        dashViewModel.performanceData.first { $0.month == selectedMonth } ?? PerformanceStat(month: selectedMonth ?? "", attributed: 0, resolved: 0)
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
        
            VStack(spacing: 0) {
                // Header Padding
                
                // Search + Profile
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.4))
                        TextField("", text: $searchText, prompt: Text("Pesquisar...").foregroundColor(.white.opacity(0.3)))
                            .foregroundColor(.white)
                            .font(.amiko(size: 16))
                    }
                    .padding()
                    .glassStyle(cornerRadius: 15)
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            dashViewModel.isPersonalView.toggle()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        Image(dashViewModel.isPersonalView ? "pessoa2" : "pessoa")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .foregroundColor(.white)
                            .padding(14)
                            .glassStyle(cornerRadius: 15, isSelection: dashViewModel.isPersonalView)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 5)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 1. STATS
                        VStack(spacing: 16) {
                            HStack(spacing: 15) {
                                DashboardStatCard(title: "NOVOS", value: dashViewModel.newTicketsCount, color: .blue, trigger: dashViewModel.lastUpdateTrigger)
                                DashboardStatCard(title: "ATRIBUÍDOS", value: dashViewModel.assignedTicketsCount, color: .orange, trigger: dashViewModel.lastUpdateTrigger)
                                DashboardStatCard(title: "RESOLVIDOS", value: dashViewModel.resolvedTicketsCount, color: .green, trigger: dashViewModel.lastUpdateTrigger)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // 2. UPDATES
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Spacer()
                                Text("ÚLTIMAS ATUALIZAÇÕES")
                                    .font(.inconsolata(size: 16, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                                Text("\(activityIndex + 1)/2")
                                    .font(.amiko(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            VStack(spacing: 12) {
                                let start = activityIndex * 3
                                let end = min(start + 3, dashViewModel.activities.count)
                                
                                if start < end {
                                    ForEach(start..<end, id: \.self) { index in
                                        ActivityRow(activity: dashViewModel.activities[index])
                                    }
                                } else if dashViewModel.activities.isEmpty && !dashViewModel.isLoading {
                                    Text("Sem atividades recentes")
                                        .font(.amiko(size: 14))
                                        .foregroundColor(.white.opacity(0.3))
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 20)
                                }
                            }
                            
                            // Auto-progress bar
                            GeometryReader { progressGeo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.1))
                                    Capsule().fill(Color.white.opacity(0.4))
                                        .frame(width: progressGeo.size.width * progress)
                                }
                            }
                            .frame(height: 3)
                            .padding(.top, 5)
                        }
                        .padding(.horizontal, 16)
                        
                        // 3. CHARTS
                        VStack(spacing: 15) {
                            HStack {
                                ChartTabButton(title: "DESEMPENHO", isSelected: selectedChartType == .performance) {
                                    withAnimation { selectedChartType = .performance }
                                }
                                ChartTabButton(title: "CATEGORIAS", isSelected: selectedChartType == .categories) {
                                    withAnimation { selectedChartType = .categories }
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            if selectedChartType == .performance {
                                PerformanceChartView(performanceData: dashViewModel.performanceData, selectedMonth: $selectedMonth)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                            } else {
                                CategoriesChartView(categoryData: dashViewModel.categoryData)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        
                        // 4. QUICK ACTIONS
                        VStack(alignment: .leading, spacing: 15) {
                            Text("AÇÕES RÁPIDAS")
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 15) {
                                DashboardQuickActionCard(title: "NOVO TICKET", icon: "ticket", color: .white) {
                                    showCreateTicket = true
                                }
                                DashboardQuickActionCard(title: "MEUS TICKET", icon: "person.text.rectangle", color: .white) {
                                    // Meus tickets
                                }
                                DashboardQuickActionCard(title: "PESQUISAR", icon: "magnifyingglass", color: .white) {
                                    // Pesquisar
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 10)
                }
            }
            
            // Loading Overlay
            if dashViewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
        }
        .onReceive(timer) { _ in
            if !isPaused {
                progress += 0.1 / pageDuration
                if progress >= 1.0 {
                    progress = 0
                    withAnimation {
                        activityIndex = (activityIndex + 1) % 2
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateTicket) {
            TicketCreateView()
        }
        .task {
            await dashViewModel.refreshData()
        }
    }
}


struct ChartTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.amiko(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
                .cornerRadius(10)
        }
    }
}

struct PerformanceChartView: View {
    let performanceData: [PerformanceStat]
    @Binding var selectedMonth: String?
    
    var body: some View {
        VStack {
            Chart {
                ForEach(performanceData) { stat in
                    LineMark(
                        x: .value("Mês", stat.month),
                        y: .value("Atribuídos", stat.attributed),
                        series: .value("Tipo", "Atribuídos")
                    )
                    .foregroundStyle(.blue.opacity(0.7))
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Mês", stat.month),
                        y: .value("Atribuídos", stat.attributed)
                    )
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                    
                    LineMark(
                        x: .value("Mês", stat.month),
                        y: .value("Resolvidos", stat.resolved),
                        series: .value("Tipo", "Resolvidos")
                    )
                    .foregroundStyle(.green.opacity(0.7))
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .padding()
            .chartXAxis {
                AxisMarks(values: .stride(by: 1)) { _ in
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.amiko(size: 10))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.amiko(size: 10))
                }
            }
        }
        .glassStyle(cornerRadius: 22)
        .padding(.horizontal, 16)
    }
}

struct CategoriesChartView: View {
    let categoryData: [(name: String, count: Int)]
    
    var body: some View {
        VStack {
            Chart {
                ForEach(categoryData, id: \.name) { item in
                    BarMark(
                        x: .value("Categoria", item.name),
                        y: .value("Quantidade", item.count)
                    )
                    .foregroundStyle(.blue.opacity(0.7))
                    .cornerRadius(5)
                }
            }
            .frame(height: 200)
            .padding()
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.amiko(size: 10))
                }
            }
        }
        .glassStyle(cornerRadius: 22)
        .padding(.horizontal, 16)
    }
}

#Preview {
    DashboardView(isLoggedIn: .constant(true))
}
