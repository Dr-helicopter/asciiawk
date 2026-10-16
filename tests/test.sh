#!/bin/sh
# usage: ./test.sh			run all tests
#		./test.sh --bless	overwrite expected outputs with current output
#		AWK=mawk ./test.sh   run against a different awk
#		SCRPT=./asciiawk.awk ./test.sh   run against a different script

awk_bin=${AWK:-awk}
asciiawk_script=${SCRPT:-asciiawk.awk}

tmp=$(mktemp) || exit 2
trap 'rm -f "$tmp"' EXIT
pass=0
fail=0

for f in tests/*.adoc; do
	exp=${f%.adoc}.out
	$awk_bin -f "$asciiawk_script" "$f" >"$tmp" 2>/dev/null

	if [ "$1" = "--bless" ]; then
		cp "$tmp" "$exp"
		echo "blessed $exp"
		continue
	fi

	if diff -u "$exp" "$tmp" >/dev/null 2>&1; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		echo "FAIL: $f"
		diff -u "$exp" "$tmp"  | cat -v | tail -n +3
		diff -u "$exp" "$tmp"  --color=always
	fi
done

[ "$1" = "--bless" ] && exit 0
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
