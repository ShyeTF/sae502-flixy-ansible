# Preuves pour la soutenance

Ce dossier contient les **vraies** sorties des tests, copiées telles quelles. Rien
n'est réécrit ni inventé : si un test rate, sa sortie est gardée aussi, avec la
correction faite ensuite.

Pour l'instant il est vide, les rôles ne sont pas encore écrits.

## Ce qu'il faut y mettre

| Fichier | Contenu | Comment |
|---|---|---|
| `deploy-run1.log` | 1er passage de `deploy.yml` sur VM vierges | voir `tests/README.md` |
| `deploy-run2.log` | 2e passage, doit finir en `changed=0` | idem |
| `images.txt` | vérification des images juste avant la démo | commandes de `docs/images.md` |
| `radarr-etat.txt` | contrôle final de l'état de Radarr | sortie du rôle `media_stack` |
| `backup.log` | sortie de `backup.yml` | `ansible-playbook playbooks/backup.yml ... \| tee` |
| `restauration/<backup_id>/manifest.json` | manifest du jeu restauré | copié depuis vm-media |
| `restauration/<backup_id>/avant.txt` | état avant restauration : nb de lignes par table, liste des objets MinIO | requêtes de `docs/sauvegarde-restauration.md` |
| `restauration/<backup_id>/restore.log` | sortie de `restore.yml` | `tee` |
| `restauration/<backup_id>/apres.txt` | même chose après restauration, + 200 de la route de santé | idem |
| `secours/` | test de la démo import + webhook | voir `docs/secours.md` |

Chaque fichier commence par la date et l'heure du test et le commit du dépôt utilisé
(`git rev-parse --short HEAD`).

Captures d'écran : en PNG, dans le sous-dossier du test, avec un nom clair
(`secours/03-film-dans-catalogue.png`).

## Pas de secrets

Avant chaque commit dans ce dossier :

```bash
grep -rniE 'password|passwd|api_?key|secret|token|bearer|authorization' tests/preuves/
```

Rien ne doit sortir à part des noms de variables. Les tâches qui manipulent Vault sont en
`no_log: true`, mais je vérifie quand même. Pas de `-v` / `-vvv` dans les logs gardés
(ça affiche les variables). Si un secret part par erreur dans un commit : je le change
dans Vault, pas seulement dans le fichier.
