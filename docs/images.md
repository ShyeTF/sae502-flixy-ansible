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
| web | `registry.gitlab.com/kineflix/front-end/web` | `sae-1.0` | non, pas encore construit | à compléter |
| api | `registry.gitlab.com/kineflix/back-end/api` | `sae-1.0` | non, pas encore construit | à compléter |
| migrator | `registry.gitlab.com/kineflix/back-end/migrator` | `sae-1.0` | non, pas encore construit | à compléter |

Remarques :
- les images lscr.io renvoient le même digest que ghcr.io/linuxserver (lscr.io redirige
  vers ghcr.io)
- l'index de `pgsty/minio` contient bien une variante `linux/amd64` (les VM sont en amd64)
- `pgsty/mc` est ajouté pour la sauvegarde : même date de release que le serveur MinIO
- le registre GitLab de kineflix est privé (réponse 401 sans jeton), il faudra un
  deploy token en lecture seule dans Vault pour le `docker login` sur vm-app

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

web, api et migrator sont construites par la CI GitLab de Flixy. Pour la SAÉ je pousse un
tag fixe `sae-1.0` (variable `flixy_image_tag`) au lieu du `latest` de la prod.

Une fois le tag construit, je remplis ce tableau et la variable `flixy_code_refs` dans
`main.yml` (elle est recopiée dans le `manifest.json` de chaque sauvegarde) :

| Image | Dépôt GitLab | Commit (SHA complet) | Pipeline CI | Digest de l'image |
|---|---|---|---|---|
| web:sae-1.0 | kineflix/front-end (branche leo-p) | feb36a6a530bd08108c94ca4b69b1aea1db65864 (prévu) | à compléter | à compléter |
| api:sae-1.0 | kineflix/back-end (branche leo-p, `Dockerfile`) | 44e371bb29f15637114ce78cac4e7aa0da9c1b55 (prévu) | à compléter | à compléter |
| migrator:sae-1.0 | kineflix/back-end (branche leo-p, `migrator/Dockerfile`) | 44e371bb29f15637114ce78cac4e7aa0da9c1b55 (prévu) | à compléter | à compléter |

Les commits « prévus » sont ceux de la branche `leo-p` au 30/10. Celui du back-end contient la route
`/v1/health` (7a2b854) et la migration 0014. api et migrator viennent du même commit, car les migrations
sont dans `libs/database/src/migrations`. Le front vient de `leo-p` (MR !16), pas de `main`.

Aujourd'hui, la CI du back-end ne construit d'images que depuis `main` (tags `latest` + id du job)
ou depuis un tag git `v*` (tags `v…` + `prod`). Pour avoir `sae-1.0` sans toucher à `latest` ni à `prod`,
il faut ajouter à la CI un job déclenché sur un tag git `sae-*`. Pour tirer les images depuis
les VM, il faut un deploy token GitLab en scope `read_registry` (dans le vault, jamais en clair).

Pour récupérer les infos :

```bash
# dans chaque depot, sur le commit tagge
git rev-parse sae-1.0

# digest de l'image poussee (apres docker login sur le registre GitLab)
docker buildx imagetools inspect registry.gitlab.com/kineflix/back-end/api:sae-1.0
```

## Contraintes sur le code

- La route `GET /v1/health` existe seulement à partir du commit `7a2b854` de la branche `leo-p` de l'api. Le tag `sae-1.0` de l'api doit donc être construit depuis ce commit ou un commit plus récent, sinon le contrôle de santé du déploiement renvoie 404.
- Le worker BullMQ tourne dans le conteneur `api` (il n'y a qu'une app, `apps/api`). Il s'arrête en même temps que l'api pendant une restauration.
