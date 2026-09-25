# Règles générales du projet

Lire entièrement `PROJECT_PROFILE.md` s’il existe, puis cartographier la structure avant toute modification. Détecter la stack, le gestionnaire de paquets, les commandes et les conventions depuis les fichiers présents ; ne jamais supposer qu’un framework, un outil ou une commande existe.

## Principes de travail

- Préserver l’architecture, le design, les routes, les données et les fonctionnalités existantes. Ne supprimer une fonctionnalité qu’avec une justification explicite validée par la demande.
- Préférer des changements petits, ciblés, réversibles et vérifiables. Ne pas toucher aux fichiers sans rapport avec la tâche.
- Ne jamais exposer, copier, journaliser ou enregistrer un secret, un token ou une clé API. Utiliser uniquement les noms de variables dans les rapports.
- N’ajouter une dépendance de production qu’après avoir prouvé sa nécessité et vérifié l’absence d’alternative existante.
- Éviter les commandes destructrices et toute commande Git qui efface du travail non validé.
- Exécuter les tests, le lint, la vérification des types et le build lorsqu’ils existent et sont pertinents. Indiquer précisément toute vérification impossible.
- Utiliser des agents en lecture seule pour l’exploration et les audits. Ne pas faire modifier simultanément les mêmes fichiers par plusieurs agents.

## Choisir un agent ou une skill

Choisir un **agent** pour confier une responsabilité spécialisée ou obtenir un avis indépendant ; choisir une **skill** pour appliquer un workflow reproductible. Pour une demande complexe, le coordinateur consulte le profil, sélectionne le minimum d’agents et de skills utiles, puis délègue en parallèle uniquement les tâches indépendantes lorsque cela améliore réellement la qualité ou la rapidité. Une tâche simple reste confiée à un seul intervenant.

## Clôture obligatoire

Terminer par les fichiers modifiés, les vérifications réellement exécutées avec leurs résultats, les vérifications omises et les risques restants. Si des fichiers ont changé, proposer un titre de commit conventionnel et une courte description en français. Ne jamais présenter une hypothèse ou une vérification non exécutée comme un fait.
