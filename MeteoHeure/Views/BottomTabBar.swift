import SwiftUI
import UIKit

// MARK: - Barre d'onglets flottante « Liquid Glass »
//
// Petite capsule de verre compacte qui flotte au-dessus du contenu, en bas
// de l'écran (le placement flottant — marges latérales et basse — est géré
// par MainView, qui la superpose au contenu).
//
// Rendu verre :
//  • iOS 26+  : vrai `glassEffect(.regular.interactive())` natif, avec
//    l'illumination spéculaire qui suit le doigt au toucher.
//  • iOS 16-25 : même apparence composée avec Material + teintes
//    translucides + reflet, pour rester fidèle au Liquid Glass.
//
// La pastille de l'onglet actif est une bulle de verre qui « coule » d'un
// onglet à l'autre (matchedGeometryEffect + ressort court). Appui : léger
// scale + retour haptique. Clair/sombre automatique via colorScheme ;
// Reduce Motion respecté (l'indicateur saute au lieu de glisser).

struct BottomTabBar: View {
    /// Hauteur totale de la capsule (hors marges flottantes).
    static let height: CGFloat = 64

    @Binding var selection: MainView.Screen

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var indicatorNamespace
    @State private var haptics = UIImpactFeedbackGenerator(style: .light)

    private let tabs: [(screen: MainView.Screen, icon: String, title: String)] = [
        (.clocks,   "clock",     "Horloges"),
        (.weather,  "cloud.sun", "Météo"),
        (.big,      "gauge",     "Grand format"),
        (.settings, "gearshape", "Réglages"),
    ]

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        glassBar
            .shadow(color: .black.opacity(isDark ? 0.30 : 0.12),
                    radius: 16, x: 0, y: 9)
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var glassBar: some View {
        if #available(iOS 26.0, *) {
            tabContent
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            tabContent
                .background(glassShell)
        }
    }

    private var tabContent: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.screen) { tab in
                tabButton(tab)
            }
        }
        .padding(5)
        .frame(height: Self.height)
    }

    // MARK: - Coque de verre

    @ViewBuilder
    private var glassShell: some View {
        Group {
            // Équivalent composé pour iOS 16-25 : Material + voile.
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(isDark ? Color.white.opacity(0.07)
                                     : Color.black.opacity(0.035))
                }
        }
        .overlay {
            // Fine bordure claire — jamais épaisse.
            Capsule()
                .strokeBorder(
                    LinearGradient(colors: [
                        .white.opacity(isDark ? 0.30 : 0.65),
                        .white.opacity(isDark ? 0.10 : 0.28),
                        .white.opacity(isDark ? 0.18 : 0.45),
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        }
        .overlay {
            // Reflet spéculaire discret sur la moitié haute.
            Capsule()
                .fill(
                    LinearGradient(colors: [
                        .white.opacity(isDark ? 0.10 : 0.22),
                        .white.opacity(0.0),
                    ], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.62))
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Onglet

    private func tabButton(_ tab: (screen: MainView.Screen, icon: String, title: String)) -> some View {
        let active = selection == tab.screen

        return Button {
            select(tab.screen)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: active ? 20 : 19,
                                  weight: active ? .semibold : .regular))
                    .frame(height: 23)

                Text(tab.title.uppercased())
                    .font(.system(size: 8.4, weight: active ? .bold : .semibold))
                    .tracking(0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .foregroundStyle(active ? activeTint : inactiveTint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if active {
                    activeIndicator
                        .matchedGeometryEffect(id: "tabIndicator", in: indicatorNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(TabPressStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }

    /// Bulle de verre derrière l'icône active (neutre — jamais un « gros bouton coloré »).
    @ViewBuilder
    private var activeIndicator: some View {
        if #available(iOS 26.0, *) {
            // Une teinte simple laisse le verre de la barre échantillonner le fond.
            Capsule()
                .fill(activeTint.opacity(isDark ? 0.16 : 0.09))
        } else {
            legacyActiveIndicator
        }
    }

    private var legacyActiveIndicator: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .fill(
                        LinearGradient(colors: isDark
                            ? [Color.white.opacity(0.20), Color.white.opacity(0.05)]
                            : [Color.black.opacity(0.14), Color.black.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
            .overlay {
                // Pointe d'accent (orange du thème) — très discrète.
                Capsule()
                    .fill(
                        LinearGradient(colors: [
                            Theme.accent.opacity(isDark ? 0.16 : 0.07),
                            .clear,
                        ], startPoint: .bottomTrailing, endPoint: .topLeading)
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(colors: [
                            .white.opacity(isDark ? 0.40 : 0.75),
                            .white.opacity(isDark ? 0.12 : 0.30),
                        ], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(isDark ? 0.35 : 0.10), radius: 5, x: 0, y: 2)
    }

    private var activeTint: Color { isDark ? .white : Theme.ink }
    private var inactiveTint: Color { isDark ? .white.opacity(0.55) : Theme.ink.opacity(0.5) }

    // MARK: - Sélection (animation + haptique)

    private func select(_ screen: MainView.Screen) {
        guard screen != selection else { return }
        haptics.impactOccurred()
        if reduceMotion {
            selection = screen
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82, blendDuration: 0.06)) {
                selection = screen
            }
        }
    }
}

// MARK: - Style d'appui : léger scale au toucher (1 → 0.94 → 1)

private struct TabPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.86 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: configuration.isPressed ? 0.18 : 0.34,
                        dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

// MARK: - Aperçus (clair / sombre)

#Preview("Clair") {
    ZStack {
        Theme.paper.ignoresSafeArea()
        VStack {
            Spacer()
            BottomTabBar(selection: .constant(.clocks))
                .padding(.horizontal, 16)
        }
    }
}

#Preview("Sombre") {
    ZStack {
        Color(red: 0.09, green: 0.09, blue: 0.09).ignoresSafeArea()
        VStack {
            Spacer()
            BottomTabBar(selection: .constant(.weather))
                .padding(.horizontal, 16)
        }
    }
    .preferredColorScheme(.dark)
}
