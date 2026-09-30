# Bottom Filter Overlay Style Specification

This document defines the custom, high-performance bottom sheet/filter overlay pattern developed for the GLPI Mobile iOS application. It completely replaces native SwiftUI `.sheet` presentations to prevent dark-mode touch highlights ("flashlight/lantern" glows) while replicating the native gesture detents.

---

## 1. Visual & Layout Metrics

| Element | Specification / Metric | Description |
| :--- | :--- | :--- |
| **Positioning** | Pushed to screen bottom (`Spacer()` on top) | Stretches to bottom edge |
| **Safe Area** | `.ignoresSafeArea(edges: .bottom)` | Ensures background spans down the home indicator |
| **Margins** | `padding(.horizontal, 0)`, `padding(.bottom, 0)` | Full-width bottom layout matching native sheet bounds |
| **Corner Radius** | `28pt` rounded corners on **top-left** & **top-right** only | Uses custom `RoundedCorner` shape; bottom is square |
| **Outline Border** | None | Clean edges without borders to match system look |
| **Drag Handle** | None | Drag indicator capsule is removed |
| **Title** | Centered horizontally, bold casing (`16pt`) | Example: `"Filtrar por Estado"` |

---

## 2. Color Palette & Dark Mode Strategy

| State / Mode | Light Mode (`isLightMode = true`) | Dark Mode (`isLightMode = false`) |
| :--- | :--- | :--- |
| **Card Background** | Pure White (`Color.white`) | Pure Black (`Color.black`) |
| **Text Color (Default)**| Black (`Color.black`) | Off-White (`Color.white.opacity(0.8)`) |
| **Divider / Separator**| None (Clean space spacing: `4pt`) | None (Clean space spacing: `4pt`) |
| **Selection Capsule** | `GlpiColors.universalBlue` | `GlpiColors.universalBlue` |
| **Selected Text** | White (`Color.white`) | White (`Color.white`) |
| **Shadow** | `.opacity(0.15)`, radius `25`, y `-10` | `.opacity(0.55)`, radius `25`, y `-10` |

---

## 3. Gesture Detent Logic (Two-State Bidirectional)

Instead of a single-direction swipe to dismiss, the overlay manages two interactive heights:
* **Medium Detent (Default):** `maxHeight: 240pt`
* **Large Detent (Expanded):** `maxHeight: 420pt`

### State Transitions (Drag Gesture on Header)
1. **From Medium Detent (`isFullyExpanded == false`):**
   * **Swipe Up (`yOffset < -45`):** Expands the sheet to Large Detent (`isFullyExpanded = true`).
   * **Swipe Down (`yOffset > 100`):** Dismisses the sheet (`isPresented = false`).
2. **From Large Detent (`isFullyExpanded == true`):**
   * **Swipe Down (`yOffset > 45`):** Shrinks the sheet back to Medium Detent (`isFullyExpanded = false`).
   * **Swipe Up (`yOffset < 0`):** Applies elastic friction (`yOffset * 0.2`) and springs back to `0` offset on release.

---

## 4. Reference Code Implementation

Below is the complete implementation of the overlay template (`TicketStatusFilterOverlay.swift`):

```swift
import SwiftUI

struct TicketStatusFilterOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedStatus: String
    @AppStorage("isLightMode_V2") var isLightMode = true
    
    @State private var offset: CGFloat = 0
    @State private var isFullyExpanded = false
    
    private let statuses = [
        "Todos", "Novo", "A processar (atribuído)", "A processar (planeado)",
        "Aguardando", "Resolvido", "Encerrado", "Não Resolvido"
    ]
    
    var body: some View {
        ZStack {
            // Dimming Background
            Color.black.opacity(isLightMode ? 0.25 : 0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }
            
            // Bottom-aligned card
            VStack {
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    // Header Drag Area
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Text("Filtrar por Estado")
                                .font(.amiko(size: 16, weight: .bold))
                                .foregroundColor(isLightMode ? .black : .white)
                            Spacer()
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 15)
                    }
                    .background(isLightMode ? Color.white : Color.black)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let yOffset = value.translation.height
                                if yOffset < 0 {
                                    offset = isFullyExpanded ? yOffset * 0.2 : yOffset * 0.4
                                } else {
                                    offset = yOffset
                                }
                            }
                            .onEnded { value in
                                let yOffset = value.translation.height
                                if isFullyExpanded {
                                    if yOffset > 45 {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            isFullyExpanded = false
                                            offset = 0
                                        }
                                    } else {
                                        withAnimation(.spring()) { offset = 0 }
                                    }
                                } else {
                                    if yOffset > 100 {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            isPresented = false
                                        }
                                    } else if yOffset < -45 {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            isFullyExpanded = true
                                            offset = 0
                                        }
                                    } else {
                                        withAnimation(.spring()) { offset = 0 }
                                    }
                                }
                            }
                    )
                    
                    // Options List
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 4) {
                            ForEach(statuses, id: \.self) { status in
                                filterMenuItem(title: status, isSelected: selectedStatus.lowercased() == status.lowercased()) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedStatus = status
                                        isPresented = false
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: isFullyExpanded ? 420 : 240)
                    
                    Spacer().frame(height: 35)
                }
                .background(isLightMode ? Color.white : Color.black)
                .cornerRadius(28, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(isLightMode ? 0.15 : 0.55), radius: 25, x: 0, y: -10)
                .offset(y: max(-20, offset))
            }
            .ignoresSafeArea(edges: .bottom)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .zIndex(15)
    }
    
    private func filterMenuItem(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.amiko(size: 15, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isLightMode ? .black : .white.opacity(0.8)))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? GlpiColors.universalBlue : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(NoHighlightButtonStyle())
        .padding(.horizontal, 12)
    }
}

// Helpers
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
```
