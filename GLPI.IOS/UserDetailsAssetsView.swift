import SwiftUI

struct UserDetailsAssetsView: View {
    @Environment(\.dismiss) private var dismiss
    let userName: String
    let assets: [GLPIAsset]
    
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
                    
                    VStack(spacing: 2) {
                        Text("DISPOSITIVOS DE")
                            .font(.amiko(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                        Text(userName.uppercased())
                            .font(.amiko(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        // User Profile Header Mini
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(GlpiColors.universalBlue.opacity(0.1))
                                    .frame(width: 70, height: 70)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(GlpiColors.universalBlue)
                            }
                            
                            Text("\(assets.count) ATIVOS ASSOCIADOS")
                                .font(.amiko(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.vertical, 20)
                        
                        // List of Assets
                        VStack(spacing: 15) {
                            ForEach(assets) { asset in
                                AssetDetailRow(asset: asset)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 120)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct AssetDetailRow: View {
    let asset: GLPIAsset
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(GlpiColors.universalBlue.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: asset.icon)
                    .font(.system(size: 20))
                    .foregroundColor(GlpiColors.universalBlue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.amiko(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Text(asset.tag)
                    .font(.amiko(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Text(asset.status)
                .font(.amiko(size: 9, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .clipShape(Capsule())
        }
        .padding(15)
        .glassStyle(cornerRadius: 20)
    }
}

#Preview {
    UserDetailsAssetsView(userName: "Gonçalo Sousa", assets: [
        GLPIAsset(name: "MacBook Pro M3", tag: "TAG-402", icon: "desktopcomputer", type: .computer, status: "Ativo", owner: "Gonçalo Sousa", department: "DSI", serialNumber: "SN-8HX9J2L1")
    ])
}
