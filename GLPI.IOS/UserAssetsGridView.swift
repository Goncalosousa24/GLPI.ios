//
//  UserAssetsGridView.swift
//  GLPI.IOS
//
//  Created by Antigravity on 22/04/2026.
//

import SwiftUI

struct UserAssetsGridView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    // Mock Assets (Consistentes com InventoryView)
    let mockAssets = [
        GLPIAsset(name: "MacBook Pro M3 - GS", tag: "TAG-001", icon: "desktopcomputer", type: .computer, status: "Ativo", owner: "Gonçalo Sousa", department: "DSI", serialNumber: "8HX9J2L1"),
        GLPIAsset(name: "Monitor Dell UltraSharp", tag: "TAG-042", icon: "display", type: .monitor, status: "Ativo", owner: "Gonçalo Sousa", department: "DSI", serialNumber: "DL293041"),
        GLPIAsset(name: "iMac 24\" - Recepção", tag: "TAG-910", icon: "desktopcomputer", type: .computer, status: "Ativo", owner: "Ana Martins", department: "Stock", serialNumber: "IM-9102"),
        GLPIAsset(name: "Mac Studio M2 Ultra", tag: "TAG-990", icon: "desktopcomputer", type: .computer, status: "Ativo", owner: "Ricardo Ferreira", department: "DSI", serialNumber: "MS-9902"),
        GLPIAsset(name: "Dell P2723DE", tag: "TAG-112", icon: "display", type: .monitor, status: "Ativo", owner: "Ana Martins", department: "Stock", serialNumber: "DL-1122"),
        GLPIAsset(name: "Brother MFC-L2710", tag: "TAG-445", icon: "printer.fill", type: .printer, status: "Ativo", owner: "Ricardo Ferreira", department: "DAO", serialNumber: "BR-4455"),
        GLPIAsset(name: "Monitor LG Ergo", tag: "TAG-009", icon: "display", type: .monitor, status: "Ativo", owner: "Duarte Silva", department: "Stock", serialNumber: "LG-0099"),
        GLPIAsset(name: "Zebra ZD421", tag: "TAG-223", icon: "printer.fill", type: .printer, status: "Ativo", owner: "Duarte Silva", department: "DAO", serialNumber: "ZB-2233")
    ]
    
    var assetsByUser: [String: [GLPIAsset]] {
        let filtered = mockAssets.filter { $0.owner != nil }
        let grouped = Dictionary(grouping: filtered, by: { $0.owner ?? "" })
        
        if searchText.isEmpty {
            return grouped
        } else {
            return grouped.filter { $0.key.localizedCaseInsensitiveContains(searchText) }
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
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .glassStyle(cornerRadius: 12)
                    }
                    
                    Spacer()
                    
                    Text("ATIVOS POR PESSOA")
                        .font(.amiko(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                GLPISearchHeader(
                    searchText: $searchText,
                    placeholder: "Pesquisar pessoa..."
                )
                .padding(.top, 20)
                
                // Grid
                ScrollView {
                    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]
                    
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(assetsByUser.keys.sorted(), id: \.self) { user in
                            NavigationLink(destination: UserDetailsAssetsView(userName: user, assets: assetsByUser[user] ?? [])) {
                                UserCard(userName: user, deviceCount: assetsByUser[user]?.count ?? 0)
                            }
                        }
                        Spacer(minLength: 120)
                    }
                    .padding(25)
                }
            }
        }
        .navigationBarHidden(true)
    }
}


// Re-implementando UserCard aqui para ser limpo
struct UserCard: View {
    let userName: String
    let deviceCount: Int
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(GlpiColors.universalBlue.opacity(0.1))
                    .frame(width: 45, height: 45)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(GlpiColors.universalBlue)
            }
            
            VStack(spacing: 4) {
                Text(userName.uppercased())
                    .font(.amiko(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(deviceCount) Dispositivos")
                    .font(.amiko(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .glassStyle(cornerRadius: 24)
    }
}

#Preview {
    UserAssetsGridView()
}
