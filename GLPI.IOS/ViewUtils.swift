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
        if let d = formatter.date(from: self) { return d }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: self)
    }
}
