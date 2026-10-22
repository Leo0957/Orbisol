import SwiftUI
import CoreText

enum ClockTypeface: String, CaseIterable, Identifiable {
    case orbitron, oxanium, rajdhani, digital, shareTechMono, spaceMono, system

    static let storageKey = "Orbisol.clockTypeface"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .orbitron: return "Orbitron"
        case .oxanium: return "Oxanium"
        case .rajdhani: return "Rajdhani"
        case .digital: return "DSEG 7"
        case .shareTechMono: return "Share Tech Mono"
        case .spaceMono: return "Space Mono"
        case .system: return "Classique"
        }
    }
    var detail: String {
        switch self {
        case .orbitron: return "Futuriste · Par défaut"
        case .oxanium: return "Technique et géométrique"
        case .rajdhani: return "Élégante et élancée"
        case .digital: return "Horloge numérique à sept segments"
        case .shareTechMono: return "Esprit terminal"
        case .spaceMono: return "Rétro et expressive"
        case .system: return "La police originale d’Orbisol"
        }
    }

    // Bundled fonts work offline. Registration happens once per process.
    private static let registered: Void = {
        for name in ["Orbitron", "Oxanium", "Rajdhani", "DSEG7Classic-Regular", "ShareTechMono", "SpaceMono"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()

    func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        _ = Self.registered
        let name: String
        switch self {
        case .orbitron: name = "Orbitron-Regular"
        case .oxanium: name = "Oxanium-ExtraLight"
        case .rajdhani: name = "Rajdhani-SemiBold"
        case .digital: name = "DSEG7Classic-Regular"
        case .shareTechMono: name = "ShareTechMono-Regular"
        case .spaceMono: name = "SpaceMono-Regular"
        case .system: return .system(size: size, weight: weight, design: .monospaced)
        }
        return .custom(name, size: size).weight(weight)
    }
}

private struct ClockTypefaceModifier: ViewModifier {
    @AppStorage(ClockTypeface.storageKey) private var selection = ClockTypeface.orbitron.rawValue
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .font((ClockTypeface(rawValue: selection) ?? .orbitron).font(size, weight: weight))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

extension View {
    func clockTypeface(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ClockTypefaceModifier(size: size, weight: weight))
    }
}

struct ClockTypefaceSettings: View {
    @AppStorage(ClockTypeface.storageKey) private var selection = ClockTypeface.orbitron.rawValue
    @EnvironmentObject private var viewModel: LocationsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Choisissez le style des horaires. Votre choix est appliqué immédiatement et enregistré automatiquement.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.dim)
                ForEach(ClockTypeface.allCases) { typeface in
                    Button {
                        selection = typeface.rawValue
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(typeface.title).font(.headline)
                                    Text(typeface.detail).font(.caption).foregroundStyle(Theme.dim)
                                }
                                Spacer()
                                Image(systemName: selected == typeface ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected == typeface ? Theme.accent : Theme.faint)
                                    .font(.title2)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(viewModel.hour12 ? "09:41" : "21:41")
                                    .font(typeface.font(40, weight: .bold))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                if viewModel.hour12 {
                                    Text("pm").font(.caption).foregroundStyle(Theme.dim)
                                }
                            }
                            .accessibilityHidden(true)
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected == typeface ? Theme.accent.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(selected == typeface ? Theme.accent : Theme.line, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(typeface.title + ", " + typeface.detail)
                    .accessibilityAddTraits(selected == typeface ? .isSelected : [])
                }
            }
            .padding(20)
        }
        .background(Theme.paper)
        .navigationTitle("Police d’écriture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var selected: ClockTypeface { ClockTypeface(rawValue: selection) ?? .orbitron }
}

// MARK: - Thème de l'interface (calqué sur la maquette)
//
// Fond « papier » chaud (#EAEAE6), noir encre, orange accent,
// chiffres en typographie mono technique.

enum Theme {
    // Papier chaud crème (#F2F1EC), encre, gris, orange maquette.
    static let paper = adaptive(UIColor(red: 0.949, green: 0.945, blue: 0.925, alpha: 1), .init(white: 0.075, alpha: 1))
    static let ink = adaptive(.init(white: 0.12, alpha: 1), .init(white: 0.94, alpha: 1))
    static let dim = adaptive(.init(white: 0.45, alpha: 1), .init(white: 0.70, alpha: 1))
    static let faint = adaptive(.init(white: 0.60, alpha: 1), .init(white: 0.53, alpha: 1))
    static let line = adaptive(.init(white: 0.84, alpha: 1), .init(white: 0.23, alpha: 1))
    static let accent = Color(red: 0.878, green: 0.529, blue: 0.106) // orange maquette
    /// Pastille « pêche » très claire derrière les icônes d'actions (Réglages).
    static let peach = adaptive(.init(red: 0.99, green: 0.85, blue: 0.71, alpha: 1), .init(red: 0.28, green: 0.20, blue: 0.12, alpha: 1))
    private static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Chiffres « digital » (SF Mono).
    static func digit(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// Texte courant.
    static func label(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - En-tête de section (HORLOGES / Villes suivies / …)
//
// Bloc commun aux écrans « liste » (Horloges, Réglages) : sur-titre orange
// en capitales espacées, titre principal encre en graisse forte, puis une
// ligne de description grise.

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(2.6)
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(Theme.ink)
                .padding(.top, 3)
            Text(subtitle)
                .font(.system(size: 13.5, weight: .regular))
                .tracking(0.1)
                .foregroundStyle(Theme.dim)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Filet séparateur fin (réglages, lignes de listes)

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1)
    }
}

// MARK: - Logo Orbisol

struct LogoMark: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Group {
            if colorScheme == .dark {
                HStack(spacing: 5) {
                    Text("ORBISOL").font(ClockTypeface.orbitron.font(20, weight: .bold)).foregroundStyle(Theme.ink)
                    Text(".").font(.title.bold()).foregroundStyle(Theme.accent)
                }
            } else {
                Image("LogoOrbisolWordmark").resizable().scaledToFit()
            }
        }
        .frame(width: 150, height: 45)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Orbisol")
    }
}

// MARK: - Toggle 12h / 24h (pilule noire = actif)

struct FormatToggle: View {
    let hour12: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 3) {
            chip("12h", active: hour12) { onChange(true) }
            chip("24h", active: !hour12) { onChange(false) }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 7).stroke(Theme.faint, lineWidth: 1))
    }

    private func chip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(active ? Theme.paper : Theme.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(active ? Theme.ink : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}

// MARK: - Sélecteur °C / °F (utilisé dans le menu)

struct UnitToggle: View {
    let fahrenheit: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 3) {
            unit("°C", active: !fahrenheit) { onChange(false) }
            unit("°F", active: fahrenheit) { onChange(true) }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 7).stroke(Theme.faint, lineWidth: 1))
    }

    private func unit(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(active ? Theme.paper : Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 4.5)
            .background(active ? Theme.ink : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}

// MARK: - Sélecteur d'options (chips encre, 3 valeurs max)
//
// Même langage visuel que FormatToggle / UnitToggle : une bordure fine
// theme.faint et la valeur active en pastille encre.

struct OptionToggle: View {
    let options: [(value: Int, label: String)]
    let selected: Int
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                chip(option)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 7).stroke(Theme.faint, lineWidth: 1))
    }

    private func chip(_ option: (value: Int, label: String)) -> some View {
        Text(option.label)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.3)
            .foregroundStyle(option.value == selected ? Theme.paper : Theme.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(option.value == selected ? Theme.ink : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
            .onTapGesture { onChange(option.value) }
    }
}
