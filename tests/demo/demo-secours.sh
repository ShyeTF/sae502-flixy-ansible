#!/bin/bash
# Demo B (secours) : import d'un film libre + webhook. A lancer sur vm-media avec l'uid 1000.
# La cle API Radarr arrive par l'entree standard (jamais en argument, jamais affichee) :
#   ansible-vault view ... | sed -n 's/^vault_radarr_api_key: "\(.*\)"/\1/p' \
#     | ssh deploy@vm-media 'sudo -u "#1000" bash /tmp/demo-secours.sh'
read -r K
[ ${#K} -eq 32 ] || { echo "cle API absente"; exit 1; }
R=http://172.30.0.10:7878/api/v3
h() { curl -s -H "X-Api-Key: $K" -H "Content-Type: application/json" "$@"; }
echo "== $(date '+%d/%m/%Y %H:%M:%S') demo B (secours) : import + webhook"
echo "-- 1. Sintel (TMDB 45745) ajoute dans Radarr, surveille, sans recherche"
if [ "$(h "$R/movie?tmdbId=45745" | python3 -c "import json,sys;print(len(json.load(sys.stdin)))")" != 0 ]; then echo "Sintel deja dans Radarr : remettre l'etat de depart avant"; exit 1; fi
h "$R/movie/lookup/tmdb?tmdbId=45745" > /tmp/m.json
python3 - <<'P'
import json
m=json.load(open('/tmp/m.json'))
m.update({'qualityProfileId':4,'rootFolderPath':'/data/flixy/films','monitored':True,'minimumAvailability':'released','addOptions':{'searchForMovie':False}})
json.dump(m,open('/tmp/m.json','w'))
P
h -X POST "$R/movie" -d @/tmp/m.json | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('title'),d.get('year'),'id',d.get('id'),'path',d.get('path')) if isinstance(d,dict) else print(d)"
rm -f /tmp/m.json
echo "-- 2. copie du fichier de demo dans le dossier d'import"
mkdir -p "/data/flixy/import/Sintel (2010)"
cp "/data/flixy/demo/Sintel (2010)/Sintel.2010.1080p.mkv" "/data/flixy/import/Sintel (2010)/"
ls -l "/data/flixy/import/Sintel (2010)/"
echo "-- 3. import par l'API Radarr (DownloadedMoviesScan, Move)"
h -X POST "$R/command" -d '{"name":"DownloadedMoviesScan","path":"/data/flixy/import/Sintel (2010)","importMode":"Move"}' | python3 -c "import json,sys;d=json.load(sys.stdin);print('commande',d['name'],'id',d['id'],d['status'])"
for i in $(seq 1 30); do sleep 4; f=$(h "$R/movie?tmdbId=45745" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d[0].get('movieFile',{}).get('path','') if d else '')"); [ -n "$f" ] && break; done
echo "-- 4. fichier range par Radarr : $f"
ls -ln "$f"; ls "/data/flixy/import/Sintel (2010)/" 2>/dev/null | wc -l | sed 's/^/fichiers restants dans import : /'
echo "-- 5. historique Radarr (dernier evenement)"
h "$R/history?pageSize=3&sortKey=date&sortDirection=descending" | python3 -c "import json,sys;[print(r['date'],r['eventType'],r['sourceTitle']) for r in json.load(sys.stdin)['records']]"
