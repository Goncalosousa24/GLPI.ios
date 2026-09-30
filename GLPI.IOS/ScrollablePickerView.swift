import SwiftUI

/// Lista expansível com barra de scroll customizada — reutilizável para qualquer seletor.
struct ScrollablePickerView: View {
    let options: [String]
    @Binding var selected: String
    var onSelect: () -> Void = {}
    var showNone: Bool = false

    private let rowHeight:  CGFloat = 44
    private let spacing:    CGFloat = 4
    private let vPadding:   CGFloat = 8
    private let visibleRows: Int    = 4

    // Altura exata para mostrar N linhas simétricamente
    private var listHeight: CGFloat {
        let rows     = CGFloat(visibleRows) * rowHeight
        let gaps     = CGFloat(visibleRows - 1) * spacing
        return rows + gaps + vPadding * 2
    }

    @State private var contentOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    // Adiciona "Nenhum" no topo apenas quando solicitado e já existe seleção, e garante que o selecionado fica no topo
    private var displayedOptions: [String] {
        var baseOptions = options
        if !selected.isEmpty {
            if let idx = baseOptions.firstIndex(of: selected) {
                baseOptions.remove(at: idx)
                baseOptions.insert(selected, at: 0)
            } else {
                baseOptions.insert(selected, at: 0)
            }
        }
        
        guard showNone && !selected.isEmpty else { return baseOptions }
        return ["— Nenhum —"] + baseOptions
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing) {
                    if displayedOptions.isEmpty {
                        HStack {
                            Spacer()
                            Text("Sem resultados")
                                .font(.amiko(size: 13, weight: .regular))
                                .foregroundColor(GlpiColors.dynamicText.opacity(0.4))
                                .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(displayedOptions, id: \.self) { opt in
                            if opt == "— Nenhum —" {
                            // Opção especial de limpeza
                            Button(action: {
                                selected = ""
                                onSelect()
                            }) {
                                HStack {
                                    Text("Nenhum")
                                        .font(.amiko(size: 14, weight: .bold))
                                        .foregroundColor(GlpiColors.dynamicBlueText)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                                .background(GlpiColors.universalBlue.opacity(0.05))
                                .cornerRadius(12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 8)
                        } else {
                            OptionRow(title: opt, isSelected: selected == opt) {
                                if selected == opt {
                                    selected = ""
                                } else {
                                    selected = opt
                                }
                                onSelect()
                            }
                        }
                    }
                }
            }
            .overlay(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SPOffsetKey.self,
                            value: proxy.frame(in: .named("spScroll")).minY
                        )
                    },
                    alignment: .top
                )
                .padding(.top, vPadding)
                .padding(.bottom, vPadding)
                .padding(.leading, 8)
                .padding(.trailing, 18)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: SPHeightKey.self,
                            value: geo.size.height
                        )
                    }
                )
            }
            .coordinateSpace(name: "spScroll")
            .frame(height: listHeight)
            .onPreferenceChange(SPOffsetKey.self) { value in
                contentOffset = max(0, -value)
            }
            .onPreferenceChange(SPHeightKey.self) { value in
                if value > 0 { contentHeight = value }
            }

            // Barra de scroll customizada
            if contentHeight > listHeight {
                let inset:    CGFloat = 10
                let available          = listHeight - inset * 2
                let barH               = max(36, (listHeight / contentHeight) * available)
                let maxScroll          = contentHeight - listHeight
                let travel             = available - barH
                let progress           = min(max(contentOffset / maxScroll, 0), 1)

                Capsule()
                    .fill(GlpiColors.universalBlue.opacity(0.8))
                    .frame(width: 5, height: barH)
                    .padding(.trailing, 5)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, inset + progress * travel)
                    .frame(height: listHeight, alignment: .top)
                    .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

private struct SPOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct SPHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
