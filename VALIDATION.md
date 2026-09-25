# Validation du kit et des tâches

## Contrôle du kit

Depuis la racine où le kit est installé :

```sh
python3 scripts/validate_kit.py
```

Un résultat valide exige un code de sortie nul et aucune ligne marquée comme erreur. Le script contrôle la structure et des garde-fous statiques ; il ne confirme ni le chargement effectif par Codex ni la pertinence métier des workflows.

Après copie dans un projet :

1. créer et renseigner `PROJECT_PROFILE.md` ;
2. ouvrir une nouvelle tâche Codex à la racine ;
3. demander la liste des agents et skills locales ;
4. faire exécuter `$project-discovery` en lecture seule ;
5. comparer son rapport au dépôt réel ;
6. tester une skill ciblée sur une branche ou un environnement non critique.

## Contrôle d’une modification web

Détecter d’abord les commandes dans les manifestes et la documentation. Exécuter uniquement celles qui existent et sont adaptées à la tâche.

| Contrôle | Attendu | Si impossible |
|---|---|---|
| Diff ciblé | aucun fichier hors périmètre | expliquer chaque exception |
| Tests | tests pertinents réussis | donner la commande et le blocage |
| Lint | aucune nouvelle erreur | distinguer dette antérieure et régression |
| Types | aucune nouvelle erreur | localiser les erreurs restantes |
| Build | sortie produite avec succès | joindre l’étape et le message utile |
| Fonctionnel | critères d’acceptation vérifiés | lister les scénarios manuels requis |
| Responsive | formats concernés contrôlés | indiquer les formats non testés |
| Accessibilité | clavier, labels et sémantique essentiels | préciser les tests humains restants |
| Sécurité | entrées, accès et secrets examinés | séparer risque potentiel et faille confirmée |
| Déploiement | configuration réelle cohérente | ne pas déclarer la production validée |

## Règle de preuve

Ne jamais transformer une lecture de code en preuve d’exécution. Qualifier le résultat : **réussi**, **échoué**, **non exécuté**, **à vérifier manuellement** ou **non applicable**. Conserver dans le rapport les commandes, le contexte utile et les limites, sans valeur secrète.
