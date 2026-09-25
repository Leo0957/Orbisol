import SwiftUI

/// Écran d'ajout : une recherche (ville / pays / région) et une liste de résultats.
/// La recherche est débouncée (300 ms) pour limiter les appels réseau.
struct AddLocationView: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Location] = []
    @State private var isSearching = false
    @State private var searchErrorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView("Recherche…")
                        Spacer()
                    }
                } else if let message = searchErrorMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if query.count < 2 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recherchez une ville, un pays ou une région.")
                            .font(.subheadline)
                        Text("Par exemple : Abidjan, Québec, Tokyo…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if results.isEmpty {
                    Text("Aucun résultat.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(results) { location in
                        Button {
                            addAndDismiss(location)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(subtitle(for: location))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Ajouter une ville")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Ville, pays, région…")
            .tint(Theme.accent)
            .onChange(of: query) { newQuery in
                scheduleSearch(newQuery)
            }
        }
    }

    // MARK: - Recherche débouncée

    /// Annule la recherche précédente puis en planifie une nouvelle
    /// après 300 ms de pause de frappe.
    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            searchErrorMessage = nil
            return
        }
        isSearching = true
        searchErrorMessage = nil

        let task = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // debounce
            guard !Task.isCancelled else { return }
            let found = await viewModel.searchLocations(query: trimmed)
            guard !Task.isCancelled else { return }
            searchErrorMessage = found.isEmpty ? "Aucun résultat pour « \(trimmed) »." : nil
            results = found
            isSearching = false
        }
        searchTask = task
    }

    private func addAndDismiss(_ location: Location) {
        viewModel.add(location)
        dismiss()
    }

    private func subtitle(for location: Location) -> String {
        var parts: [String] = []
        if let region = location.region, !region.isEmpty { parts.append(region) }
        if let country = location.country, !country.isEmpty { parts.append(country) }
        parts.append(utcLabel(location))
        return parts.joined(separator: " · ")
    }

    /// Libellé « UTC+1 » / « UTC-5:30 » calculé depuis le fuseau du lieu.
    private func utcLabel(_ location: Location) -> String {
        let seconds = location.timeZone?.secondsFromGMT(for: Date()) ?? 0
        let totalMinutes = seconds / 60
        let sign = totalMinutes < 0 ? "-" : "+"
        let hours = abs(totalMinutes) / 60
        let minutes = abs(totalMinutes) % 60
        if minutes == 0 { return "UTC\(sign)\(hours)" }
        return String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }
}

#Preview {
    AddLocationView()
        .environmentObject(LocationsViewModel())
}