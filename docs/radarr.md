# Configuration de Radarr par API

Remarque de M. Martini : la config par API doit recréer **tout l'état dont Radarr a
besoin**, pas seulement les paramètres de connexion. Comme les configs ne sont pas
sauvegardées (voir `sauvegarde-restauration.md`), si un élément manque après un
`deploy.yml` sur VM vierge, la chaîne ne marche plus.

## Ce que Radarr doit avoir pour que la chaîne marche

| Élément | Où (API) | Valeur | Sans ça |
|---|---|---|---|
| clé API connue | `config.xml` (template, avant le 1er démarrage) | `vault_radarr_api_key` | l'api Flixy et Prowlarr ne peuvent pas parler à Radarr |
| authentification | `config.xml` | Forms, compte depuis Vault | WebUI ouverte |
| dossier racine | `/api/v3/rootfolder` | `/data/flixy/films` | impossible d'ajouter un film |
| profil qualité | `/api/v3/qualityprofile` | `HD-1080p` (profil par défaut de Radarr, recréé s'il manque) | l'api ne peut pas ajouter le film (`qualityProfileId` obligatoire) |
| gestion des médias | `/api/v3/config/mediamanagement` | renommage, hardlinks, droits 2775, groupe 1000 | fichiers mal nommés ou illisibles par l'api |
| nommage | `/api/v3/config/naming` | `{Movie Title} ({Release Year})` | l'api ne retrouve pas le fichier |
| validation du certificat | `/api/v3/config/host` | `disabledForLocalAddresses` | le webhook HTTPS vers nginx (cert auto-signé) échoue |
| client de téléchargement | `/api/v3/downloadclient` | qBittorrent, hôte `qbittorrent:8080`, catégorie `radarr` | rien n'est téléchargé |
| catégorie qBittorrent | qBittorrent `/api/v2/torrents/categories` | `radarr` -> `/data/flixy/downloads/radarr` | Radarr ne retrouve pas ses téléchargements |
| indexeurs | Prowlarr `/api/v1/applications` + `/api/v1/indexer`, puis commande `ApplicationIndexerSync` | appli Radarr en `fullSync` | aucune recherche possible |
| webhook Connect | `/api/v3/notification` | `https://192.168.1.50/v1/radarr/webhook`, POST, secret Bearer, sur import / upgrade / suppression | le film est téléchargé mais n'arrive jamais dans le catalogue |

Les valeurs sont dans `roles/media_stack/defaults/main.yml`, les secrets dans Vault.

Téléchargements et films sont tous les deux sous `/data/flixy` (même système de fichiers,
monté au même chemin dans Radarr et qBittorrent) : l'import est un déplacement ou un
hardlink, pas une copie, et pas besoin de « remote path mapping ».

Les indexeurs ne sont pas mis directement dans Radarr : ils sont déclarés dans Prowlarr,
qui les pousse dans Radarr (synchro d'application). Le choix des indexeurs n'est pas
encore fait (`prowlarr_indexers`, à compléter), uniquement des indexeurs publics qui
proposent les films libres de `docs/medias.md`.

## Idempotence : GET avant POST/PUT

Pour chaque élément de la liste :

1. `GET` de la liste (ex. `GET /api/v3/downloadclient`)
2. recherche par nom (ou par chemin pour le dossier racine)
3. absent -> `POST`, `changed`
4. présent mais différent sur les champs gérés -> `PUT /<id>`, `changed`
5. présent et identique -> rien, `ok`

Les tâches `GET` sont en `changed_when: false`. Comme ça, le 2e passage de `deploy.yml`
donne bien `changed=0` (voir `tests/README.md`).

Pièges notés :
- Radarr teste le webhook quand on l'enregistre. Au 1er déploiement l'api n'existe pas
  encore, et pendant une restauration nginx renvoie 503 : le `POST` est fait avec
  `?forceSave=true` pour qu'il soit enregistré quand même
- l'API renvoie plus de champs que ce qu'on envoie : on ne compare que les champs gérés,
  sinon tout part en `PUT` à chaque passage
- les champs `fields` des providers (client, webhook) sont une liste `name/value`,
  il faut les comparer par nom
- les mots de passe ne reviennent pas dans le `GET` (masqués) : on ne les compare pas,
  et toutes ces tâches sont en `no_log: true`

## Contrôle final

À la fin du rôle `media_stack`, une tâche relit tout et vérifie :
- le dossier racine existe et est accessible
- le profil `HD-1080p` existe
- le client qBittorrent répond (`POST /api/v3/downloadclient/test`)
- au moins un indexeur synchronisé depuis Prowlarr
- le webhook est présent et actif

Le résultat va dans `tests/preuves/` avec les sorties de `deploy.yml`.
