# Role reverse_proxy (vm-app)

- nginx dans son propre compose (`/opt/flixy/proxy`), seul conteneur qui publie des
  ports (80, 443), relie au reseau `flixy_interne`
- certificat auto-signe (openssl, cree une seule fois), SAN = IP du site
- 80 : uniquement `301` vers 443
- `/v1/radarr/webhook` : `allow` IP de vm-media, `deny all` (403 sinon), le secret
  Bearer est verifie par l'api (401 si mauvais)
- `/v1/` -> api, `/` -> web
- `flixy_maintenance: true` (passe par restore.yml) : 503 sur tout le site et le webhook
