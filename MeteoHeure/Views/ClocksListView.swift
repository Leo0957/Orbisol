import SwiftUI

/// Écran « Horloges » de la maquette.
/// En-tête de section, puis la liste des villes suivies. Chaque ligne :
/// fuseau (UTC+2) + ville + pays à gauche, heure locale en gros chiffres
/// + suffixe am/pm à droite, et une ligne météo discrète (temp · temps).
/// La carte « Ajouter une ville » ferme la liste.
struct ClocksListView: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    let onSelect: (Location) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.locations.isEmpty {
                empty
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ScreenHeader(eyebrow: "Horloges",
                                     title: "Villes suivies",
                                     subtitle: "Fuseaux, météo rapide et pluie à venir")
                            .padding(.top, 18)
                            .padding(.bottom, 4)

                        ForEach(viewModel.locations) { location in
                            row(location)
                            Hairline()
                        }
                        addCard
                            .padding(.top, 18)
                            .padding(.bottom, 4)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Ligne horloge

    private func row(_ location: Location) -> some View {
        let t = ClockFormat.time(timeZone: location.timeZone ?? .current,
                                 hour12: viewModel.hour12,
                                 date: viewModel.now)
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ClockFormat.utcLabel(timeZone: location.timeZone ?? .current))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.dim)
                HStack(spacing: 7) {
                    Text(location.name.uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.ink)
                    if viewModel.isPrimary(location) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("Ville principale")
                    }
                }
                Text(location.countrySubtitle)
                    .font(.system(size: 12.5, weight: .regular))
                    .tracking(0.2)
                    .foregroundStyle(Theme.dim)
                if let current = viewModel.weatherByLocation[location.id]?.current {
                    weatherLine(current, location: location)
                        .padding(.top, 3)
                }
            }
            Spacer(minLength: 12)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(t.text)
                    .font(Theme.digit(44, .bold))
                    .tracking(0.5)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                if !t.suffix.isEmpty {
                    VStack(spacing: 3) {
                        Circle().fill(Theme.dim).frame(width: 3.5, height: 3.5)
                        Text(t.suffix)
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.dim)
                    }
                }
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(location) }
        .contextMenu {
            if !viewModel.isPrimary(location) {
                Button {
                    viewModel.makePrimary(location)
                } label: {
                    Label("Ville principale", systemImage: "star")
                }
            }
            Button(role: .destructive) {
                viewModel.remove(location)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    /// « 18° · ciel clair » — ou « 18° · pluie vers 11 am » si la pluie approche.
    private func weatherLine(_ current: OpenMeteoResponse.Current, location: Location) -> some View {
        HStack(spacing: 6) {
            Image(systemName: WeatherStyle.symbol(code: current.weatherCode,
                                                  isDay: current.isDay == 1))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 15)
            Text(weatherSummary(current, location: location))
                .font(.system(size: 12.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.dim)
        }
    }

    private func weatherSummary(_ current: OpenMeteoResponse.Current, location: Location) -> String {
        let temperature = viewModel.tempText(current.temperature2m, for: location)
        if case .soon(_, let hour) = viewModel.nextRain(for: location) {
            return "\(temperature) · pluie vers \(ClockFormat.shortHour(hour: hour, hour12: viewModel.hour12))"
        }
        return "\(temperature) · \(WeatherStyle.shortCondition(code: current.weatherCode))"
    }

    // MARK: - Carte « ajouter » (dégradé pêche → bleu de la maquette)

    private var addCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(colors: [
                        Color(red: 0.99, green: 0.83, blue: 0.61),
                        Color(red: 0.66, green: 0.83, blue: 0.95),
                        Color(red: 0.42, green: 0.65, blue: 0.88)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }
            .padding(20)

            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Text("Ajouter une ville")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(.white)
                Text("ville · pays · région")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(20)

            Button {
                onAdd()
            } label: {
                ZStack {
                    Circle().fill(.white)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
            .padding(14)
            .accessibilityLabel("Ajouter une ville")
        }
        .frame(height: 158)
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundStyle(Theme.dim)
            Text("Aucune ville enregistrée")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Button {
                onAdd()
            } label: {
                Text("Ajouter une ville")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.paper)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.ink, in: Capsule())
            }
            Spacer()
        }
    }
}
