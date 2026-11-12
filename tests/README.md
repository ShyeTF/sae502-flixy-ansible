# Tests

Toutes les sorties gardées vont dans `tests/preuves/` (voir son README, pas de secrets,
pas de fausses sorties).

## 1. Idempotence de deploy.yml

But : lancer `deploy.yml` deux fois de suite sur les mêmes VM. Le 2e passage doit
finir avec `changed=0` sur les deux hôtes.

```bash
# 1er passage (VM vierges)
ansible-playbook playbooks/deploy.yml --ask-vault-pass | tee tests/preuves/deploy-run1.log

# 2e passage, sans rien changer
ansible-playbook playbooks/deploy.yml --ask-vault-pass | tee tests/preuves/deploy-run2.log

# controle
grep -A3 "PLAY RECAP" tests/preuves/deploy-run2.log
```

Résultat attendu dans `deploy-run2.log` :

```
vm-app   : ok=XX  changed=0  unreachable=0  failed=0 ...
vm-media : ok=XX  changed=0  unreachable=0  failed=0 ...
```

Points à surveiller :
- tâches API (Radarr, Prowlarr, qBittorrent) : un GET d'abord, puis POST ou PUT
  seulement si la config est différente (détail dans `docs/radarr.md`)
- migrator : au 2e passage il n'y a aucune migration à appliquer, la tâche ne doit pas
  passer en changed
- `ansible.posix.mount` : le montage existe déjà, donc rien ne change
- templates (compose, nginx) : même contenu, donc pas de redémarrage

## 2. État de Radarr

Après le 1er passage, le contrôle final du rôle `media_stack` doit être vert (racine,
profil, client qBittorrent, indexeurs, webhook). Sortie dans `radarr-etat.txt`.

## 3. Sauvegarde et restauration

Procédure (détail dans `docs/sauvegarde-restauration.md`) :

1. `backup.yml` -> noter le `backup_id`, garder le `manifest.json`
2. ajouter un film et une image de profil (écritures après la sauvegarde)
3. relever l'état « avant » (lignes par table, liste des objets MinIO)
4. `restore.yml -e backup_id=<id>`
5. relever l'état « après » : il doit correspondre au manifest, le film et l'image du
   point 2 ne doivent plus être là
6. pendant la restauration, vérifier que le site et le webhook répondent 503 et que
   l'api ne redémarre qu'après la vérification
7. relancer `deploy.yml` après la restauration : `changed=0` attendu

## 4. Démo de secours

Procédure et checklist dans `docs/secours.md`, sorties dans `tests/preuves/secours/`.

## 5. Syntaxe et lint

```bash
for p in playbooks/*.yml; do ansible-playbook -i inventory/hosts.example.yml "$p" --syntax-check; done
ansible-lint      # config dans .ansible-lint, profil production
```
