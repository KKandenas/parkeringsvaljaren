#!/usr/bin/env bash
# Gör GitHub-ärenden av veckokontrollens resultat (tool/kontrollera_kallor.dart
# --json). Ett ärende per kommun eller app med etiketten "veckokontroll":
#   - nya problem ger ett nytt ärende (och GitHub mejlar),
#   - finns ärendet redan uppdateras texten,
#   - ärenden vars problem har försvunnit stängs.
#
#   tool/skapa_arenden.sh resultat.json
#
# Kräver GitHub CLI (gh) med rätt att skriva ärenden, och jq.
set -euo pipefail

resultat=$1
etikett=veckokontroll

gh label create "$etikett" --color FBCA04 \
  --description "Hittat av veckokontrollen av källorna" --force >/dev/null

oppna=$(gh issue list --label "$etikett" --state open --limit 500 \
  --json number,title)

aktuella=()
antal=$(jq length "$resultat")
for ((i = 0; i < antal; i++)); do
  rubrik=$(jq -r ".[$i].rubrik" "$resultat")
  titel="Veckokontroll: $rubrik"
  aktuella+=("$titel")
  text=$(
    echo "Veckokontrollen $(date +%Y-%m-%d) hittade:"
    echo
    jq -r ".[$i].problem[] | \"- \" + ." "$resultat"
    echo
    echo "Kontrollera källan och uppdatera assets/data/kommuner.json"
    echo "(eller apps.json). Står appen på sidan av ett annat skäl, lägg"
    echo "dess id under \"namnsOcksa\" för källan. Ärendet stängs av sig"
    echo "självt när kontrollen inte längre hittar problemet."
  )
  nummer=$(jq -r --arg t "$titel" '.[] | select(.title == $t) | .number' \
    <<<"$oppna")
  if [[ -n "$nummer" ]]; then
    gh issue edit "$nummer" --body "$text" >/dev/null
    echo "Uppdaterade #$nummer $titel"
  else
    gh issue create --title "$titel" --body "$text" --label "$etikett" >/dev/null
    echo "Skapade: $titel"
  fi
done

# Stäng ärenden som inte längre har några problem.
while IFS=$'\t' read -r nummer titel; do
  [[ -z "$nummer" ]] && continue
  if ! printf '%s\n' "${aktuella[@]}" | grep -Fxq "$titel"; then
    gh issue close "$nummer" \
      --comment "Veckokontrollen $(date +%Y-%m-%d) hittar inte längre något problem." >/dev/null
    echo "Stängde #$nummer $titel"
  fi
done < <(jq -r '.[] | [.number, .title] | @tsv' <<<"$oppna")
