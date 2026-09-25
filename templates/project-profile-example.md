# Profil du projet — exemple fictif

> Exemple générique. Aucun nom, domaine, service ou secret réel n’est utilisé.

## Identité

- **Nom du projet :** Example Portal
- **Objectif :** permettre à des utilisateurs authentifiés de consulter et gérer leurs demandes.
- **Utilisateurs visés :** clients et équipe support.
- **Statut :** développement.

## Technologies et commandes confirmées

- **Technologies :** framework web détecté dans le manifeste, API du même dépôt.
- **Gestionnaire de paquets :** à confirmer depuis le fichier de verrouillage du projet cible.
- **Installation :** à relever dans les scripts ou la documentation.
- **Développement :** à relever.
- **Lint :** à relever.
- **Types :** non détecté dans cet exemple.
- **Tests :** à relever.
- **Build :** à relever.

## Architecture

- **Organisation :** application, composants partagés, services et tests séparés.
- **Routes principales :** accueil public, connexion, tableau de bord, détail d’une demande.
- **Composants importants :** navigation, formulaire de demande, tableau de résultats.
- **Services :** client API centralisé avec gestion commune des erreurs.

## Interface

- **Design system :** composants et tokens internes.
- **Couleurs :** tokens sémantiques `surface`, `text`, `primary`, `danger`.
- **Typographies :** pile système.
- **Contraintes :** navigation clavier, états vides explicites, interface utilisable sur mobile.

## Produit et métier

- **Règle essentielle :** un client ne voit que ses propres demandes.
- **À ne jamais supprimer :** contrôle d’autorisation serveur sur le détail d’une demande.
- **Décision validée :** les erreurs utilisateur restent compréhensibles sans exposer de détail interne.
- **Problème connu :** la validation sur appareil réel reste à organiser.

## Intégrations et environnement

- **Services externes :** service de notification fictif côté serveur.
- **Variables requises :** `PUBLIC_API_URL`, `NOTIFICATION_SERVICE_TOKEN` ; noms uniquement.
- **Fichier d’exemple :** fichier d’environnement d’exemple sans valeur sensible.

## Hébergement

- **Plateforme :** non choisie dans cet exemple.
- **Domaine :** non défini.
- **Build et sortie :** à détecter avant configuration.

## Sécurité

- **Authentification :** session serveur avec rôles client et support.
- **Données sensibles :** coordonnées et contenu des demandes.
- **Contraintes :** validation serveur, autorisation par ressource, aucun secret côté client.

## Définition de terminé

- Critères d’acceptation vérifiés.
- Tests pertinents, lint et build réussis lorsqu’ils existent.
- Parcours principal contrôlé au clavier et sur les formats prioritaires.
- Documentation alignée et risques restants signalés.
