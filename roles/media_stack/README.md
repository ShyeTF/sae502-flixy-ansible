# Role media_stack (vm-media)

- compose `/opt/flixy-media/compose.yml` : Radarr (seul port publie, 7878, filtre
  DOCKER-USER), Prowlarr et qBittorrent non publies, tous en PUID/PGID 1000
- reseau docker a sous-reseau fixe (`media_docker_subnet`) : Ansible et le tunnel SSH
  joignent les conteneurs par leur IP, sans publier de port
- fichiers poses avant le 1er demarrage (`force: false`) : `config.xml` de Radarr et
  Prowlarr (cle API depuis Vault), `qBittorrent.conf` (mot de passe en PBKDF2)
- etat complet par API, toujours GET puis POST/PUT si besoin (`provider.yml`,
  `config_unique.yml`) : categorie qBittorrent, dossier racine, profil, gestion des
  medias, nommage, hote (auth + certificat), client qBittorrent, webhook, application
  Radarr dans Prowlarr, indexeurs, synchro
- controle final (`controle.yml`) : assert + resume pour `tests/preuves/radarr-etat.txt`

Limite connue : les mots de passe (admin, qBittorrent) et le secret du webhook sont
masques dans les GET, ils ne sont donc pas compares. Si on les change dans Vault, il
faut supprimer l'element dans Radarr (ou le fichier de config) pour qu'il soit recree.

Tunnel pour les WebUI : `ssh -L 9696:172.30.0.11:9696 -L 8080:172.30.0.12:8080 deploy@<vm-media>`
