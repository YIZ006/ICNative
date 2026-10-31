import WidgetKit
import SwiftUI

private let appGroupId = "group.com.abom.utas.utas"
private let imageKey = "widget_image_path"
private let senderKey = "widget_sender_name"

struct OrbitTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> OrbitWidgetEntry {
        OrbitWidgetEntry(date: Date(), imagePath: nil, senderName: "Bạn bè")
    }

    func getSnapshot(in context: Context, completion: @escaping (OrbitWidgetEntry) -> Void) {
        completion(OrbitWidgetEntry(date: Date(), imagePath: resolvedImagePath(), senderName: resolvedSenderName()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OrbitWidgetEntry>) -> Void) {
        let entry = OrbitWidgetEntry(date: Date(), imagePath: resolvedImagePath(), senderName: resolvedSenderName())
        completion(Timeline(entries: [entry], policy: .atEnd))
    }

    private func resolvedImagePath() -> String? {
        let prefs = UserDefaults(suiteName: appGroupId)
        guard let path = prefs?.string(forKey: imageKey), !path.isEmpty else { return nil }
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }

    private func resolvedSenderName() -> String {
        let prefs = UserDefaults(suiteName: appGroupId)
        return prefs?.string(forKey: senderKey) ?? "Bạn bè"
    }
}

struct OrbitWidgetEntry: TimelineEntry {
    let date: Date
    let imagePath: String?
    let senderName: String
}

struct OrbitWidgetEntryView: View {
    var entry: OrbitTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Background Ivory
            Color(red: 247/255, green: 245/255, blue: 238/255)

            if let path = entry.imagePath, let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Text(entry.senderName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.55))
                                    .cornerRadius(8)
                                Spacer()
                            }
                            .padding(8)
                        }
                    )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(Color(red: 44/255, green: 53/255, blue: 34/255))
                    Text("Orbit Widget")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 44/255, green: 53/255, blue: 34/255))
                    Text("Mở app để lưu & cập nhật ảnh")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 44/255, green: 53/255, blue: 34/255).opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
        .widgetURL(URL(string: "icnative://open"))
    }
}

@main
struct OrbitWidgetBundle: WidgetBundle {
    var body: some Widget {
        OrbitWidget()
    }
}

struct OrbitWidget: Widget {
    let kind: String = "OrbitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OrbitTimelineProvider()) { entry in
            OrbitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Orbit")
        .description("Đưa bạn bè và người thương lên màn hình chính iPhone.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
