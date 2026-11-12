# Sauvegarde et restauration

Retour de M. Martini : un miroir MinIO mis à jour chaque nuit ne permet pas de retrouver
les objets qui allaient avec un ancien dump. Du coup chaque sauvegarde est maintenant un
**jeu complet et identifié** : le dump et les objets sont pris au même moment et rangés
ensemble.

## Ce qui est sauvegardé ou pas

| Donnée | Sauvegardée | Pourquoi |
|---|---|---|
| base PostgreSQL `flixy` | oui, `pg_dump -Fc` | catalogue, comptes, demandes |
| bucket MinIO `user.picture` | oui, copie dans le jeu | images envoyées par les utilisateurs, référencées dans la base |
| Valkey (file BullMQ) | non | file de travail, les demandes en cours sont dans la base |
| configs Radarr / Prowlarr / qBittorrent / nginx / compose | non | recréées par `deploy.yml` depuis l'inventaire et Vault |
| médias `/data/flixy` | non | films libres, retéléchargeables |

## Un jeu de sauvegarde

`backup_id` = horodatage de la sauvegarde, format `%Y%m%d-%H%M%S` (ex. `20261024-030000`).

Sur vm-media, dans `/srv/backups/flixy/<backup_id>/` :

```
postgres.dump    dump PostgreSQL (format custom)
minio/           copie du bucket user.picture à ce moment-là
lignes.txt       nombre de lignes par table (pour la vérification après restauration)
objets.txt       liste des objets du bucket (nom + taille)
SHA256SUMS       sha256 de tous les fichiers du jeu
manifest.json    description du jeu, écrit en dernier
```

`/srv/backups/flixy` n'est pas dans l'export NFS, donc vm-app ne peut pas effacer les
sauvegardes par le montage. Droits 0700.

Le manifest sert à savoir exactement ce qu'il y a dans le jeu et avec quelle version de
Flixy il a été fait. Format prévu (exemple de structure, pas une vraie sortie) :

```json
{
  "backup_id": "<horodatage>",
  "date": "<date ISO 8601>",
  "hote": "vm-app",
  "flixy_image_tag": "sae-1.0",
  "images": { "api": "<image@sha256:...>", "web": "...", "migrator": "...", "postgres": "...", "minio": "..." },
  "code": { "web": "<SHA>", "api": "<SHA>", "migrator": "<SHA>" },
  "postgres": { "fichier": "postgres.dump", "sha256": "<sha256>", "lignes_par_table": { "<table>": 0 } },
  "minio": { "bucket": "user.picture", "dossier": "minio/", "nb_objets": 0, "taille_octets": 0 }
}
```

- `images` : digests réels des images qui tournent (`docker image inspect`, champ
  `RepoDigests`)
- `code` : recopie de `flixy_code_refs` (voir `docs/images.md`)
- `lignes_par_table` : comptage exact de chaque table du schéma public, pour comparer
  après restauration

Un dossier sans `manifest.json` est un jeu incomplet (sauvegarde coupée en route) :
`restore.yml` l'ignore et la rétention le supprime.

## backup.yml

Lancé à la main, ou chaque nuit à 3 h par le timer posé par le rôle backup (même script
`/usr/local/sbin/flixy-backup`).

1. calcul du `backup_id` (une seule fois pour tout le playbook)
2. dossier de préparation `/var/backups/flixy/<backup_id>/` sur vm-app
3. arrêt des écritures : `api` et `migrator` (et le worker BullMQ s'il est séparé) sont
   stoppés quelques secondes, le temps du dump et de la copie. À l'échelle de la SAÉ
   (une base de quelques Mo, peu d'images) ça prend moins d'une minute. Sans ça, une
   image envoyée entre le dump et la copie MinIO pourrait ne pas correspondre à la base.
4. `pg_dump -Fc` + comptage des lignes par table
5. copie du bucket avec `mc mirror` vers le dossier du jeu (un nouveau dossier à chaque
   fois, ce n'est pas un miroir qu'on écrase)
6. relance de l'api
7. `SHA256SUMS`, puis `manifest.json`
8. `rsync` vers vm-media (manifest envoyé en dernier), puis `sha256sum -c` côté vm-media
9. suppression du dossier de préparation

Rétention : les jeux de plus de 7 jours sont supprimés, mais on garde toujours au moins le
dernier jeu complet (si les sauvegardes plantent pendant une semaine on ne se retrouve pas
sans rien).

Pourquoi pas le versioning du bucket MinIO : ça marche (`mc cp --rewind`), mais les
versions restent sur le même disque que le bucket, donc ce n'est pas une vraie copie, et
il faut retrouver la bonne date à la main. Avec un dossier par jeu, le lien entre dump et
objets est direct.

## restore.yml

```bash
ansible-playbook playbooks/restore.yml -e backup_id=20261024-030000 --ask-vault-pass
ansible-playbook playbooks/restore.yml --ask-vault-pass    # dernier jeu complet
```

Règle principale : **rien n'écrit dans la base ou dans MinIO tant que les deux ne sont pas
restaurés et vérifiés.**

| Étape | Où | Quoi |
|---|---|---|
| 1 | vm-media | choix du jeu (`backup_id` ou le dernier avec un manifest), `sha256sum -c`. Si ça rate on s'arrête, rien n'est touché |
| 2 | vm-app | pose du verrou `/opt/flixy/.restauration-en-cours` |
| 3 | les deux | `deploy.yml` importé avec `flixy_maintenance: true` : configs et conteneurs recréés, mais api / worker / migrator pas démarrés, nginx renvoie 503 sur le site et sur `/v1/radarr/webhook` |
| 4 | vm-media | `docker compose stop radarr` : plus d'import, donc plus d'appel au webhook. qBittorrent continue de télécharger |
| 5 | vm-app | contrôle que les écritures sont bien arrêtées, récupération du jeu, comparaison du tag d'images avec le manifest |
| 6 | vm-app | PostgreSQL : `dropdb` / `createdb`, `pg_restore --no-owner --exit-on-error` |
| 7 | vm-app | MinIO : `mc mirror --overwrite --remove` du dossier `minio/` vers le bucket, qui redevient exactement celui du jeu |
| 8 | vm-app | **vérification** : lignes par table et liste des objets (nom + taille) identiques au manifest. Si ça ne colle pas : échec, on reste en maintenance |
| 9 | vm-app | migrator (rien à appliquer si même tag), puis api, attente du 200 sur la route de santé, sortie de maintenance de nginx, suppression du verrou |
| 10 | vm-media | `docker compose start radarr` : les imports en attente repartent et appellent le webhook, l'api est prête |

### Pour que deploy.yml ne relance pas l'api trop tôt

Deux sécurités :
- `flixy_maintenance` (false par défaut dans `group_vars/all/main.yml`) : `restore.yml`
  importe `deploy.yml` avec `flixy_maintenance: true`. Dans ce mode le rôle `flixy_app`
  ne lance ni le migrator ni l'api, et `reverse_proxy` met nginx en 503.
- le verrou : si quelqu'un relance `deploy.yml` à la main pendant une restauration, le
  rôle `flixy_app` voit `/opt/flixy/.restauration-en-cours` et ne démarre pas non plus
  l'api. Le verrou n'est retiré qu'après la vérification de l'étape 8.

Si la restauration échoue au milieu, le verrou reste : c'est voulu. On corrige, puis on
relance `restore.yml`.

### Changement de version

Si le tag d'images du manifest n'est pas celui de `flixy_image_tag`, la restauration
s'arrête. On peut forcer avec `-e restore_allow_tag_change=true` : dans ce cas le
migrator appliquera les migrations manquantes à l'étape 9.

## Preuves

Pour la soutenance (voir `tests/preuves/README.md`) :
- la sortie de `backup.yml` et le `manifest.json` du jeu utilisé
- un test complet : sauvegarde, ajout d'un film et d'une image, restauration du jeu
  d'avant, vérification que le film et l'image ajoutés ont disparu et que le reste est
  là
- la sortie de `restore.yml`

## Limites

Les deux VM sont sur le même Proxmox : une panne du serveur ou de son disque fait perdre
les données et les sauvegardes. Pour aller plus loin il faudrait une copie hors du
serveur (NAS, ou un `rclone` chiffré vers l'extérieur), hors périmètre de la SAÉ.
