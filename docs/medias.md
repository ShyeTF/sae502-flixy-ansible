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

## Démo de secours

La démo import + webhook (si la recherche ou le téléchargement externe ne marche pas le
jour J) utilise ces mêmes fichiers. Procédure dans `docs/secours.md`.

Ces mentions de licence et d'attribution sont aussi rappelées sur la diapo de la démo.
