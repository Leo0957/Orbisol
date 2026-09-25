# Conception de la skill `legal-compliance-audit`

## Objectif et périmètre

Créer une skill générique d’audit technique et documentaire de préconformité juridique pour les sites et applications accessibles depuis la France ou l’Union européenne. Elle doit identifier les éléments présents, manquants, incomplets, contradictoires, potentiellement non conformes ou impossibles à vérifier depuis le code, sans fournir de validation juridique définitive.

La skill réalise uniquement un audit par défaut. Elle ne prépare ou ne modifie des pages légales que sur demande explicite, en conservant le design et les composants existants et en utilisant des placeholders pour toute information inconnue.

## Emplacement et intégration

Respecter l’emplacement réellement utilisé par le kit :

- créer `.agents/skills/legal-compliance-audit/SKILL.md` ;
- créer `.agents/skills/legal-compliance-audit/agents/openai.yaml` ;
- ajouter `legal-compliance-audit` à `SKILL_NAMES` dans `scripts/validate_kit.py` ;
- mettre à jour dans `README.md` le nombre de skills de 17 à 18 et mentionner l’audit juridique dans le résumé des domaines couverts.

Ne modifier aucun skill existant. Ne créer ni checklist, ni référence, ni modèle séparé : le contenu tient dans `SKILL.md` et cette structure reproduit les cinq skills de référence.

## Structure et rédaction de `SKILL.md`

Utiliser un frontmatter contenant uniquement `name` et `description`, avec une description française entre guillemets et un nom kebab-case identique au dossier. Reprendre exactement les neuf sections du kit :

1. `Objectif`
2. `Quand utiliser cette skill`
3. `Quand ne pas l’utiliser`
4. `Informations nécessaires`
5. `Étapes de travail`
6. `Vérifications obligatoires`
7. `Format du résultat`
8. `Règles de sécurité`
9. `Critères de réussite`

Employer des instructions concises à l’infinitif ou à l’impératif, fondées sur des preuves et adaptées à une utilisation sans framework imposé.

## Workflow d’audit

L’agent doit :

1. cartographier le projet et identifier le territoire, le statut de l’éditeur, le type de service et le modèle économique ;
2. relever les inconnues qui conditionnent les obligations ;
3. inspecter les pages légales, le footer, les formulaires, les comptes et les parcours de paiement ;
4. suivre les données à travers cookies, stockage local, API, authentification, bases, analytics et services tiers ;
5. comparer les textes affichés au comportement réel du code ;
6. contrôler l’éditeur, le RGPD, les traceurs, les CGU/CGV et le commerce électronique, les communications, les mineurs, la propriété intellectuelle, l’accessibilité et les obligations sectorielles ;
7. vérifier les règles importantes à partir de sources publiques officielles et actuelles lorsque l’accès Internet existe ;
8. classer et dédupliquer les constats, proposer des corrections concrètes et déclarer les limites.

La présence d’un traceur nécessitant un consentement doit être démontrée avant de recommander une bannière. Une réglementation sectorielle ne doit être appliquée qu’après confirmation de son champ d’application.

## Sources et gestion des incertitudes

Privilégier la CNIL, Légifrance, Service-Public.fr, la DGCCRF, la Commission européenne, EUR-Lex et les autorités publiques compétentes. Pour chaque règle importante, consigner l’autorité ou le texte, le lien officiel et la date de vérification. Ne pas utiliser un blog ou un contenu commercial comme source juridique principale.

Sans Internet, marquer les règles comme devant être revérifiées dans les textes officiels actuels. Toute donnée d’entreprise inconnue doit rester inconnue et utiliser un placeholder explicite. Les obligations dépendant du statut, du territoire ou du fonctionnement réel doivent recevoir l’état `À vérifier` ou `Non applicable`, avec justification.

## Contrat de sortie

Commencer par un résumé indiquant le type de projet, le territoire supposé, le niveau global de préconformité, le décompte des problèmes et les informations manquantes. Produire ensuite le tableau demandé avec les colonnes : priorité, catégorie, élément contrôlé, état actuel, problème, risque, correction, fichiers et source officielle.

Ajouter les sections suivantes dans cet ordre :

- éléments correctement présents ;
- obligations probablement manquantes ;
- informations à fournir par le propriétaire ;
- différences entre textes et fonctionnement réel ;
- plan de correction priorisé ;
- sources officielles consultées ;
- limites de l’audit.

Classer chaque constat en `Critique`, `Élevé`, `Moyen`, `Faible`, `À vérifier` ou `Non applicable`, puis le qualifier comme obligation légale probable, bonne pratique, élément contractuel, validation humaine ou élément non applicable.

## Garde-fous

Ne jamais se présenter comme avocat, garantir une conformité complète, inventer une règle ou une information d’entreprise, masquer une incertitude, affirmer qu’un contenu est libre de droits sans preuve, appliquer automatiquement une loi étrangère ou modifier une donnée sensible. Employer les formulations de prudence demandées et distinguer systématiquement analyse statique, comportement observé et vérification humaine restante.

## Validation

Avant l’écriture, exécuter des scénarios de référence sans la nouvelle skill afin d’observer les omissions réelles. Après l’écriture, rejouer les mêmes scénarios avec la skill et vérifier le respect du format, des sources, des placeholders, des états et des limites.

Exécuter ensuite :

- le validateur `python3 scripts/validate_kit.py` ;
- le validateur structurel fourni par `skill-creator` s’il est exécutable sans ajout de dépendance ;
- une recherche des promesses de conformité certaine et des marqueurs inachevés ;
- un inventaire avant/après et les empreintes des cinq skills de référence afin de prouver leur absence de modification.

Le kit n’étant pas un dépôt Git, consigner cette limite et ne revendiquer aucun commit.
