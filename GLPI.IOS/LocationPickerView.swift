import SwiftUI

struct LocationPickerView: View {
    let locations: [String]
    @Binding var selected: String
    var onSelect: () -> Void

    private let listHeight: CGFloat = 204  // 4×44 linhas + 3×4 spacing + 8 top + 8 bottom

    @State private var contentOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            // ScrollView com coordinateSpace nele próprio
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(locations, id: \.self) { loc in
                        OptionRow(title: loc, isSelected: selected == loc) {
                            selected = loc
                            onSelect()
                        }
                    }
                }
                .overlay(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: LocOffsetKey.self,
                            value: proxy.frame(in: .named("locScroll")).minY
                        )
                    },
                    alignment: .top
                )
                .padding(.top, 8)
                .padding(.bottom, 8)
                .padding(.leading, 8)
                .padding(.trailing, 18)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: LocContentHeightKey.self,
                            value: geo.size.height
                        )
                    }
                )
            }
            .coordinateSpace(name: "locScroll")
            .frame(height: listHeight)
            .onPreferenceChange(LocOffsetKey.self) { value in
                contentOffset = max(0, -value)
            }
            .onPreferenceChange(LocContentHeightKey.self) { value in
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
                    .fill(Color.white.opacity(0.55))
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

// PreferenceKeys privadas
private struct LocOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct LocContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
