# Role docker

- depot officiel Docker pour Debian trixie (deb822), docker-ce, buildx, compose
- sur vm-app : drop-in `RequiresMountsFor=/data/flixy` sur `docker.service`
- filtrage des ports publies dans la chaine `DOCKER-USER` :
  - script `/usr/local/sbin/flixy-docker-user` genere depuis `docker_user_regles`
    (`inventory/group_vars/app` et `media`)
  - service `flixy-docker-user` (oneshot, `PartOf=docker.service`) : les regles sont
    remises a chaque demarrage de Docker, donc persistantes apres un reboot

Verif : `sudo iptables -S DOCKER-USER`
