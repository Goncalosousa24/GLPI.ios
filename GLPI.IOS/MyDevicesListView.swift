//
//  MyDevicesListView.swift
//  GLPI.IOS
//
//  Created by Gonçalo Sousa on 21/05/2026.
//

import SwiftUI

struct MyDevicesListView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    @State private var devices: [Asset] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var filteredDevices: [Asset] {
        if searchText.isEmpty {
            return devices
        } else {
            return devices.filter { device in
                device.name.localizedCaseInsensitiveContains(searchText) ||
                device.tag.localizedCaseInsensitiveContains(searchText) ||
                device.serialNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Fundo adaptável (Sincronizado com o Tema da App)
            (isLightMode ? Color.white : Color.black).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. UNIVERSAL HEADER (Regras Universais de Cabecalho)
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: GlpiMetrics.universalBackIcon)
                            .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                            .foregroundColor(GlpiColors.universalBlue)
                    }
                    .padding(.leading, GlpiMetrics.universalHeaderLeading)
                    
                    Spacer()
                    
                    Text("MEUS DISPOSITIVOS")
                        .font(.amiko(size: 18, weight: .black))
                        .foregroundColor(GlpiColors.dynamicText)
                    
                    Spacer()
                    
                    // Compensação para centrar
                    Color.clear.frame(width: 44, height: 44)
                        .padding(.trailing, GlpiMetrics.universalHeaderLeading)
                }
                .padding(.top, GlpiMetrics.topPadding + 5)
                .frame(height: GlpiMetrics.navAreaHeight)
                
                // 2. SEARCH BAR (Sincronizada)
                GLPISearchHeader(
                    searchText: $searchText,
                    placeholder: "Pesquisar dispositivo..."
                )
                .padding(.bottom, 10)
                
                // 3. CONTEÚDO (Lista de Dispositivos / Loader / Empty State)
                ZStack {
                    if isLoading {
                        VStack(spacing: 15) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: GlpiColors.universalBlue))
                                .scaleEffect(1.5)
                            Text("A carregar dispositivos...")
                                .font(.amiko(size: 14))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.5))
                        }
                    } else if let error = errorMessage {
                        VStack(spacing: 15) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.red.opacity(0.8))
                            Text(error)
                                .font(.amiko(size: 14))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Button(action: {
                                loadDevices()
                            }) {
                                Text("TENTAR NOVAMENTE")
                                    .font(.amiko(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(GlpiColors.universalBlue)
                                    .cornerRadius(10)
                            }
                            .padding(.top, 10)
                        }
                    } else if filteredDevices.isEmpty {
                        VStack(spacing: 15) {
                            Image(systemName: "desktopcomputer.slash")
                                .font(.system(size: 44))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.2))
                            Text(searchText.isEmpty ? "Não tem nenhum dispositivo associado." : "Nenhum dispositivo corresponde à pesquisa.")
                                .font(.amiko(size: 14))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 15) {
                                ForEach(filteredDevices) { device in
                                    MyDeviceRow(device: device)
                                }
                                Spacer(minLength: 50)
                            }
                            .padding(.horizontal, GlpiMetrics.padding)
                            .padding(.top, 10)
                        }
                        .scrollDismissesKeyboard(.immediately)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadDevices()
        }
    }
    
    private func loadDevices() {
        isLoading = true
        errorMessage = nil
        
        let userId = PreferenceManager.shared.userId
        Task {
            do {
                let fetchedDevices = try await GLPIClient.shared.getMyDevices(userId: userId)
                await MainActor.run {
                    self.devices = fetchedDevices
                    self.isLoading = false
                }
            } catch {
                print("Erro ao carregar dispositivos do utilizador: \(error)")
                await MainActor.run {
                    self.errorMessage = "Erro ao carregar dados do servidor GLPI."
                    self.isLoading = false
                }
            }
        }
    }
}

struct MyDeviceRow: View {
    let device: Asset
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                // Nome do Dispositivo
                Text(device.name.uppercased())
                    .font(.amiko(size: 15, weight: .black))
                    .foregroundColor(isLightMode ? GlpiColors.universalBlue : .white)
                    .lineLimit(1)
                
                Spacer()
                
                if !device.status.isEmpty && device.status.lowercased() != "nenhum" && device.status.lowercased() != "null" {
                    Text(device.status.uppercased())
                        .font(.amiko(size: 9, weight: .bold))
                        .frame(width: 75)
                        .padding(.vertical, 4)
                        .background(GlpiColors.universalBlue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            
            // Detalhes Horizontais
            HStack(alignment: .top, spacing: 10) {
                MyDeviceDetailColumn(label: "TIPO", value: device.type.displayName.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                MyDeviceDetailColumn(label: "ETIQUETA", value: device.tag.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                MyDeviceDetailColumn(label: "S/N", value: device.serialNumber.uppercased())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .glassStyle(cornerRadius: 22)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "ativo", "operacional", "em uso":
            return .green
        case "manutenção", "reparação":
            return .orange
        case "inativo", "avariado":
            return .red
        default:
            return GlpiColors.dynamicText.opacity(0.5)
        }
    }
}

struct MyDeviceDetailColumn: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.amiko(size: 9, weight: .bold))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
            Text(value.isEmpty ? "N/A" : value)
                .font(.amiko(size: 11, weight: .black))
                .foregroundColor(GlpiColors.dynamicText.opacity(0.9))
                .lineLimit(1)
        }
    }
}

#Preview {
    MyDevicesListView()
}
