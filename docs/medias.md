# Médias de démo

Pour la SAÉ je n'utilise que des contenus libres. Rien n'est stocké dans le dépôt
(les .mp4, .mkv et .zip sont dans le .gitignore).

| Titre | Auteur | Licence | Page officielle | Téléchargement |
|---|---|---|---|---|
| Big Buck Bunny (2008) | Blender Foundation | CC BY 3.0 | https://peach.blender.org/about/ | https://download.blender.org/demo/movies/BBB/ |
| Sintel (2010) | Blender Foundation | CC BY 3.0 | https://durian.blender.org/sharing/ | https://download.blender.org/demo/movies/ |
| test-pattern.mp4 | moi (généré avec ffmpeg) | aucune | - | - |

Licence : Creative Commons Attribution 3.0 Unported,
https://creativecommons.org/licenses/by/3.0/

## Attribution

Comme demandé par la licence et par les pages des films :

- Big Buck Bunny : (c) copyright 2008, Blender Foundation / www.bigbuckbunny.org
- Sintel : © copyright Blender Foundation | durian.blender.org

Licence : CC BY 3.0, https://creativecommons.org/licenses/by/3.0/.
Les films ne sont pas modifiés. Ils sont seulement réencodés en HLS pour la lecture.
Les crédits de fin restent dans la vidéo.

## Vidéo de test

Une vidéo courte générée, pour tester sans rien télécharger :

```bash
ffmpeg -f lavfi -i testsrc2=size=1280x720:rate=25 -f lavfi -i sine=frequency=440 \
  -t 60 -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest test-pattern.mp4
```

## Repli si la recherche ou le téléchargement externe ne marche pas

Si l'indexeur ou le téléchargement n'est pas disponible le jour de la démo :

1. Le film est d'abord demandé depuis le site (sinon l'api ne l'ajoute pas au catalogue).
2. Je copie le fichier dans `/data/flixy/import/<Titre (Année)>/` en uid/gid 1000.
3. Je lance l'import manuel dans Radarr par son API :

   ```bash
   curl -X POST "http://192.168.1.51:7878/api/v3/command" \
     -H "X-Api-Key: $RADARR_API_KEY" -H "Content-Type: application/json" \
     -d '{"name": "DownloadedMoviesScan", "path": "/data/flixy/import"}'
   ```

   (lancé depuis vm-app, la seule IP autorisée sur le 7878)
4. Radarr range le fichier et appelle le webhook `/v1/radarr/webhook`, et l'api
   ajoute le film au catalogue comme dans le cas normal.
