import SwiftUI
import MapKit
import Charts

struct RadarResponse: Decodable {
    let host: String
    let radar: Radar
    struct Radar: Decodable { let past: [Frame] }
    struct Frame: Decodable, Identifiable {
        let time: Double
        let path: String
        var id: Double { time }
    }
}

struct RadarView: View {
    @EnvironmentObject private var model: LocationsViewModel
    let location: Location
    @Environment(\.scenePhase) private var scenePhase
    @State private var response: RadarResponse?
    @State private var index = 0.0
    @State private var playing = false
    @State private var loading = false
    @State private var error: String?
    private var frames: [RadarResponse.Frame] { response?.radar.past ?? [] }
    private var frame: RadarResponse.Frame? { frames.indices.contains(Int(index)) ? frames[Int(index)] : nil }
    var body: some View {
        VStack(spacing: 12) {
            if let response, let frame {
                RadarMap(location: location, host: response.host, path: frame.path)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Button { playing.toggle() } label: { Image(systemName: playing ? "pause.fill" : "play.fill").frame(width: 44, height: 44) }
                        .accessibilityLabel(playing ? "Pause" : "Animer le radar")
                    Slider(value: $index, in: 0...Double(max(1, frames.count - 1)), step: 1)
                        .disabled(frames.count < 2).accessibilityLabel("Image radar")
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }
                        .accessibilityLabel("Actualiser le radar").disabled(loading)
                }.padding(.horizontal)
                Text("Observation : \(WorldTime.time(Date(timeIntervalSince1970: frame.time), zone: location.timeZone ?? .current)) · heure de \(location.name)")
                    .font(.subheadline).monospacedDigit()
                Text("Zones sombres : couverture radar absente. Une zone transparente peut indiquer l’absence de pluie ou de données récentes.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            } else if loading { Spacer(); ProgressView("Chargement du radar…"); Spacer() }
            forecastSection
            if let error {
                Text(error).font(.footnote).padding()
                Button("Réessayer") { Task { await load() } }.disabled(loading)
            }
            Link("Radar : RainViewer", destination: URL(string: "https://www.rainviewer.com/")!)
                .font(.caption).padding(.bottom, 10)
        }
        .navigationTitle("Radar · \(location.name)").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: playing) {
            while playing && !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_200_000_000) } catch { return }
                if !frames.isEmpty { index = Double((Int(index) + 1) % frames.count) }
            }
        }
        .onChange(of: scenePhase) { if $0 != .active { playing = false } }
        .onDisappear { playing = false }
    }
    private struct RainPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let amount: Double
    }
    private var forecastPoints: [RainPoint] {
        guard let minute = model.weatherByLocation[location.id]?.minutely15 else { return [] }
        return minute.time.enumerated().compactMap { index, raw in
            guard minute.precipitation.indices.contains(index),
                  let amount = minute.precipitation[index],
                  let date = WorldTime.parse(raw, zone: location.timeZone ?? .current),
                  date > Date(), date < Date().addingTimeInterval(3 * 3600) else { return nil }
            return RainPoint(date: date, amount: amount)
        }
    }
    private var forecastSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Pluie prévue · 3 heures").font(.headline)
            if forecastPoints.isEmpty {
                Text("Prévision à 15 minutes indisponible pour cette ville.").font(.caption)
            } else {
                Chart(forecastPoints) { point in
                    BarMark(x: .value("Heure", point.date), y: .value("mm / 15 min", point.amount))
                        .foregroundStyle(Theme.accent)
                }.frame(height: 110)
            }
            Text("Prévision modélisée Open-Meteo, distincte des images radar observées RainViewer.")
                .font(.caption2).foregroundStyle(.secondary)
            Text(model.dataStatus(for: location).label).font(.caption2).foregroundStyle(.secondary)
        }.padding(.horizontal)
    }
    @MainActor private func load() async {
        guard !loading else { return }
        loading = true; playing = false; error = nil
        defer { loading = false }
        do {
            let (data, raw) = try await URLSession.shared.data(from: URL(string: "https://api.rainviewer.com/public/weather-maps.json")!)
            guard (raw as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let value = try JSONDecoder().decode(RadarResponse.self, from: data)
            guard let host = URL(string: value.host), host.scheme == "https", host.host == "tilecache.rainviewer.com",
                  !value.radar.past.isEmpty, value.radar.past.allSatisfy({ $0.path.hasPrefix("/v2/radar/") }) else { throw URLError(.cannotParseResponse) }
            response = value
            index = Double(value.radar.past.count - 1)
        } catch { self.error = "Radar indisponible. Vérifiez la connexion puis réessayez." }
    }
}

struct RadarMap: UIViewRepresentable {
    let location: Location
    let host: String
    let path: String
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        // Public radar tiles stop at zoom 7; keep a useful regional scale.
        map.isZoomEnabled = false
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)), animated: false)
        let marker = MKPointAnnotation()
        marker.coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        marker.title = location.name
        map.addAnnotation(marker)
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        guard context.coordinator.path != path else { return }
        context.coordinator.path = path
        map.removeOverlays(map.overlays)
        let radar = MKTileOverlay(urlTemplate: "\(host)\(path)/256/{z}/{x}/{y}/2/1_1.png")
        radar.maximumZ = 7
        let coverage = MKTileOverlay(urlTemplate: "\(host)/v2/coverage/0/256/{z}/{x}/{y}/0/0_0.png")
        coverage.maximumZ = 7
        map.addOverlay(radar, level: .aboveRoads)
        map.addOverlay(coverage, level: .aboveRoads)
    }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var path = ""
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tiles = overlay as? MKTileOverlay else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKTileOverlayRenderer(tileOverlay: tiles)
            renderer.alpha = tiles.urlTemplate?.contains("coverage") == true ? 0.3 : 0.7
            return renderer
        }
    }
}
