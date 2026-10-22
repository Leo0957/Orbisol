import SwiftUI
import WidgetKit

/// Point d'entrée de l'extension widget (cible « MeteoHeureWidget »).
@main
struct MeteoHeureWidgetBundle: WidgetBundle {
    var body: some Widget {
        availableWidgets
    }

    private var availableWidgets: some Widget {
        if #available(iOS 17.0, *) {
            return WidgetBundleBuilder.buildBlock(ConfiguredDayNightWidget(), OrbisolWeatherWidget(), OrbisolRainWidget(), OrbisolMultiCityWidget())
        } else {
            return DayNightWidget()
        }
    }
}

/// Rectangulaire « Jour · Nuit » : carte du monde en points, où il fait
/// jour ou nuit, avec un marqueur orange pour les villes suivies.
struct DayNightWidget: Widget {
    let kind = "DayNightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayNightProvider()) { entry in
            DayNightWidgetView(date: entry.date, cities: entry.cities)
        }
        .configurationDisplayName("Jour · Nuit")
        .description("La carte du monde en points : où il fait jour, où il fait nuit.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
