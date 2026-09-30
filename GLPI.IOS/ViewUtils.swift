//
//  ViewUtils.swift
//  GLPI.IOS
//

import SwiftUI

struct YOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension Date {
    func firstDayOfMonth() -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        if let date = calendar.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-01 00:00:00"
            return formatter.string(from: date)
        }
        return ""
    }
}
extension String {
    func toDate() -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let d = formatter.date(from: self) { return d }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: self)
    }
}

// MARK: - Sistema Universal de Alertas (Toast)

enum GLPIToastType: Sendable {
    case success
    case error
    
    var color: Color {
        switch self {
        case .success:
            return GlpiColors.universalBlue
        case .error:
            return Color.red
        }
    }
}

struct GLPIToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let type: GLPIToastType
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.amiko(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(type.color.opacity(0.95))
                                .shadow(color: type.color.opacity(0.4), radius: 10, x: 0, y: 4)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.keyboard)
                .zIndex(999)
                .onAppear {
                    let generator = UINotificationFeedbackGenerator()
                    switch type {
                    case .success:
                        generator.notificationOccurred(.success)
                    case .error:
                        generator.notificationOccurred(.error)
                    }
                    
                    // Auto-dismiss após 1.5 segundos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func glpiToast(isPresented: Binding<Bool>, message: String, type: GLPIToastType) -> some View {
        self.modifier(GLPIToastModifier(isPresented: isPresented, message: message, type: type))
    }
}
