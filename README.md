# flixy-ansible

Projet SAÉ 5.02 (BUT R&T 3e année) - Léo Ponthieux

## But

Flixy est une plateforme de streaming perso que je développe (API NestJS + front web).
Aujourd'hui tout tourne sur une seule VM, déployé à la main avec Portainer, sans
sauvegarde. Le but de la SAÉ est de redéployer la chaîne de zéro avec Ansible sur deux
VM Debian vierges, sur une copie séparée avec des comptes et des clés de test.

Ordre de priorité :
1. déploiement reproductible (et idempotent)
2. sécurité (ports, filtrage, secrets dans Vault)
3. sauvegarde et restauration
4. recherche automatique des films, en dernier

Périmètre : films uniquement (Radarr). Pas de Sonarr, pas de GPU, pas de tunnel Cloudflare.

## Architecture

| VM | IP | OS | Conteneurs |
|---|---|---|---|
| vm-app | 192.168.1.50/24 | Debian 13 (trixie) | nginx, web, api, migrator, postgres, valkey, minio |
| vm-media | 192.168.1.51/24 | Debian 13 (trixie) | radarr, prowlarr, qbittorrent |

- Passerelle 192.168.1.1, IP fixes dans l'inventaire.
- Le Mac est le nœud de contrôle Ansible (SSH par clé, utilisateur `deploy`).
- Images figées dans `inventory/group_vars/all/main.yml` : postgres 18.6, valkey 9.1.2,
  minio RELEASE.2026-08-04, nginx 1.30.6, radarr 6.4.4, prowlarr 2.6.5,
  qbittorrent 5.2.4.
- web, api et migrator sont construites par la CI de mon GitLab avec un tag fixe pour la
  SAÉ (`flixy_image_tag`, ex. `sae-1.0`). Jamais de `latest`.

## Flux

1. L'utilisateur demande un film sur le site (nginx -> web / api).
2. L'api met la demande dans une file (Valkey) et ajoute le film dans Radarr par son API.
3. Radarr cherche via Prowlarr et envoie le téléchargement à qBittorrent (catégorie radarr).
4. Radarr range le fichier dans `/data/flixy` et appelle le webhook
   `https://192.168.1.50/v1/radarr/webhook` (secret Bearer).
5. L'api ajoute le film au catalogue PostgreSQL. Le fichier est lu sur le montage NFS.

## Ports et filtrage

vm-app :
- seul nginx publie des ports : 80 (fait uniquement un 301 vers le 443) et 443
- api (3000), postgres (5432), valkey (6379) et minio (9000) ne sont pas publiés
- le webhook passe par nginx en HTTPS, `location /v1/radarr/webhook` autorisée seulement
  depuis 192.168.1.51, donc pas de port en plus

vm-media :
- seul Radarr publie le 7878. Comme Docker contourne UFW, il est filtré dans la chaîne
  `DOCKER-USER` (192.168.1.50 seulement), règles persistantes
- Prowlarr et qBittorrent ne sont pas publiés. Pour leurs WebUI je passe par un tunnel
  SSH, par ex. `ssh -L 9696:<ip conteneur>:9696 deploy@192.168.1.51`

UFW sur les deux VM : SSH (22) depuis le Mac, et NFS (2049) sur vm-media depuis vm-app
seulement. Tout le reste en deny.

## NFS

- vm-media exporte `/data/flixy` en NFSv4 vers 192.168.1.50 uniquement :
  `rw,sync,no_subtree_check,root_squash`
- dossier en uid/gid 1000, droits 2775. Radarr, qBittorrent et l'api tournent en 1000.
- vm-app monte au même chemin avec `ansible.posix.mount` (option `_netdev`), plus un
  drop-in systemd `RequiresMountsFor=/data/flixy` sur `docker.service`.
- avant le `compose up`, le rôle vérifie `mountpoint -q /data/flixy` et une écriture en
  uid 1000. Si ça rate, le playbook s'arrête.

## Sauvegarde et restauration

`backup.yml` (et un timer quotidien posé par le rôle backup) :
- dump PostgreSQL + `mc mirror` du bucket MinIO
- envoi en rsync/SSH sur vm-media, conservation 7 jours

`restore.yml` :
- relance d'abord `deploy.yml`, qui recrée les configs (Radarr, Prowlarr, qBittorrent,
  nginx, compose) depuis l'inventaire et Vault
- PostgreSQL : arrêt de l'api, recréation de la base, `pg_restore` du dump choisi
  (le dernier par défaut), puis migrator et api
- MinIO : recopie du miroir
- les médias ne sont ni sauvegardés ni touchés

Les deux VM sont sur le même Proxmox, donc ça ne protège pas d'une panne du serveur.

## Test d'idempotence

`deploy.yml` lancé deux fois : le 2e passage doit donner `changed=0`.
- tâches API : GET d'abord, création ou modification seulement s'il y a une différence
- le migrator n'applique rien au 2e passage
- le module mount ne change rien

Les sorties des deux passages sont gardées dans `tests/`. Procédure dans `tests/README.md`.

## Médias de démo et repli

Uniquement Big Buck Bunny et Sintel (Blender Foundation, CC BY 3.0) et une vidéo de test
générée avec ffmpeg. Licences, liens et attribution dans `docs/medias.md`.

Si la recherche ou le téléchargement externe ne marche pas : je dépose le fichier dans
`/data/flixy/import`, je lance l'import manuel Radarr par API (commande
`DownloadedMoviesScan`), puis le webhook ajoute le film au catalogue comme d'habitude.

## Arborescence

```
ansible.cfg  requirements.yml
inventory/   hosts.example.yml, group_vars/all/{main.yml, vault.example.yml}
roles/       common, docker, nfs, media_stack, flixy_app, reverse_proxy, backup
playbooks/   deploy.yml, backup.yml, restore.yml, teardown.yml
docs/        medias.md
tests/       idempotence
```

Ordre des rôles dans `deploy.yml` : common, docker, nfs (vm-media puis vm-app),
media_stack, flixy_app, reverse_proxy, backup.

Les rôles ont été créés avec `ansible-galaxy init`. Pour l'instant ce n'est que le
squelette, avec une tâche de départ par rôle.

## Lancement

```bash
ansible-galaxy collection install -r requirements.yml

# inventaire et secrets (jamais commités, voir .gitignore)
cp inventory/hosts.example.yml inventory/hosts.yml
cp inventory/group_vars/all/vault.example.yml inventory/group_vars/all/vault.yml
ansible-vault encrypt inventory/group_vars/all/vault.yml

ansible all -m ping
ansible-playbook playbooks/deploy.yml --syntax-check

ansible-playbook playbooks/deploy.yml --ask-vault-pass
ansible-playbook playbooks/backup.yml --ask-vault-pass
ansible-playbook playbooks/restore.yml --ask-vault-pass                  # dernier dump
ansible-playbook playbooks/restore.yml -e backup_file=<dump> --ask-vault-pass
ansible-playbook playbooks/teardown.yml                                  # garde les volumes
```
