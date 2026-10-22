# Test d'idempotence

But : lancer `deploy.yml` deux fois de suite sur les mêmes VM. Le 2e passage doit
finir avec `changed=0` sur les deux hôtes.

## Procédure

```bash
# 1er passage (VM vierges)
ansible-playbook playbooks/deploy.yml --ask-vault-pass | tee tests/deploy-run1.log

# 2e passage, sans rien changer
ansible-playbook playbooks/deploy.yml --ask-vault-pass | tee tests/deploy-run2.log

# controle
grep -A3 "PLAY RECAP" tests/deploy-run2.log
```

Résultat attendu dans `deploy-run2.log` :

```
vm-app   : ok=XX  changed=0  unreachable=0  failed=0 ...
vm-media : ok=XX  changed=0  unreachable=0  failed=0 ...
```

## Points à surveiller

- Tâches API (Radarr, Prowlarr, qBittorrent) : un GET d'abord, puis POST ou PUT
  seulement si la config est différente. Sinon `changed_when: false`.
- migrator : au 2e passage il n'y a aucune migration à appliquer, la tâche ne doit pas
  passer en changed.
- `ansible.posix.mount` : le montage existe déjà, donc rien ne change.
- Templates (compose, nginx) : même contenu, donc pas de redémarrage.

Les deux logs sont gardés dans ce dossier (deploy-run1.log, deploy-run2.log) comme preuve
pour la soutenance. Vérifier qu'ils ne contiennent aucun secret (no_log sur les tâches
qui manipulent Vault).
