import SwiftUI

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "Computadores"
    @State private var showScanner = false
    @State private var showCreateAsset = false
    @State private var showReservations = false
    @State private var showHistory = false
    
    let categories = ["Computadores", "Monitores", "Periféricos", "Rede", "Software"]
    
    var body: some View {
        ZStack {
            GlpiColors.premiumBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header + Search (Mesmo estilo do Dashboard)
                VStack(spacing: 15) {
                    HStack {
                        Text("INVENTÁRIO")
                            .font(.inconsolata(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 50)
                    
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.4))
                            TextField("", text: $searchText, prompt: Text("Pesquisar ativos...").foregroundColor(.white.opacity(0.3)))
                                .foregroundColor(.white)
                                .font(.amiko(size: 16))
                        }
                        .padding()
                        .glassStyle(cornerRadius: 15)
                        
                        Button(action: {
                            showScanner = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .padding(14)
                                .glassStyle(cornerRadius: 15)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 10)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        ScrollOffsetTracker()
                        
                        // 1. Category Filter (Pills)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(categories, id: \.self) { cat in
                                    FilterPill(title: cat, isSelected: selectedCategory == cat) {
                                        withAnimation(.spring()) {
                                            selectedCategory = cat
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // 2. Stats Grid
                        HStack(spacing: 15) {
                            InventoryStatCard(title: "TOTAL ATIVOS", value: "156")
                            InventoryStatCard(title: "EM USO", value: "142")
                        }
                        .padding(.horizontal, 16)
                        
                        // 3. Quick Actions Grid
                        VStack(spacing: 15) {
                            HStack(spacing: 15) {
                                DashboardQuickActionCard(title: "ADICIONAR", icon: "plus.app.fill", color: .white) {
                                    showCreateAsset = true
                                }
                                DashboardQuickActionCard(title: "SCAN", icon: "barcode.viewfinder", color: .white) {
                                    showScanner = true
                                }
                                DashboardQuickActionCard(title: "REPORTAR", icon: "exclamationmark.bubble.fill", color: .white) {
                                    // Ação reportar
                                }
                            }
                            HStack(spacing: 15) {
                                DashboardQuickActionCard(title: "RESERVAS", icon: "calendar", color: .white) {
                                    showReservations = true
                                }
                                DashboardQuickActionCard(title: "HISTÓRICO", icon: "clock.arrow.2.circlepath", color: .white) {
                                    showHistory = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // 4. Asset List (Glass Cards)
                        VStack(alignment: .leading, spacing: 15) {
                            Text("RECENTES - \(selectedCategory.uppercased())")
                                .font(.amiko(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(viewModel.assets) { asset in
                                    AssetRow(asset: asset)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .preferredColorScheme(.dark)
        .tint(.white)
        .sheet(isPresented: $showScanner) {
            ScannerView()
        }
        .sheet(isPresented: $showCreateAsset) {
            AssetCreateView()
        }
    }
}

struct InventoryStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.amiko(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.amiko(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassStyle(cornerRadius: 22)
    }
}

struct AssetRow: View {
    let asset: Asset
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: asset.icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.amiko(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(asset.tag)
                    .font(.amiko(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(asset.status)
                    .font(.amiko(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .foregroundColor(.white)
            }
        }
        .padding(15)
        .glassStyle(cornerRadius: 18)
    }
}

#Preview {
    InventoryView()
}
