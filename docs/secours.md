# Scénario de secours : démo import + webhook

Ce n'est **pas** le test de la recherche et du téléchargement. Ce sont deux démos
séparées, présentées comme telles à la soutenance :

| | Démo A : recherche et téléchargement | Démo B : import + webhook (secours) |
|---|---|---|
| Ce qui est montré | demande sur le site -> Radarr -> Prowlarr -> qBittorrent -> import -> webhook -> catalogue | fichier déposé à la main -> import Radarr -> webhook -> catalogue |
| Dépend de l'extérieur | oui (indexeurs, pairs, réseau de la salle) | non, tout est local |
| Ce que ça prouve | la recherche automatique | le rangement des fichiers, le webhook sécurisé et l'ajout au catalogue |
| Ce que ça ne prouve pas | - | la recherche et le téléchargement |

Si la démo A ne marche pas le jour J, je le dis et je passe à la démo B. Je ne fais pas
passer B pour A.

## Préparation

- fichier de démo : Sintel ou Big Buck Bunny (CC BY 3.0, voir `docs/medias.md`), ou la
  vidéo de test générée avec ffmpeg
- copié à l'avance sur vm-media, hors du dossier d'import :
  `/data/flixy/demo/Sintel (2010)/Sintel (2010).mp4`, uid/gid 1000
- le film ne doit **pas** déjà être dans la bibliothèque Radarr ni dans le catalogue
  (sinon on ne voit rien se passer)

## Déroulé

1. Sur le site Flixy, je demande le film (« Sintel »). L'api l'ajoute dans Radarr.
   Sans cette demande, l'api ne connaît pas le film et le webhook ne l'ajoute pas.
2. Je montre le film en « manquant » dans Radarr (tunnel SSH ou capture).
3. Je copie le fichier dans le dossier d'import (sur vm-media) :

   ```bash
   cp -a "/data/flixy/demo/Sintel (2010)" /data/flixy/import/
   ```

4. Je lance l'import dans Radarr par son API, depuis vm-app (seule IP autorisée sur le
   7878) :

   ```bash
   curl -s -X POST "http://192.168.1.55:7878/api/v3/command" \
     -H "X-Api-Key: $RADARR_API_KEY" -H "Content-Type: application/json" \
     -d '{"name": "DownloadedMoviesScan", "path": "/data/flixy/import/Sintel (2010)", "importMode": "Move"}'
   ```

   (`RADARR_API_KEY` est lu depuis Vault au moment de la démo, jamais écrit en clair
   dans un fichier ou dans l'historique.)

5. Radarr range le fichier dans `/data/flixy/films/Sintel (2010)/` et appelle le webhook.
6. Je montre la ligne du webhook dans les logs nginx (requête venant de 192.168.1.55,
   réponse 2xx) et dans les logs de l'api.
7. Le film apparaît dans le catalogue et se lit sur le site.

## Test à l'avance

À faire au moins une fois avant la soutenance, sur les VM déployées par Ansible (pas
sur la prod), puis encore la veille :

- [ ] dérouler les étapes 1 à 7
- [ ] vérifier que le fichier final est en uid/gid 1000 et lisible par l'api via NFS
- [ ] vérifier que l'appel du webhook avec un mauvais secret est refusé (401) et qu'il
      est bloqué (403) depuis une autre IP que 192.168.1.55
- [ ] remettre l'état de départ : supprimer le film dans Radarr (avec le fichier) et
      dans le catalogue, pour que la démo soit rejouable
- [ ] chronométrer (objectif : moins de 3 min)

Les sorties (commande curl, réponse de Radarr, extraits de logs nginx et api, date du
test) vont dans `tests/preuves/secours/`, sans la clé API. Voir `tests/preuves/README.md`.

## Résultat du test du 12/11/2026 (copie SAE, VM 104/105)

Script : `tests/demo/demo-secours.sh` (clé API lue par l'entrée standard).
Preuve : `tests/preuves/secours/demo-b-sintel.txt`.

- Sintel (CC BY 3.0, TMDB 45745) ajouté dans Radarr, fichier 1080p (md5 vérifié avec
  celui de download.blender.org) copié dans `import/`, import `DownloadedMoviesScan` :
  Radarr range `/data/flixy/films/Sintel (2010)/Sintel (2010) WEBDL-1080p.mkv` (uid/gid
  1000, visible depuis vm-app via NFS) ;
- le webhook part tout seul : nginx `POST /v1/radarr/webhook 201` depuis 192.168.1.55,
  l'api reçoit `Download`, relit le film dans Radarr ;
- l'api l'ignore (`ignored: not requested`) : dans ce test personne n'avait demandé le
  film depuis le site (étape 1 sautée).

Limite connue : pour aller jusqu'au catalogue, l'api va chercher la fiche du film sur
TMDB (`putMovie` → `resolveMovie`). Il faut donc une **vraie clé TMDB** (compte
personnel gratuit, pas celle de la prod) dans `vault_tmdb_api_key`, et un compte
utilisateur sur la copie pour faire la demande. Avec la clé factice, la chaîne marche
jusqu'au webhook compris.

Remettre l'état de départ : supprimer Sintel dans Radarr avec ses fichiers
(`DELETE /api/v3/movie/1?deleteFiles=true`), le fichier de démo reste dans `demo/`.
