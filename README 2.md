# Codex Web Agent Kit

Kit générique pour analyser, développer, auditer, corriger et maintenir un projet web sans imposer de framework. Il combine des règles communes, 11 agents spécialisés, 18 workflows réutilisables, des modèles de rapports et un validateur autonome.

## Comprendre les trois niveaux

| Élément | Rôle | Exemple |
|---|---|---|
| `AGENTS.md` | Règles stables applicables à toute tâche du dépôt | préserver l’existant, vérifier avant de supposer |
| Agent | Responsable spécialisé avec un périmètre et un mode de travail | `codebase_explorer` cartographie sans écrire |
| Skill | Procédure réutilisable déclenchée pour un type de travail | `bug-investigation` guide un diagnostic complet |

Un agent décide et prend en charge une responsabilité. Une skill lui fournit un workflow. Les deux peuvent être combinés, mais le kit reste utilisable avec un seul agent ou une seule skill.

## Installation dans un projet

1. Sauvegarder ou versionner le projet cible.
2. Copier **le contenu** de `codex-web-agent-kit/` à la racine du projet, y compris `.codex/` et `.agents/`.
3. Si le projet possède déjà un `AGENTS.md` ou une configuration Codex, fusionner les règles au lieu d’écraser les fichiers.
4. Copier `PROJECT_PROFILE.template.md` vers `PROJECT_PROFILE.md`, puis remplacer les exemples par les informations vérifiées du projet.
5. Depuis la racine du projet, exécuter `python3 scripts/validate_kit.py` si Python est disponible.
6. Ouvrir une nouvelle tâche Codex depuis cette racine afin que la configuration soit relue.

Exemple de copie vers un projet vide de configuration Codex :

```sh
cp -R path/to/codex-web-agent-kit/. path/to/project/
cd path/to/project
cp PROJECT_PROFILE.template.md PROJECT_PROFILE.md
python3 scripts/validate_kit.py
```

La première commande peut remplacer des fichiers de même nom : dans un projet déjà configuré, préférer une copie sélective et une fusion manuelle.

## Profil du projet

`PROJECT_PROFILE.md` devient la source de contexte locale : objectif, stack détectée, commandes confirmées, architecture, règles métier, design, services, sécurité et définition de terminé. Ne pas y enregistrer de valeur secrète ; noter uniquement les noms de variables d’environnement. Mettre le profil à jour après une décision stable, pas après chaque expérimentation.

Le fichier `templates/project-profile-example.md` illustre un profil rempli avec un projet fictif et générique.

## Vérifier la détection

Après redémarrage de la tâche Codex :

- demander : « Liste les agents personnalisés disponibles dans ce projet et résume leur périmètre. » ;
- demander : « Liste les skills locales détectées sous `.agents/skills/`. » ;
- appeler explicitement un agent : « Utilise `codebase_explorer` pour cartographier le projet sans rien modifier. » ;
- appeler explicitement une skill : « Utilise `$project-discovery` pour établir le profil technique. »

La syntaxe exacte d’affichage peut varier selon la version de Codex. L’existence des fichiers ne prouve pas à elle seule leur chargement : confirmer la détection dans une nouvelle tâche et faire exécuter une action minimale en lecture seule.

## Utiliser plusieurs agents

Le coordinateur découpe une demande complexe, attribue des périmètres indépendants et attend les rapports avant de décider des changements. Demander explicitement le parallélisme si souhaité, tout en interdisant les écritures concurrentes sur les mêmes fichiers.

Exemples de demandes :

```text
Analyse entièrement ce projet avec les agents spécialisés appropriés.

Utilise codebase_explorer pour cartographier le projet, puis prépare un plan d’implémentation.

Fais auditer cette branche par security_auditor, qa_tester et performance_auditor. Attends leurs rapports avant de proposer des corrections.

Utilise la skill pre-release-check et corrige uniquement les problèmes bloquants.

Analyse ce bug, trouve sa cause racine, applique la plus petite correction possible et ajoute un test de non-régression.
```

## Agents inclus

| Agent | Usage principal |
|---|---|
| `coordinator` | orchestration des demandes complexes |
| `codebase_explorer` | cartographie en lecture seule |
| `frontend_developer` | interface, état client et responsive |
| `backend_developer` | API, données, authentification et validation |
| `ui_ux_auditor` | parcours et cohérence visuelle |
| `qa_tester` | scénarios, tests et régressions |
| `security_auditor` | audit défensif de sécurité |
| `seo_accessibility_auditor` | SEO technique et accessibilité |
| `performance_auditor` | chargement, rendu, réseau et bundle |
| `deployment_specialist` | build et configuration d’hébergement |
| `documentation_maintainer` | documentation alignée sur le réel |

## Skills incluses

Les skills couvrent la découverte, l’audit complet, l’implémentation, les bugs, l’UI/UX, le responsive, l’accessibilité, le SEO, la performance, la sécurité, la préconformité juridique, les tests, la refactorisation, les dépendances, la documentation, la prépublication, le déploiement et la préparation de commit. Chaque description indique quand l’utiliser et quand choisir un workflow plus ciblé.

Chaque dossier de skill contient aussi `agents/openai.yaml`, une métadonnée d’interface générée pour rendre son nom, son résumé et son exemple d’appel lisibles dans les surfaces Codex compatibles. Le workflow lui-même reste défini dans `SKILL.md` et ne dépend d’aucun outil externe.

## Adapter le kit

- Renseigner `PROJECT_PROFILE.md` avec des faits issus du dépôt.
- Ajouter les règles stables propres au projet dans son `PROJECT_PROFILE.md` ou dans une documentation dédiée.
- Garder `AGENTS.md` court : y placer seulement les garde-fous communs à toutes les tâches.
- Mettre les procédures longues dans une skill et les détails spécifiques à une plateforme dans `references/`.
- Conserver les noms techniques en anglais et les instructions en français pour rester cohérent avec le kit.

### Ajouter une skill

Créer `.agents/skills/<skill-name>/SKILL.md`. Utiliser un nom en minuscules avec des tirets, un frontmatter contenant uniquement `name` et `description`, puis les neuf sections de workflow utilisées par ce kit. Ajouter une référence ou un script seulement si elle évite une duplication réelle. Relancer le validateur et tester la skill sur une demande réaliste.

### Ajouter un agent

Créer `.codex/agents/<agent-name>.toml` avec `name` en `snake_case`, `description` précise et `developer_instructions` complètes. Définir `sandbox_mode = "read-only"` pour un rôle d’exploration ou d’audit. Ne pas imposer de modèle et éviter de recouvrir le périmètre d’un agent existant. Relancer le validateur, puis vérifier la détection dans une nouvelle tâche.

## Validation et maintenance

`VALIDATION.md` décrit les contrôles attendus. `scripts/validate_kit.py` vérifie la structure, le TOML, les agents, le frontmatter, les doublons, les fichiers vides, les chemins absolus évidents et les secrets manifestes. Ce contrôle structurel ne remplace pas un essai réel dans le projet cible.
