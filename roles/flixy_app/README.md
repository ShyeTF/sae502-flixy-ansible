# Role flixy_app (vm-app)

1. **Images** (`tasks/images.yml`) : clone en lecture seule du code Flixy sur le noeud
   de controle (commits de `flixy_src`), archive envoyee sur vm-app, `docker build`
   local avec le tag `sae-1.0`. Rien n'est pousse sur le GitLab ni sur le registre de
   Flixy. Reconstruction seulement si l'image manque ou vient d'un autre commit
   (label `org.opencontainers.image.revision`).
2. verif que `/data/flixy` est bien monte (NFS)
3. fichiers d'environnement en 0600 (secrets depuis Vault) + `compose.yml`
4. `up` de postgres, valkey, minio, web (toujours), creation du bucket `user.picture`
5. sauf maintenance ou verrou de restauration : migrator (changed seulement si une
   migration a ete appliquee), puis api, attente du healthcheck `/v1/health`

Aucun port n'est publie par ce compose. nginx (role reverse_proxy) rejoint le reseau
`flixy_interne`.

L'api exige des variables Google, Apple, Sonarr et Cloudflare : pour la copie SAE ce
sont des valeurs factices (vault), ces fonctions ne sont pas utilisees dans la demo.
Turnstile utilise les cles de test officielles de Cloudflare (le captcha passe toujours).
