Why these flags:

	•	-print0 / read -d '' — survives spaces and newlines in paths
	•	-depth — processes files before their parent dirs are touched, so nothing gets re-traversed mid-rename
	•	[[ $b == README-* ]] — idempotent, safe to re-run without stacking README-README-
	•	mv -n — never clobber an existing target
	•	-- — filenames starting with - won’t be parsed as options

Bash only ([[ ]]), which is fine on OL8.

find . -depth -type f -name '*.md' -print0 |
while IFS= read -r -d '' f; do
  d=${f%/*}; b=${f##*/}
  [[ $b == README-* ]] && continue
  printf '%s -> %s\n' "$f" "$d/README-$b"
done
