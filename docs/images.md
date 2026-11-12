# Images utilisées

Toutes les images sont figées dans `inventory/group_vars/all/main.yml`, jamais de `latest`.

## Vérification de disponibilité

Vérifié le 24/10/2026 depuis une machine sans Docker, en interrogeant directement l'API
des registres (requête `HEAD /v2/<image>/manifests/<tag>`). Le digest est celui de
l'index multi-arch renvoyé par le registre.

| Rôle | Image | Tag | Dispo | Digest (index) |
|---|---|---|---|---|
| postgres | `postgres` (Docker Hub) | `18.6-alpine` | oui | `sha256:898c60cb390d1085bc97bdd6a1ae968757421df394b071848b52b1c09c89d6a5` |
| valkey | `valkey/valkey` | `9.1.2-alpine` | oui | `sha256:48332870af354a799964c0012ae1194a0bf2bf894eb508f945810596dc2d8d11` |
| minio | `pgsty/minio` | `RELEASE.2026-08-04T00-00-00Z` | oui | `sha256:b6bfe7239bfc83fb90d31612d9704d86039dd714f7904b3f1ad68f211e602372` |
| mc (client MinIO) | `pgsty/mc` | `RELEASE.2026-08-04T00-00-00Z` | oui | `sha256:b57234d21057175b6c3358509733128e35da330094aaacf37bf33348b11d1f92` |
| nginx | `nginx` (Docker Hub) | `1.30.6-alpine` | oui | `sha256:47928bf67eb62a1863cb08d9ecb52d3e704304ba614eaee17884204677702951` |
| radarr | `lscr.io/linuxserver/radarr` | `6.4.4` | oui | `sha256:fc0ae3c50f8128b97e84381903ec8d6845c3a569641cb7117c124376cccb57c1` |
| prowlarr | `lscr.io/linuxserver/prowlarr` | `2.6.5` | oui | `sha256:b3b00047ed20f6ce2b16780145cb6a0acb51c9e28ea6aa6f5dcd33c7034f1797` |
| qbittorrent | `lscr.io/linuxserver/qbittorrent` | `5.2.4` | oui | `sha256:1ea873647c43d566f251a7122aee330b184509c57ee3257ed19f62dac0f8f24b` |
| web | `flixy-sae/web` (construite sur vm-app) | `sae-1.0` | construite au déploiement | voir plus bas |
| api | `flixy-sae/api` (construite sur vm-app) | `sae-1.0` | construite au déploiement | voir plus bas |
| migrator | `flixy-sae/migrator` (construite sur vm-app) | `sae-1.0` | construite au déploiement | voir plus bas |

Remarques :
- les images lscr.io renvoient le même digest que ghcr.io/linuxserver (lscr.io redirige
  vers ghcr.io)
- l'index de `pgsty/minio` contient bien une variante `linux/amd64` (les VM sont en amd64)
- `pgsty/mc` est ajouté pour la sauvegarde : même date de release que le serveur MinIO
- les images Flixy ne viennent pas du registre GitLab de Flixy : elles sont construites
  pour la SAÉ (voir plus bas), donc pas de jeton de registre

Si une image disparaît ou change, on peut passer au digest dans `main.yml`
(`image@sha256:...`) pour être sûr de tirer exactement la même.

### Commandes pour revérifier

Sur une machine avec Docker :

```bash
docker manifest inspect postgres:18.6-alpine > /dev/null && echo ok
docker buildx imagetools inspect lscr.io/linuxserver/radarr:6.4.4 | head -3
```

Ou avec skopeo (pas besoin du démon Docker) :

```bash
skopeo inspect --raw docker://pgsty/minio:RELEASE.2026-08-04T00-00-00Z | sha256sum
```

La sortie de cette vérification, refaite avant la démo, va dans `tests/preuves/images.txt`.

## Images Flixy et références du code

La copie SAÉ ne doit avoir **aucun impact** sur la Flixy en service : rien n'est écrit sur
le GitLab de Flixy (pas de tag, pas de branche, pas de changement de CI, pas de push sur le
registre), et aucun service, secret ou base de la production n'est utilisé.

Les images web, api et migrator sont donc construites par Ansible (rôle `flixy_app`,
`tasks/images.yml`) :

1. sur le nœud de contrôle, clone **en lecture seule** des dépôts au commit fixé dans
   `flixy_src` (`inventory/group_vars/all/main.yml`), dans `.src/` (ignoré par git)
2. `git archive` du commit, copie sur vm-app, extraction dans `/opt/flixy/build/`
3. `docker build` sur vm-app avec les Dockerfile du projet, tag local `flixy-sae/<image>:sae-1.0`,
   label `org.opencontainers.image.revision=<commit>`
4. au passage suivant, l'image n'est reconstruite que si elle manque ou si le label ne
   correspond plus au commit (idempotence)

Les images restent locales à vm-app (`pull_policy: never` dans le compose).

| Image | Dépôt (lecture seule) | Commit (SHA complet) | Dockerfile | Id de l'image |
|---|---|---|---|---|
| flixy-sae/web:sae-1.0 | kineflix/front-end (branche leo-p, MR !16) | feb36a6a530bd08108c94ca4b69b1aea1db65864 | `Dockerfile`, `APP_NAME=web` | à compléter après le 1er build |
| flixy-sae/api:sae-1.0 | kineflix/back-end (branche leo-p) | 44e371bb29f15637114ce78cac4e7aa0da9c1b55 | `Dockerfile`, `APP=api` | à compléter après le 1er build |
| flixy-sae/migrator:sae-1.0 | kineflix/back-end (branche leo-p) | 44e371bb29f15637114ce78cac4e7aa0da9c1b55 | `migrator/Dockerfile` | à compléter après le 1er build |

L'id (`sha256:...`) de chaque image est affiché par la tâche « Id des images » du
déploiement, et recopié dans le `manifest.json` de chaque sauvegarde. Une image locale
n'a pas de digest de registre : c'est l'id de l'image qui sert de référence.

Pour revérifier sur vm-app :

```bash
docker image inspect -f '{{.Id}} {{index .Config.Labels "org.opencontainers.image.revision"}}' flixy-sae/api:sae-1.0
```

## Contraintes sur le code

- La route `GET /v1/health` existe seulement à partir du commit `7a2b854` de la branche `leo-p`
  de l'api (elle n'est pas dans `v1.1.1`). L'api doit donc être construite depuis ce commit ou
  un commit plus récent, sinon le healthcheck de l'image et le contrôle de restauration échouent.
- Le worker BullMQ tourne dans le conteneur `api` (il n'y a qu'une app, `apps/api`). Il s'arrête
  en même temps que l'api pendant une sauvegarde ou une restauration.
- L'api exige des variables Google, Apple, Sonarr et Cloudflare au démarrage : valeurs
  factices dans le vault de la SAÉ (fonctions non utilisées dans la démo). Turnstile utilise
  les clés de test officielles de Cloudflare.
- Le clone en lecture seule demande que le nœud de contrôle ait accès en lecture aux dépôts
  (compte de Léo).
