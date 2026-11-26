#!/usr/bin/env bash
# Offline checks: shell syntax, JSON, installer dry run, QML syntax, no personal data.
set -uo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"
fail=0
ok()   { printf '  ok   %s\n' "$1"; }
bad()  { printf '  FAIL %s\n' "$1"; fail=1; }

echo "shell syntax"
for f in install.sh bin/* tests/*.sh; do bash -n "$f" && ok "$f" || bad "$f"; done

echo "json"
for f in $(find . -name '*.json' -not -path './.git/*'); do
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" && ok "$f" || bad "$f"
done

echo "qml syntax"
lint="$(command -v qmllint || echo /usr/lib/qt6/bin/qmllint)"
if [ -x "$lint" ]; then
    for f in $(find . -name '*.qml' -not -path './.git/*'); do
        # imports from KDE/SDDM aren't resolvable offline; only syntax errors fail
        if "$lint" --max-warnings -1 -U "$f" 2>&1 | grep -qE '(^|: )Error: |Syntax error|Expected token'; then bad "$f"; else ok "$f"; fi
    done
else echo "  skip (no qmllint)"; fi

echo "installer dry run"
if [[ "${XDG_CURRENT_DESKTOP:-}" == *KDE* ]]; then
    ./install.sh --dry-run --yes >/dev/null 2>&1 && ok "./install.sh --dry-run" || bad "./install.sh --dry-run"
else echo "  skip (needs a Plasma session)"; fi

echo "personal data"
if grep -rInE '/home/[a-z]|[A-Za-z0-9._%+-]+@(gmail|yandex|mail)\.' --exclude-dir=.git --exclude=check.sh . | grep -v 'SPDX-FileCopyrightText' ; then
    bad "personal paths or e-mail found above"
else ok "no personal paths or e-mail"; fi

exit $fail
