# flixy-ansible

Projet SAÉ 5.02 (BUT R&T 3e année) - Léo Ponthieux

## But

Flixy est une plateforme de streaming perso que je développe (API NestJS + front web).
Quand un utilisateur demande un film, l'API l'ajoute dans Radarr, qui le cherche via
Prowlarr et l'envoie à qBittorrent. Une fois le film rangé, Radarr prévient l'API par
webhook et le film arrive dans le catalogue.

Aujourd'hui tout est déployé à la main avec Portainer sur une seule VM. Le but de la SAÉ
est de pouvoir tout redéployer de zéro avec Ansible sur deux VM Debian vierges, avec des
versions d'images figées, du HTTPS, un pare-feu et une sauvegarde de la base.

Pour la SAÉ je travaille sur une copie séparée avec des comptes et des clés de test,
rien n'est branché sur mon serveur actuel. Périmètre : films uniquement (pas de Sonarr).

## Architecture

| VM       | IP (exemple)  | Conteneurs                                                   |
|----------|---------------|--------------------------------------------------------------|
| vm-app   | 192.168.1.50  | nginx, web, api, migrator, postgres, valkey, minio           |
| vm-media | 192.168.1.51  | prowlarr, radarr, qbittorrent                                |

- Le Mac sert de nœud de contrôle Ansible (SSH par clé, utilisateur `deploy`).
- `/data/flixy` est exporté en NFS par vm-media et monté au même chemin sur vm-app.
- Seuls le 443 et le 22 sont ouverts sur vm-app. Postgres, Valkey, MinIO et l'API restent
  dans le réseau Docker.
- Les dumps PostgreSQL partent tous les jours sur vm-media (rsync sur SSH), gardés 7 jours.

Les versions des images sont dans `inventory/group_vars/all/main.yml`.

## Rôles (dans l'ordre de deploy.yml)

1. `common` : utilisateur technique, clés SSH, mises à jour, ufw
2. `docker` : Docker Engine + Compose
3. `nfs` : export sur vm-media, montage sur vm-app
4. `media_stack` : Prowlarr, Radarr, qBittorrent + config par API (module uri)
5. `flixy_app` : compose généré en Jinja2, secrets dans Vault, migrator avant l'api
6. `reverse_proxy` : nginx, certificat auto-signé, redirection 80 -> 443
7. `backup` : pg_dump quotidien vers vm-media

Les rôles ont été créés avec `ansible-galaxy init`. Pour l'instant ils ne contiennent
que des tâches de départ, le contenu arrive au fur et à mesure.

## Playbooks

- `deploy.yml` : déploiement complet
- `backup.yml` : sauvegarde à la main
- `restore.yml` : restauration d'un dump (`-e backup_file=...`)
- `teardown.yml` : suppression, garde les volumes par défaut (`keep_volumes: true`)

## Lancement

```bash
# inventaire et secrets (jamais commités, voir .gitignore)
cp inventory/hosts.example.yml inventory/hosts.yml
cp inventory/group_vars/all/vault.example.yml inventory/group_vars/all/vault.yml
ansible-vault encrypt inventory/group_vars/all/vault.yml

# vérifier
ansible all -m ping
ansible-playbook playbooks/deploy.yml --syntax-check

# déployer
ansible-playbook playbooks/deploy.yml --ask-vault-pass

# sauvegarde / restauration / suppression
ansible-playbook playbooks/backup.yml --ask-vault-pass
ansible-playbook playbooks/restore.yml -e backup_file=flixy-2026-10-22.sql.gz --ask-vault-pass
ansible-playbook playbooks/teardown.yml
```
