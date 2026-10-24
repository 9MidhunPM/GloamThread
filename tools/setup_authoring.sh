#!/usr/bin/env bash
# Optional package-local tooling. Never install globally or replace an API key.
set -euo pipefail

package_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
authoring_dir="$package_dir/authoring"
if [[ -L "$authoring_dir" || -L "$authoring_dir/.venv" ]]; then
    printf '%s\n' 'Authoring and its virtual environment must stay inside this extracted package.' >&2
    exit 1
fi
if [[ ! -f "$authoring_dir/requirements-authoring.txt" || ! -f "$authoring_dir/.env.example" ]]; then
    printf '%s\n' 'Run setup_authoring.sh from the extracted arena package, beside authoring/.' >&2
    exit 1
fi
if [[ -L "$authoring_dir/.env" || ( -e "$authoring_dir/.env" && ! -f "$authoring_dir/.env" ) ]]; then
    printf '%s\n' 'authoring/.env must be a regular private file; setup did not change it.' >&2
    exit 1
fi
command -v python3 >/dev/null || { printf '%s\n' 'Install Python 3.10+ with venv/pip support first.' >&2; exit 1; }
python3 -c 'import sys; assert sys.version_info >= (3, 10), "Python 3.10+ is required"'
python3 -m venv "$authoring_dir/.venv"
"$authoring_dir/.venv/bin/python" -m pip install --requirement "$authoring_dir/requirements-authoring.txt"
if [[ ! -e "$authoring_dir/.env" ]]; then
    (umask 077; set -o noclobber; cat -- "$authoring_dir/.env.example" > "$authoring_dir/.env")
fi
chmod 600 -- "$authoring_dir/.env"
printf '%s\n' 'Optional authoring is installed.' \
    'Edit authoring/.env locally to add your own OPENAI_API_KEY. Setup never prints the key.' \
    'Built-in and accepted fighters work offline without this setup.' \
    'Check configuration without a model request: authoring/.venv/bin/python authoring/tools/fighter_forge.py status'
