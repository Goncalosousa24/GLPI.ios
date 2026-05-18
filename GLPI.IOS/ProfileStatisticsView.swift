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
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    @State private var activeMonthIndex: Int = 0
    @State private var loopProgress: Double = 0.0
    @State private var isPaused: Bool = false
    @State private var pauseTask: Task<Void, Never>? = nil
    @State private var animateCharts: Bool = false
    
    // Personal performance data (Mock)
    let performanceData: [PerformanceStat] = [
        PerformanceStat(month: "JAN", attributed: 2, resolved: 1),
        PerformanceStat(month: "FEV", attributed: 4, resolved: 3),
        PerformanceStat(month: "MAR", attributed: 3, resolved: 4),
        PerformanceStat(month: "ABR", attributed: 6, resolved: 5),
        PerformanceStat(month: "MAI", attributed: 4, resolved: 6),
        PerformanceStat(month: "JUN", attributed: 8, resolved: 7)
    ]
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    private var activePoint: PerformanceStat {
        if activeMonthIndex >= 0 && activeMonthIndex < performanceData.count {
            return performanceData[activeMonthIndex]
        }
        return performanceData[0]
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
    
    var body: some View {
        ZStack {
            GlpiColors.background.ignoresSafeArea()
            
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
                            DashboardStatCard(title: "NOVOS", value: 3, color: .white, trigger: 0)
                            DashboardStatCard(title: "EM PROGRESSO", value: 5, color: .blue, trigger: 0)
                            DashboardStatCard(title: "RESOLVIDOS", value: 12, color: .green, trigger: 0)
                            DashboardStatCard(title: "PRIORITÁRIOS", value: 2, color: .yellow, trigger: 0)
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
                                    Text("RESOLVIDOS")
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
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 1.0, dampingFraction: 1.0)) {
                    animateCharts = true
                }
            }
        }
        .onReceive(timer) { _ in
            guard animateCharts else { return }
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
