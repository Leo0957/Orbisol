import SwiftUI

// MARK: - Thème de l'interface (calqué sur la maquette)
//
// Fond « papier » chaud (#EAEAE6), noir encre, orange accent,
// chiffres en typographie mono technique.

enum Theme {
    // Papier chaud crème (#F2F1EC), encre, gris, orange maquette.
    static let paper  = Color(red: 0.949, green: 0.945, blue: 0.925) // #F2F1EC
    static let ink    = Color(red: 0.12, green: 0.12, blue: 0.11)
    static let dim    = Color(red: 0.47, green: 0.47, blue: 0.45)
    static let faint  = Color(red: 0.74, green: 0.73, blue: 0.71)
    static let line   = Color(red: 0.86, green: 0.85, blue: 0.82)
    static let accent = Color(red: 0.878, green: 0.529, blue: 0.106) // orange maquette
    /// Pastille « pêche » très claire derrière les icônes d'actions (Réglages).
    static let peach  = Color(red: 0.99, green: 0.85, blue: 0.71)

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

// MARK: - Petit logo (chevrons + point orange)

struct LogoMark: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 2, y: 4))
                p.addLine(to: CGPoint(x: 8.5, y: 20))
                p.addLine(to: CGPoint(x: 15, y: 5))
                p.addLine(to: CGPoint(x: 21.5, y: 20))
                p.addLine(to: CGPoint(x: 28, y: 4))
            }
            .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
                .offset(x: 15, y: 10)
        }
        .frame(width: 34, height: 24)
        .contentShape(Rectangle())
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
