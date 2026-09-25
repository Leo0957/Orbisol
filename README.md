# Météo · Heure — application iPhone

Application native **Swift / SwiftUI** (iOS 16+, iPhone) affichant la météo et
l'heure locale pour plusieurs lieux : villes, pays, régions.

- Architecture **MVVM** (`Models / Views / ViewModels / Services`)
- Réseau : **URLSession + async/await** (Swift Concurrency)
- Persistance : `UserDefaults` (JSON) pour la liste des lieux
- Horloge en direct : tick 1×/seconde, heure **locale du lieu** (fuseau IANA)
- **Widget « Jour · Nuit »** (extension WidgetKit) : carte du monde en points denses
  (petit / rectangle / grand), voile de nuit réel calculé en local, heure locale
  « live » — aucune donnée réseau nécessaire
- Zéro dépendance externe, zéro clé API requise par défaut

---

## 1. Prérequis

- Un Mac avec **Xcode 16 ou plus récent** (testé avec Xcode 26)
- **Important — runtime du simulateur** : si `xcrun simctl list runtimes`
  ne retourne aucun runtime (installations fraîches), ouvrez
  *Xcode → Settings → Components* et téléchargez **« iOS 26.5 Simulator »**
  (~8,5 Go, une seule fois). Sans cela, `actool` refuse de compiler quoi
  que ce soit, simulateur comme appareil physique.

## 2. Lancer l'application

1. Ouvrez `MeteoHeure.xcodeproj` avec Xcode.
2. *(Une seule fois)* — icône de l'app : dans le navigateur de projet,
   ajoutez le dossier `Resources/Assets.xcassets` au projet
   (*File → Add Files to “MeteoHeure”…*, cible `MeteoHeure` cochée),
   puis déposez une image carrée **1024 × 1024** dans `AppIcon`.
   Le projet compile sans cette étape, l'app aura juste l'icône générique.
3. Sélectionnez un simulateur iPhone (ex. « iPhone 16 Pro ») dans la barre
   du haut, puis appuyez sur **Run** (⌘R).
4. Pour un **iPhone physique** : branchez l'appareil, choisissez-le comme
   destination, puis dans *Signing & Capabilities* de la cible `MeteoHeure`,
   sélectionnez votre **équipe** de développement Apple (gratuite pour un
   test personnel). Sur appareil, un compte développeur gratuit suffit.

## 3. API météo

L'application utilise **Open-Meteo** par défaut : gratuit, sans clé API, aucun
compte à créer. Géocodage et prévisions passent par `WeatherService.swift`.

### Passer à OpenWeatherMap (optionnel)

1. Créez un compte gratuit sur <https://home.openweathermap.org>.
2. Onglet **API keys** → « Create Key » (clé gratuite : 1 000 appels/jour).
3. Collez la clé dans `MeteoHeure/Services/WeatherAPI.swift` :
   `WeatherAPI.openWeatherMapKey = "votre_clé"`.
   ⚠️ Ce fichier est ignoré par git : la clé ne sera jamais versionnée.
4. Suivez le bloc de commentaires en tête de `WeatherService.swift`
   (URL « One Call API 3.0 » + correspondance des champs).

## 4. Structure du projet

```
MeteoHeure/
├── WeatherApp.swift                 @main, cycle de vie (scenePhase)
├── Models/
│   ├── Location.swift               Lieu : nom, région, pays, lat/lon, fuseau IANA
│   ├── WeatherResponse.swift        DTO Codable de l'API (OpenMeteoResponse)
│   ├── HourlyForecast.swift         Prévision horaire (parse heure locale)
│   └── DailyForecast.swift          Prévision journalière (parse date locale)
├── Services/
│   ├── WeatherService.swift         URLSession : météo + géocodage (async/await)
│   └── WeatherAPI.swift             Clés API éventuelles (gitignoré)
├── ViewModels/
│   └── LocationsViewModel.swift     Liste, cache météo, horloge, persistance
└── Views/
    ├── MainView.swift               Écran racine : barre du haut + onglets
    ├── BottomTabBar.swift           Barre d'onglets bas « liquid glass » (verre dépoli)
    ├── ClocksListView.swift         Liste des horloges (UTC, heure, météo, ★)
    ├── WeatherScreen.swift          Écran Météo : globe pointilliste, soleil
    ├── BigClockScreen.swift         Grand format (h/min/s + cadran radial)
    ├── AddLocationView.swift        Recherche / ajout (déboünce 300 ms)
    ├── DetailView.swift             Détail : actuel, 24 h, 7 jours, qualité de l'air
    ├── WeatherIcon.swift            Codes WMO → SF Symbols, libellés, dégradés
    ├── TemperatureCurveView.swift   Courbe 24 h + sparkline UV
    └── Theme.swift                  Palette papier / encre / orange + toggles
```

Les quatre écrans — Horloges, Météo, Grand format, Réglages — se
naviguent par la barre d'onglets flottante en verre dépoli en bas de
l'écran (remplace l'ancien menu « ·· »).

```
MeteoHeureWidget/                  ← extension WidgetKit (cible séparée)
├── WidgetBundle.swift              @main de l'extension, configuration du widget
├── Timeline.swift                  TimelineProvider (actualisation ~15 min)
├── DayNightWidgetView.swift        Rendu Canvas : points jour/nuit + marqueurs
├── WorldMap.swift                  Masque terre/mer 1° (Natural Earth, zlib)
├── SharedGroup.swift               Lecture de l'App Group (`group.com.example.meteoheure`)
└── Info.plist                      Point d'extension com.apple.widgetkit-extension

Shared/AppGroup.entitlements        App Group partagé (les 2 cibles)
scripts/generate_worldmask.py       Régénère le masque terre/mer (Natural Earth)
```

## 5. Fonctionnalités avancées incluses

- **Ma position** (`::` → 05) : CoreLocation + géocodage inverse (CLGeocoder),
  autorisation demandée à la première utilisation.
- **Unité par ville** : appui long sur la température de l'écran Météo →
  °C / °F pour ce lieu uniquement (sinon réglage global).
- **Durée du jour** : affichée entre lever et coucher du soleil.
- **Courbe des 24 h** : température lissée (Catmull-Rom) + sparkline UV dans
  la feuille de prévisions, avec min/max et point « maintenant ».
- **Indice UV max** et **lever/coucher** ajoutés aux tuiles de détails.
- **Qualité de l'air** : AQI européen + PM2.5 / PM10 / ozone (Open-Meteo
  Air Quality, sans clé).
- **Alertes pluie** (`::` → réglages) : notification locale programmée
  avant une pluie probable, **une par ville**. Seuil (40 / 55 / 70 %) et
  préavis (30 min / 1 h / 2 h) réglables dans le menu — les notifications
  sont reprogrammées à chaque changement de réglage.
- **« Prochaine pluie »** : résumé automatique (« Pluie vers 18 h · 70 % »
  ou « Pas de pluie prévue ») dans la liste des horloges, l'écran Météo et
  la feuille de prévisions.
- **Fraîcheur des données** : « mis à jour il y a X min » affiché sur
  l'écran Météo (passe en orange si les données ont plus de 30 min).
- **Ville principale** : une étoile orange marque la ville en tête de liste
  (appui long sur une ligne → « Ville principale »). Elle reste cohérente
  avec l'écran Météo, le grand format et le widget (marqueur à halo).
- **Sync iCloud** (`::` → réglages) : les villes sont partagées via
  NSUbiquitousKeyValueStore. ⚠️ Activez la capacité **iCloud** dans
  *Signing & Capabilities* de la cible pour que la synchronisation
  fonctionne réellement (sans cela le code est inoffensif).

## 6. Widget « Jour · Nuit » (écran d'accueil)

Carte du monde en **points denses** (grille 1°, masque Natural Earth) dans la
tonalité exacte de l'application : fond papier chaud, points **orange cuivré**
côté jour, **brun-gris** côté nuit, et un **voile de nuit semi-transparent**
dont le tracé suit le terminateur réel — position du Soleil calculée
localement (point subsolaire, déclinaison, équation du temps), aucune requête
réseau. La carte est actualisée toutes les ~15 minutes (la fréquence réelle
reste pilotée par WidgetKit) et l'heure affichée est « live » : elle suit la
ville **sélectionnée dans l'app** (sinon la ville principale) et le format
12 h/24 h choisi.

Trois tailles : **petit** (globe pointilliste jour/nuit de la ville, comme
l'écran Météo), **rectangle** (carte pleine largeur + étiquette ville/heure) et
**grand** (carte + horloges des villes suivies, comme l'écran « Horloges »).

### Ajouter le widget sur l'écran d'accueil

1. Appui long sur l'écran d'accueil → **+** en haut à gauche → rechercher
   « **Météo · Heure** » → choisir « **Jour · Nuit** » (petit, rectangle ou grand).
2. Les marqueurs suivent automatiquement les villes sauvegardées dans l'app
   (l'application écrit la liste dans l'App Group et demande le rechargement
   du widget à chaque modification). La ville **sélectionnée** dans l'app est
   mise en avant (halo orange + étiquette nom/heure locale) ; à défaut, la
   ville en tête de liste (principale).

### Une seule configuration Xcode à vérifier

Le partage de données passe par un **App Group** (`group.com.example.meteoheure`).
L'entitlement est déjà câblé dans le projet (`Shared/AppGroup.entitlements`,
`CODE_SIGN_ENTITLEMENTS` sur les deux cibles) :

1. Cible **MeteoHeure** → *Signing & Capabilities* → **+ Capability** →
   **App Groups** → cocher / ajouter `group.com.example.meteoheure`.
2. Cible **MeteoHeureWidget** → **+ Capability** → **App Groups** →
   même identifiant.
3. Simulateur : tout fonctionne directement, sans compte développeur.
   iPhone physique : sélectionnez votre **équipe** dans *Signing & Capabilities* ;
   la signature automatique enregistrera le groupe sur votre compte.

Sans cette étape, le widget fait office de démonstrateur : il affiche la carte
jour/nuit avec les villes témoins (Los Angeles, Paris) mais ne voit pas votre
liste personnalisée.

*Note : la carte est calculée depuis le masque terre/mer Natural Earth (domaine
public) embarqué dans `WorldMap.swift`. Pour le régénérer :
`python3 scripts/generate_worldmask.py ne_110m_land.geojson`.*

## 7. Notes techniques

- **Fuseau horaire** : chaque lieu stocke un identifiant IANA (`timezone=auto`
  fourni par l'API). Toutes les heures affichées — y compris lever/coucher et
  prévisions — sont les heures **locales du lieu**.
- **Cycle de vie** : l'horloge est coupée en arrière-plan ; la météo n'est
  re-téléchargée qu'en cas de donnée âgée (> 5 min au retour au premier plan,
  cache de 10 min par lieu).
- **Mode sombre / clair** : couleurs système + dégradés adaptatifs.
- **Unité** : métrique (°C, km/h, hPa).