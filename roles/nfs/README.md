# Role nfs

vm-media (serveur) :
- `/data/flixy` + `films`, `downloads/radarr`, `import`, `demo`, en uid/gid 1000, droits 2775
- export NFSv4 vers vm-app seulement (`/etc/exports.d/flixy.exports`)
- UFW : 2049 depuis vm-app seulement

vm-app (client) :
- montage `ansible.posix.mount` au meme chemin, options `nfsvers=4.2,_netdev`
- controles (le playbook s'arrete si un test rate) :
  - `mountpoint -q /data/flixy`
  - creation puis suppression d'un fichier en uid 1000 (`setpriv`), proprietaire verifie
