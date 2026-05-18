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
    
    @State private var currentActivityPage = 0
    struct ListConfig: Identifiable {
        let id = UUID()
        let title: String
        let status: TicketStatus?
        let isDeleteMode: Bool
    }
    
    @State private var listConfig: ListConfig? = nil
    @State private var showStatistics = false
    @State private var showActivities = false
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private var selectedStat: PerformanceStat {
        dashViewModel.performanceData.first { $0.month == selectedMonth } ?? PerformanceStat(month: selectedMonth ?? "", attributed: 0, resolved: 0)
    }
    
    var body: some View {
        ZStack {
            GlpiColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Cabeçalho Universal (De volta à posição FIXA)
                GLPISearchHeader(
                    searchText: $searchText,
                    placeholder: "Pesquisar tickets...",
                    rightIcon: dashViewModel.isPersonalView ? "pessoa" : "pessoa2",
                    isRightIconSelected: dashViewModel.isPersonalView,
                    rightIconAction: {
                        withAnimation(.spring()) {
                            dashViewModel.isPersonalView.toggle()
                        }
                    }
                )
                .padding(.top, GlpiMetrics.topPadding)
                .padding(.bottom, 5)


                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ScrollOffsetTracker()
                        
                        VStack(spacing: 20) {
                            // 1. STATS (Interativos)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                                DashboardStatCard(title: "NOVOS", value: dashViewModel.newTicketsCount, color: .blue, trigger: dashViewModel.lastUpdateTrigger) {
                                    listConfig = ListConfig(title: "NOVOS", status: .new, isDeleteMode: false)
                                }
                                
                                DashboardStatCard(title: "EM PROGRESSO", value: dashViewModel.inProgressTicketsCount, color: .purple, trigger: dashViewModel.lastUpdateTrigger) {
                                    listConfig = ListConfig(title: "EM PROGRESSO", status: .assigned, isDeleteMode: false)
                                }
                                
                                DashboardStatCard(title: "RESOLVIDOS", value: dashViewModel.resolvedTicketsCount, color: .green, trigger: dashViewModel.lastUpdateTrigger) {
                                    listConfig = ListConfig(title: "RESOLVIDOS", status: .resolved, isDeleteMode: false)
                                }
                                
                                DashboardStatCard(title: "PRIORITÁRIOS", value: dashViewModel.priorityGlobal, color: .orange, trigger: dashViewModel.lastUpdateTrigger) {
                                    listConfig = ListConfig(title: "PRIORITÁRIOS", status: .new, isDeleteMode: false)
                                }
                            }
                            .padding(.horizontal, GlpiMetrics.padding)
                            .padding(.top, 5)
                            
                            Button(action: { showActivities = true }) {
                                VStack(alignment: .center, spacing: 10) {
                                    Text("ATUALIZAÇÕES")
                                        .font(.amiko(size: 14, weight: .bold))
                                        .foregroundColor(GlpiColors.dynamicText.opacity(0.8))
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 5)
                                    
                                    TabView(selection: $currentActivityPage) {
                                        ActivityPage(activities: Array(dashViewModel.activities.prefix(3)))
                                            .tag(0)
                                        ActivityPage(activities: Array(dashViewModel.activities.dropFirst(3).prefix(3)))
                                            .tag(1)
                                        ActivityPage(activities: Array(dashViewModel.activities.dropFirst(6).prefix(3)))
                                            .tag(2)
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 200)
                                    
                                    HStack(spacing: 8) {
                                        ForEach(0..<3) { index in
                                            Capsule()
                                                .fill(currentActivityPage == index ? GlpiColors.universalBlue : GlpiColors.universalBlue.opacity(0.2))
                                                .frame(width: currentActivityPage == index ? 30 : 12, height: 6)
                                                .animation(.spring(), value: currentActivityPage)
                                        }
                                    }
                                    .padding(.bottom, 15)
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 280, alignment: .top)
                                .glassStyle(cornerRadius: 22)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, GlpiMetrics.padding)
                            
                            GLPIHorizontalScrollContainer {
                                HStack(spacing: GlpiMetrics.actionSpacing) {
                                    let cardWidth = (UIScreen.screenWidth - (GlpiMetrics.padding * 2) - (GlpiMetrics.actionSpacing * 2)) / 3
                                    
                                    DashboardQuickActionCard(title: "NOVO TICKET", icon: "plus.circle.fill") {
                                        showCreateTicket = true
                                    }
                                    .frame(width: cardWidth)
                                    
                                    DashboardQuickActionCard(title: "VISTA GERAL", icon: "square.grid.2x2.fill") {
                                        listConfig = ListConfig(title: "VISTA GERAL", status: nil, isDeleteMode: false)
                                    }
                                    .frame(width: cardWidth)
                                    
                                    DashboardQuickActionCard(title: "ELIMINAR", icon: "trash.fill") {
                                        listConfig = ListConfig(title: "ELIMINAR", status: .deleted, isDeleteMode: true)
                                    }
                                    .frame(width: cardWidth)
                                    
                                    DashboardQuickActionCard(title: "ESTATÍSTICAS", icon: "chart.bar.fill") {
                                        showStatistics = true
                                    }
                                    .frame(width: cardWidth)
                                }
                                .padding(.horizontal, GlpiMetrics.padding)
                            }
                            .padding(.top, 5)
                            
                            Spacer(minLength: 20)
                        }
                        .padding(.top, dashViewModel.isManualRefresh ? 80 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: dashViewModel.isManualRefresh)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .padding(.top, 10)
                .refreshable {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    await dashViewModel.refreshData(isManual: true)
                }
            }
            .fullScreenCover(item: $listConfig) { config in
                TicketListView(title: config.title, statusFilter: config.status, isDeleteMode: config.isDeleteMode, isPersonalView: config.isDeleteMode ? false : dashViewModel.isPersonalView)
            }
            .fullScreenCover(isPresented: $showStatistics) {
                StatisticsView()
            }
            .fullScreenCover(isPresented: $showActivities) {
                TicketListView(title: "ATUALIZAÇÕES", initialPage: currentActivityPage + 1)
            }
            

        }
        .onAppear {
            UIRefreshControl.appearance().tintColor = UIColor(GlpiColors.universalBlue)
            UIPageControl.appearance().currentPageIndicatorTintColor = UIColor(GlpiColors.universalBlue)
            UIPageControl.appearance().pageIndicatorTintColor = UIColor(GlpiColors.universalBlue).withAlphaComponent(0.2)
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
            await dashViewModel.refreshData(isManual: false)
        }
        .frame(width: UIScreen.main.bounds.width)
        .clipped()
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
                .foregroundColor(isSelected ? GlpiColors.dynamicText : GlpiColors.dynamicText.opacity(0.4))
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

// MARK: - Componentes de Atividade (Carrossel)

struct ActivityPage: View {
    let activities: [(title: String, desc: String, status: String)]
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<activities.count, id: \.self) { index in
                ActivityRowMini(activity: activities[index])
            }
            Spacer()
        }
        .padding(.top, 10)
    }
}

struct ActivityRowMini: View {
    let activity: (title: String, desc: String, status: String)
    
    var body: some View {
        HStack(spacing: 12) {
            Text(activity.title.uppercased())
                .font(.amiko(size: 13, weight: .bold))
                .foregroundColor(GlpiColors.dynamicText)
                .lineLimit(1)
            
            Spacer()
            
            GLPIBadge(text: activity.status)
        }
        .padding(.vertical, 24)
    }
}
