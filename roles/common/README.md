# Role common

Base des deux VM :
- paquets de base (sudo, curl, ufw, rsync, jq, python3-requests)
- utilisateur `deploy` avec la cle SSH du noeud de controle, sudo sans mot de passe
- SSH : cle uniquement, root interdit (`/etc/ssh/sshd_config.d/10-flixy.conf`)
- IP fixe optionnelle (`common_ip_fixe: true`), sinon donnee a la creation de la VM
- UFW : defaut deny, SSH seulement depuis `admin_ips` (et depuis vm-app sur vm-media
  pour la copie des sauvegardes)

`iptables-persistent` n'est pas installe : sur Debian 13 il est incompatible avec ufw
(`Breaks`). Les regles DOCKER-USER sont gerees par le role docker.
