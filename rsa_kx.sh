#!/bin/bash
# Key exchange usage per client-ssl profile, with RSA vs. everything else
# Usage: ./rsa_kx.sh [--percent N] [--csv]
#   --percent N   show only profiles with RSA % > N
#   --csv         output CSV instead of the text report

pct=-1
csv=0
while [ $# -gt 0 ]; do
    case "$1" in
        --percent)   pct="$2"; shift 2 ;;
        --percent=*) pct="${1#*=}"; shift ;;
        --csv)       csv=1; shift ;;
        -h|--help)   echo "Usage: $0 [--percent N] [--csv]"; exit 0 ;;
        *)           echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if ! [[ "$pct" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "--percent needs a number, got: '$pct'" >&2
    exit 1
fi

tmsh show ltm profile client-ssl field-fmt | awk -v pct="$pct" -v csv="$csv" '
function report(r, o,   t) {
    t = r + o
    if (t == 0) { print "  (no handshakes)"; return }
    printf "  RSA:other = %d:%d  (%.1f%% RSA)\n", r, o, 100 * r / t
}
/^ltm profile client-ssl / { name = $4; names[++n] = name; next }
tolower($1) ~ /key-?xchg$/ {
    m = tolower($1); sub(/.*\./, "", m); sub(/-?key-?xchg$/, "", m)
    c = $2 + 0
    if (!(m in seenm)) { seenm[m] = 1; methods[++nm] = m }
    cnt[name, m] += c
    if (m == "rsa") { rsa[name] += c; trsa += c }
    else {
        oth[name] += c; toth += c
        if (c > 0) list[name] = list[name] sprintf("  %-12s %d\n", toupper(m), c)
    }
}
END {
    if (csv) {
        printf "profile,total,rsa,other,rsa_percent"
        for (j = 1; j <= nm; j++) printf ",%s", methods[j]
        printf "\n"
    }
    shown = 0
    for (i = 1; i <= n; i++) {
        p = names[i]
        r = rsa[p] + 0; o = oth[p] + 0; t = r + o
        if (t == 0 || 100 * r / t <= pct) continue
        shown++
        if (csv) {
            printf "%s,%d,%d,%d,%.2f", p, t, r, o, 100 * r / t
            for (j = 1; j <= nm; j++) printf ",%d", cnt[p, methods[j]]
            printf "\n"
            continue
        }
        print p
        printf "  %-12s %d\n", "RSA", r
        printf "%s", list[p]
        report(r, o)
        print ""
    }
    if (csv) exit
    if (pct >= 0) printf "%d of %d profiles above %s%% RSA\n\n", shown, n, pct
    print "ALL PROFILES"
    report(trsa + 0, toth + 0)
}'
