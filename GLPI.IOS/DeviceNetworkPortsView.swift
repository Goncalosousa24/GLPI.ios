import SwiftUI

struct NetworkPortInfo: Identifiable {
    let id = UUID()
    let baseId: String
    let logicalNumber: String
    let localPortName: String
    let connectedDeviceName: String
    let macAddress: String
    let ipAddress: String
}

struct DeviceNetworkPortsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    let asset: Asset
    
    @State private var ports: [NetworkPortInfo] = []
    @State private var isLoading = true
    @State private var paginaAtual = 0
    private let tamanhoPagina = 10
    
    var body: some View {
        ZStack {
            (isLightMode ? Color.white : Color.black).ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(GlpiColors.universalBlue)
                    Spacer()
                } else if ports.isEmpty {
                    Spacer()
                    VStack(spacing: 15) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 40))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.3))
                        Text("Nenhuma porta de rede encontrada.")
                            .font(.amiko(size: 14, weight: .bold))
                            .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                    }
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(ports) { port in
                                NetworkPortRow(port: port)
                            }
                            
                            // Barra de Navegação Universal (Branca/Azul como no Histórico)
                            HStack(spacing: 0) {
                                Button(action: {
                                    if paginaAtual > 0 {
                                        paginaAtual -= 1
                                        Task { await loadPorts() }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(GlpiColors.universalBlue)
                                        .opacity(paginaAtual == 0 ? 0.2 : 1.0)
                                        .frame(width: 50, height: 50)
                                }
                                .disabled(paginaAtual == 0)
                                
                                Spacer()
                                
                                Rectangle()
                                    .fill(GlpiColors.dynamicText.opacity(0.15))
                                    .frame(width: 1, height: 24)
                                
                                Spacer()
                                
                                Button(action: {
                                    if ports.count >= tamanhoPagina {
                                        paginaAtual += 1
                                        Task { await loadPorts() }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(GlpiColors.universalBlue)
                                        .opacity(ports.count < tamanhoPagina ? 0.2 : 1.0)
                                        .frame(width: 50, height: 50)
                                }
                                .disabled(ports.count < tamanhoPagina)
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(GlpiColors.dynamicOffWhite)
                            .cornerRadius(15)
                            .padding(.top, 10)
                            .padding(.bottom, 60)
                        }
                        .padding(.horizontal, GlpiMetrics.padding)
                        .padding(.top, 10)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task { await loadPorts() }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: GlpiMetrics.universalBackIcon)
                    .font(.system(size: GlpiMetrics.universalBackIconSize, weight: GlpiMetrics.universalBackIconWeight))
                    .foregroundColor(GlpiColors.universalBlue)
            }
            .padding(.leading, GlpiMetrics.padding + 5)
            
            Spacer()
            
            Text("PORTAS - \(asset.name.uppercased())")
                .font(.amiko(size: 16, weight: .black))
                .foregroundColor(GlpiColors.dynamicBlueText)
                .lineLimit(1)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.top, 5)
        .frame(height: GlpiMetrics.navAreaHeight)
    }
    
    private func loadPorts() async {
        await MainActor.run {
            self.isLoading = true
        }
        
        let rangeStr = "\(paginaAtual * tamanhoPagina)-\(paginaAtual * tamanhoPagina + tamanhoPagina - 1)"
        let assetTypeRaw: String
        switch asset.type {
        case .computer: assetTypeRaw = "Computer"
        case .monitor: assetTypeRaw = "Monitor"
        case .printer: assetTypeRaw = "Printer"
        case .network: assetTypeRaw = "NetworkEquipment"
        }
        
        do {
            let rawPorts = try await GLPIClient.shared.getNetworkPortsSearch(range: rangeStr, assetType: assetTypeRaw, assetId: asset.realId)
            
            var resolvedPorts: [NetworkPortInfo] = []
            
            // Usando TaskGroup para carregar detalhes remotos em paralelo
            try await withThrowingTaskGroup(of: NetworkPortInfo?.self) { group in
                for item in rawPorts {
                    group.addTask {
                        let logicalNum = String(describing: item["3"] ?? item["logical_number"] ?? "")
                            .replacingOccurrences(of: ".0", with: "")
                        let localPortName = String(describing: item["1"] ?? "")
                            .replacingOccurrences(of: "[]", with: "")
                            .replacingOccurrences(of: "null", with: "")
                        
                        var connectedTo = String(describing: item["39"] ?? "")
                            .replacingOccurrences(of: "[]", with: "")
                            .replacingOccurrences(of: "null", with: "")
                        
                        let baseId = String(describing: item["2"] ?? "").replacingOccurrences(of: ".0", with: "")
                        
                        // Mini Scraper do Android para achar máquina ligada na pivot NetworkPort_NetworkPort
                        if !baseId.isEmpty && baseId != "null" {
                            var connList = try await GLPIClient.shared.getPortConnection(searchField: 3, portId: baseId)
                            if connList.isEmpty {
                                connList = try await GLPIClient.shared.getPortConnection(searchField: 4, portId: baseId)
                            }
                            
                            var remoteId: String? = nil
                            if let firstConn = connList.first {
                                let id1 = String(describing: firstConn["3"] ?? "").replacingOccurrences(of: ".0", with: "")
                                let id2 = String(describing: firstConn["4"] ?? "").replacingOccurrences(of: ".0", with: "")
                                if id1 == baseId && !id2.isEmpty { remoteId = id2 }
                                else if id2 == baseId && !id1.isEmpty { remoteId = id1 }
                            }
                            
                            if let rId = remoteId, !rId.isEmpty, rId != "null" {
                                let remoteDetails = try await GLPIClient.shared.getRemotePortDetails(remotePortId: rId)
                                if let firstRemote = remoteDetails.first {
                                    let rType = String(describing: firstRemote["20"] ?? "")
                                        .replacingOccurrences(of: "[]", with: "")
                                        .replacingOccurrences(of: "null", with: "")
                                    let itemIdRaw = String(describing: firstRemote["21"] ?? "")
                                        .replacingOccurrences(of: ".0", with: "")
                                    
                                    if !rType.isEmpty && !itemIdRaw.isEmpty && itemIdRaw != "null" {
                                        let deviceDetails = try await GLPIClient.shared.getDeviceById(itemtype: rType, id: itemIdRaw)
                                        if let friendlyName = deviceDetails["name"] as? String {
                                            connectedTo = friendlyName
                                        }
                                    }
                                }
                            }
                        }
                        
                        let displayTitle = !connectedTo.isEmpty ? connectedTo : (!localPortName.isEmpty ? localPortName : "SEM LIGAÇÃO")
                        
                        var macRaw = ""
                        if let macDict = item["4"] as? [String: Any] {
                            macRaw = macDict["name"] as? String ?? macDict["1"] as? String ?? ""
                        } else {
                            macRaw = String(describing: item["4"] ?? "")
                        }
                        macRaw = macRaw.replacingOccurrences(of: "[]", with: "").replacingOccurrences(of: "null", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if macRaw == "0" || macRaw == "0.0" { macRaw = "" }
                        
                        return NetworkPortInfo(
                            baseId: baseId,
                            logicalNumber: logicalNum.isEmpty ? "?" : logicalNum,
                            localPortName: localPortName,
                            connectedDeviceName: displayTitle,
                            macAddress: macRaw.isEmpty ? "INDISPONÍVEL" : macRaw.lowercased(),
                            ipAddress: ""
                        )
                    }
                }
                
                for try await resolvedPort in group {
                    if let port = resolvedPort {
                        resolvedPorts.append(port)
                    }
                }
            }
            
            // Ordenar por número lógico ascendente
            resolvedPorts.sort {
                let n1 = Int($0.logicalNumber) ?? 999
                let n2 = Int($1.logicalNumber) ?? 999
                return n1 < n2
            }
            
            await MainActor.run {
                self.ports = resolvedPorts
                self.isLoading = false
            }
        } catch {
            print("Erro ao carregar portas de rede: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct NetworkPortRow: View {
    let port: NetworkPortInfo
    
    var body: some View {
        HStack(spacing: 15) {
            // Círculo Número de Porta
            ZStack {
                Circle()
                    .fill(GlpiColors.universalBlue.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Text(port.logicalNumber)
                    .font(.amiko(size: 14, weight: .black))
                    .foregroundColor(GlpiColors.universalBlue)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Título Conexão
                Text(port.connectedDeviceName.uppercased())
                    .font(.amiko(size: 13, weight: .black))
                    .foregroundColor(port.connectedDeviceName == "SEM LIGAÇÃO" ? GlpiColors.dynamicText.opacity(0.4) : GlpiColors.dynamicBlueText)
                    .lineLimit(1)
                
                // Endereço MAC
                Text("MAC: \(port.macAddress)")
                    .font(.amiko(size: 10, weight: .bold))
                    .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 75)
        .glassStyle(cornerRadius: 20)
    }
}
