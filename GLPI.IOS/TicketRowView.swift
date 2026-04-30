import SwiftUI

struct TicketRowView: View {
    let ticket: GLPITicket
    let isSelected: Bool
    var isDeleteMode: Bool = false
    var onLongPress: (CGFloat) -> Void = { _ in }
    var onSelect: () -> Void = {}
    @Binding var currentY: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Button(action: onSelect) {
                HStack(spacing: 16) {
                    // Priority Indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ticket.priority.color)
                        .frame(width: 4, height: 40)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(ticket.name)
                                .font(.amiko(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(ticket.id)
                                .font(.inconsolata(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        HStack(spacing: 15) {
                            Label(ticket.status.title, systemImage: ticket.status.icon)
                                .font(.amiko(size: 11))
                                .foregroundColor(ticket.status.color)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                                Text(formatDate(ticket.date))
                                    .font(.amiko(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "person")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                                Text(ticket.requester)
                                    .font(.amiko(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    if isDeleteMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .red : .white.opacity(0.4))
                            .font(.system(size: 22))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(15)
                .glassStyle(cornerRadius: 18, isSelection: isSelected)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        let yPos = geo.frame(in: .global).midY
                        onLongPress(yPos)
                    }
            )
        }
        .frame(height: 90)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "pt_PT")
        return formatter.string(from: date)
    }
}
