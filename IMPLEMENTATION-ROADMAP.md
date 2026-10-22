# Orbisol : implementation et verification

## Extension du 22 octobre 2026

Les nouvelles fonctions iPhone relient maintenant la météo du quotidien (activité, historique modélisé, courbe de pluie prévue, alertes air/pollens), la coordination internationale (horaires par ville, rendez-vous hebdomadaire, lien partageable, rappel local de changement de décalage), les voyages (étapes datées, import d'un événement Calendrier choisi, liste de préparation, résumé du départ), les widgets (pluie, plusieurs villes, changement de ville), et les préférences (profils d'alertes, accueil, lisibilité). L'état et l'heure de dernière actualisation météo sont visibles pour chaque ville. Une tâche iOS de rafraîchissement en arrière-plan traite au plus quatre villes prioritaires ; iOS décide si et quand elle s'exécute.

Le site présente ces fonctions comme du code existant, indique que l'application n'est pas encore publiée et distingue les concepts visuels des captures d'application. Le faux QR code et le formulaire d'inscription provisoire ont été retirés. L'Apple Watch reste hors du périmètre.

Le radar RainViewer reste une lecture d'observations. Sa fonction de trames futures ayant été arrêtée, la projection est une courbe de précipitations issue des prévisions Open-Meteo, présentée séparément de l'imagerie radar. Les horaires solaires et suggestions de voyage dépendent des données disponibles.

Vérification : compilation Debug pour simulateur de l'app et des widgets, 11 groupes d'assertions Swift, build statique du site, contrôle des 10 pages HTML et de leurs références locales, affichage de `telecharger.html` dans Safari. La suite Playwright n'a pas pu démarrer car `playwright` n'est pas installé ; le simulateur iOS ne peut pas être lancé car CoreSimulator est plus ancien que la version attendue par Xcode. Les widgets, notifications, autorisations Calendrier et réveils iOS doivent encore être exercés sur iPhone.

## Deuxieme serie d'ajouts : usages quotidiens

| Ajout | Emplacement et comportement |
| --- | --- |
| Favoris | Appui long sur une ville > Epingler ; favoris en tete, ordre relatif conserve |
| Ville au demarrage | Apparence & horloge ; ville explicite ou derniere ville consultee. Le mecanisme de ville principale existait deja |
| Recherche locale | Horloges ; recherche dans nom, pays et groupe des villes deja suivies |
| Mode nuit | Grand format ; plein ecran sombre, luminosite reglable, commandes masquees apres 5 s et revelees au toucher. Option automatique de 22 h a 8 h, heure du telephone. Luminosite restauree a la fermeture ou en quittant l'app |
| Partage de creneau | Comparateur > Partager ; texte avec date, heure et fuseau pour chaque ville, duree d'une heure |
| Calendrier | Comparateur > Calendrier ; editeur Apple pre-rempli, enregistrement ou annulation par l'utilisateur |
| Alertes de froid | Centre des alertes ; seuil de -30 a +15 degres Celsius, silencieux et exclusions de villes respectes |
| Sections meteo | Reglages > Sections meteo ; visibilite et ordre des cinq sections supplementaires |
| Duree du jour | Lumiere du jour ; difference estimee en minutes par rapport a hier |
| Voyages dates | Organiser ou Reglages > Voyages dates ; groupe, depart, retour, selection d'une date/heure du sejour et previsions disponibles |
| Meteo comparee | Comparateur et detail du voyage ; temperatures min/max horaires, pluie et vent maximaux pour la meme date civile dans chaque ville |
| Sauvegarde | Reglages > Sauvegarde ; export JSON, validation de version/taille/contenu, confirmation avant import. Ajout des villes absentes, conservation des villes existantes, application des preferences importees |
| Radar | Meteo > Radar de pluie ; carte Apple et observations RainViewer, lecture/pause, curseur et actualisation. Echelle regionale fixe, deplacement possible |

Le radar utilise l'API publique RainViewer pour l'usage personnel du projet.
Ses conditions doivent etre revalidees pour une exploitation commerciale :
https://www.rainviewer.com/api.html. Les donnees exploitees sont les images
observees des deux dernieres heures, pas des previsions radar.

Verification de cette serie : compilation application/widget reussie,
dix groupes d'assertions Swift reussis (dont migration des preferences froid,
saisonnalite solaire, sauvegarde, validation et date locale du partage).
RainViewer a retourne 13 images ; fond de carte et precipitations observes dans
le simulateur. Comparateur et personnalisation meteo inspectes par captures.
Les dialogues natifs de partage/calendrier/Fichiers, le geste de reorganisation,
le cycle complet du mode nuit et la reception d'une alerte froide restent a
essayer en interaction sur appareil. Aucun rendez-vous ni message n'a ete envoye.

Les fichiers de cette serie sont principalement `ProductPlanning.swift`,
`ProductFeatures.swift` et `RadarView.swift`, avec raccordements aux vues existantes.

Etat au 16 octobre 2026. Les modifications preexistantes (identite, polices,
globe, site web) ont ete conservees. La navigation reste a quatre onglets,
avec la barre Liquid Glass native sur iOS 26 et ulterieur.

## Fonctionnalites raccordees

| Categorie | Ajouts | Acces / limites |
| --- | --- | --- |
| Meteo | Resume par periode, comparaison avec hier, creneau de sortie de deux heures | Sous le globe ; calculs bases sur les previsions disponibles |
| Meteo | Precipitations par pas de 15 minutes et pollens | Donnees Open-Meteo ; couverture variable, valeurs absentes explicites |
| Meteo | Bouton de previsions et detail horaire d'une journee | Bouton en haut de Meteo, puis selection d'un jour |
| Temps | Comparateur, date et curseur temporel, decalages et changements de jour | Horloges > Comparer ou Reglages > Comparer les heures |
| Voyages | Groupes de villes, selection des villes comparees, creneaux communs | Horloges > Organiser ; plage commune de 9 h a 19 h |
| Soleil | Globe eclaire a la date comparee, heures dorees et bleues | Approximation solaire ; relief et nuages non pris en compte |
| Apparence | Theme systeme/clair/sombre, grand format paysage, options secondes/date/meteo | Reglages > Apparence & horloge |
| Villes | Reorganisation, groupes, annulation de suppression | Confirmation pour supprimer toutes les villes |
| Accessibilite | Libelles combines, controles natifs, textes adaptatifs dans les nouveaux ecrans | Audit VoiceOver et tailles extremes restant a faire |
| Alertes | Centre, autorisation reelle, liste programmee, villes, silence nocturne, pluie/vent/chaleur | Notifications locales reprogrammees aux actualisations ; pas de surveillance serveur ni d'alertes officielles |
| Widgets | Meteo + heure, formats ecran verrouille, ville configurable pour chaque widget | Nouveaux widgets iOS 17+ ; meteo issue du dernier chargement de l'app, anciennete signalee |
| Raccourcis | Ouvrir la meteo d'une ville, obtenir son heure | App Intents ; validation dans l'app Raccourcis restant a faire |
| Fiabilite | Cache JSON atomique, lecture au demarrage, air/meteo independants, valeurs horaires nulles acceptees | Echec air sans suppression de la meteo ; heures incompletes ignorees sans inventer de valeur |
| iCloud | Etat de disponibilite et de reception plus honnete | Ne pretend pas confirmer l'envoi ; synchronisation inter-appareils non verifiee |

## Verifications effectuees

- Compilation Debug simulateur de l'application et de l'extension : reussie.
- Installation et lancement dans le simulateur iPhone 17, iOS 27.0 : reussis.
- Reponse Open-Meteo reelle : HTTP 200, decodage verifie avec les modeles Swift.
- Le test reel a detecte des valeurs nulles en fin de prevision ; correction
  appliquee, regression couverte par une fixture integree aux tests.
- Huit groupes de tests Swift autonomes : fuseaux fractionnaires, changement
  de date/heure d'ete, heures silencieuses, creneaux communs, choix de sortie,
  comparaison hier, cache absent/corrompu, tableaux tronques/nulls, calcul solaire.
- Quatre fichiers de cache non vides observes dans le conteneur du simulateur.
- Captures inspectees : horloges, meteo reelle, comparateur, centre d'alertes
  sombre. Correction du logo sombre et acces previsions remonte.
- `git diff --check` : reussi.

## Reproduire les tests

Depuis la racine du projet :

```sh
sh Tests/run-planning-tests.sh
# Optionnel : verifier aussi une reponse API deja enregistree.
sh Tests/run-planning-tests.sh /chemin/vers/reponse-meteo.json
```

Ces tests sont des assertions Swift, pas une suite XCTest/UI automatisee.

## Validation restante sur appareil

- Installation et configuration des widgets, y compris plusieurs villes et
  l'ecran verrouille ; regles de rafraichissement imposees par iOS.
- Execution des deux actions Raccourcis, ouverture par un widget.
- Reception effective des notifications et reprogrammation lors de changements.
- iCloud entre deux appareils connectes au meme compte.
- Parcours tactile complet, paysage, Dynamic Type extreme, VoiceOver,
  contraste et reduction des animations.
- Demarrage sans reseau et usage prolonge hors connexion sur appareil.

Les captures ne remplacent pas ces essais. La presence des fichiers de cache
et leurs tests de lecture/ecriture ne constituent pas un test complet en mode avion.
