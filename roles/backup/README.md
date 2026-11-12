# Role backup

vm-app :
- `/usr/local/sbin/flixy-backup [backup_id]` : api arretee, `pg_dump -Fc` + lignes par
  table, `mc mirror` du bucket dans le dossier du jeu, api relancee, `SHA256SUMS`,
  `manifest.json`, `rsync` vers vm-media (manifest en dernier)
- timer `flixy-backup.timer` (tous les jours a 3 h), meme script que `backup.yml`
- cle SSH `/root/.ssh/flixy-backup`

vm-media :
- compte `flixy-backup`, cle de vm-app limitee a `rrsync /srv/backups/flixy`
  (`restrict`, pas de shell)
- `/srv/backups/flixy` en 0700, hors export NFS
- `/usr/local/sbin/flixy-retention` + timer a 4 h : supprime les jeux de plus de 7 jours,
  garde toujours le dernier jeu complet

Un jeu : `postgres.dump`, `minio/`, `lignes.txt`, `objets.txt`, `SHA256SUMS`,
`manifest.json` (le manifest contient le sha256 de `SHA256SUMS`).
