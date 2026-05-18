import WidgetKit
import SwiftUI

struct GLPIWidgetEntry: TimelineEntry {
    let date: Date
    let ticketTitle: String
    let ticketDescription: String
    let ticketId: String
    let ticketTime: String
}

struct GLPIWidgetProvider: TimelineProvider {
    private let sharedDefaults = UserDefaults(suiteName: "group.trabalho.GLPI-IOS")

    func placeholder(in context: Context) -> GLPIWidgetEntry {
        GLPIWidgetEntry(
            date: Date(),
            ticketTitle: "AGUARDANDO DADOS",
            ticketDescription: "Abra a app para atualizar o widget.",
            ticketId: "...",
            ticketTime: "--:--"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GLPIWidgetEntry) -> ()) {
        let entry = fetchLatestEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GLPIWidgetEntry>) -> ()) {
        let entry = fetchLatestEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func fetchLatestEntry() -> GLPIWidgetEntry {
        let title = sharedDefaults?.string(forKey: "widget_ticket_title") ?? "SEM TICKETS"
        let desc = sharedDefaults?.string(forKey: "widget_ticket_desc") ?? "Não há atualizações recentes."
        let id = sharedDefaults?.string(forKey: "widget_ticket_id") ?? "---"
        let time = sharedDefaults?.string(forKey: "widget_ticket_time") ?? "--:--"
        
        return GLPIWidgetEntry(
            date: Date(),
            ticketTitle: title,
            ticketDescription: desc,
            ticketId: id,
            ticketTime: time
        )
    }
}

struct GLPIWidgetView : View {
    var entry: GLPIWidgetProvider.Entry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header Azul Total
            ZStack {
                Color(red: 0/255, green: 102/255, blue: 255/255)
            }
            .frame(height: 32)
            
            // Conteúdo Adaptativo
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.ticketTitle.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                Text(entry.ticketDescription)
                    .font(.system(size: 11))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : .gray)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                Spacer()
                
                HStack {
                    Text(entry.ticketTime)
                    Spacer()
                    Text(entry.ticketId)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(red: 0/255, green: 102/255, blue: 255/255))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colorScheme == .dark ? Color(red: 28/255, green: 28/255, blue: 30/255) : .white)
        }
    }
}

@main
struct GLPIWidget: Widget {
    let kind: String = "GLPIWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GLPIWidgetProvider()) { entry in
            GLPIWidgetView(entry: entry)
                .containerBackground(for: .widget) { 
                    // Fundo do container também segue o tema
                    Color(red: 0/255, green: 102/255, blue: 255/255) // Usa a cor de marca para a transição
                }
        }
        .configurationDisplayName("Tickets Recentes")
        .description("Acompanhe a última atualização do seu GLPI.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
