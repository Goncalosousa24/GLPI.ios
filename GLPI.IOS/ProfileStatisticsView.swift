//
//  ProfileStatisticsView.swift
//  GLPI.IOS
//
//  Created by Antigravity on 27/04/2026.
//

import SwiftUI
import Charts
import Combine

struct ProfileStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Personal performance data (Mock)
    let performanceData: [PerformanceStat] = [
        PerformanceStat(month: "Jan", attributed: 2, resolved: 1),
        PerformanceStat(month: "Fev", attributed: 4, resolved: 3),
        PerformanceStat(month: "Mar", attributed: 3, resolved: 4),
        PerformanceStat(month: "Abr", attributed: 6, resolved: 5),
        PerformanceStat(month: "Mai", attributed: 4, resolved: 6),
        PerformanceStat(month: "Jun", attributed: 8, resolved: 7)
    ]
    
    @State private var selectedMonth: String? = nil
    @State private var progress: Double = 0.0
    private let pageDuration: Double = 5.0
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    private var selectedStat: PerformanceStat {
        if let month = selectedMonth,
           let stat = performanceData.first(where: { $0.month == month }) {
            return stat
        }
        return performanceData.first!
    }
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .glassStyle(cornerRadius: 12)
                    }
                    
                    Spacer()
                    
                    Text("ESTATÍSTICAS PESSOAIS")
                        .font(.amiko(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 45, height: 45)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        ScrollOffsetTracker()
                        
                        // MARK: - Summary Cards
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            DashboardStatCard(title: "CRIADOS", value: 3, color: .white, trigger: 0)
                            DashboardStatCard(title: "EM PROGRESSO", value: 5, color: .blue, trigger: 0)
                            DashboardStatCard(title: "RESOLVIDOS", value: 12, color: .green, trigger: 0)
                            DashboardStatCard(title: "PRIORITÁRIOS", value: 2, color: .yellow, trigger: 0)
                        }
                        .padding(.horizontal, 16)
                        
                        // MARK: - Performance Chart
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("DESEMPENHO INDIVIDUAL")
                                    .font(.amiko(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()

                            }
                            
                            Chart {
                                ForEach(performanceData) { stat in
                                    AreaMark(
                                        x: .value("Mês", stat.month),
                                        y: .value("Tickets", stat.resolved)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.3), Color.clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    
                                    LineMark(
                                        x: .value("Mês", stat.month),
                                        y: .value("Tickets", stat.resolved)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 3))
                                    .foregroundStyle(Color.white)
                                    
                                    PointMark(
                                        x: .value("Mês", stat.month),
                                        y: .value("Tickets", stat.resolved)
                                    )
                                    .symbol {
                                        let isFocused = stat.month == selectedMonth
                                        Circle()
                                            .fill(isFocused ? .white : .white.opacity(0.3))
                                            .frame(width: isFocused ? 12 : 6, height: isFocused ? 12 : 6)
                                            .shadow(color: isFocused ? Color.white : .clear, radius: isFocused ? 10 : 0)
                                            .shadow(color: isFocused ? Color.white.opacity(0.5) : .clear, radius: isFocused ? 20 : 0)
                                    }
                                }
                            }
                            .frame(height: 150)
                            .chartXAxis {
                                AxisMarks(values: .automatic) { value in
                                    let month = value.as(String.self) ?? ""
                                    let isSelected = month == selectedMonth
                                    AxisValueLabel {
                                        Text(month)
                                            .font(.amiko(size: 10, weight: isSelected ? .bold : .regular))
                                            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                                            .shadow(color: isSelected ? .white : .clear, radius: isSelected ? 8 : 0)
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: .automatic) { _ in

                                    AxisValueLabel()
                                        .foregroundStyle(.white.opacity(0.5))
                                        .font(.amiko(size: 10))
                                }
                            }
                            
                            HStack(spacing: 40) {
                                VStack(alignment: .center, spacing: 4) {
                                    Text("\(selectedStat.attributed)")
                                        .font(.amiko(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("ATRIBUÍDOS")
                                        .font(.amiko(size: 10, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                
                                VStack(alignment: .center, spacing: 4) {
                                    Text("\(selectedStat.resolved)")
                                        .font(.amiko(size: 24, weight: .bold))
                                        .foregroundColor(.blue)
                                    Text("RESOLVIDOS")
                                        .font(.amiko(size: 10, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.top, 10)
                        }
                        .padding(25)
                        .glassStyle(cornerRadius: 25)
                        .padding(.horizontal, 16)
                        
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            selectedMonth = performanceData.first?.month
        }
        .onReceive(timer) { _ in
            let increment = 0.1 / pageDuration
            progress += increment
            if progress >= 1.0 {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    progress = 0
                    if let currentMonth = selectedMonth,
                       let currentIndex = performanceData.firstIndex(where: { $0.month == currentMonth }) {
                        let nextIndex = (currentIndex + 1) % performanceData.count
                        selectedMonth = performanceData[nextIndex].month
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileStatisticsView()
}
