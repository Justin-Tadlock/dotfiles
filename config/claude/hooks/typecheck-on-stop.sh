#!/usr/bin/env bash
# Claude Code Stop hook: when the working tree has uncommitted TypeScript changes,
# run the project's `typecheck` script and block the stop (exit 2) with the errors
# so Claude fixes them before finishing.
#
# Terminates: if Claude stops again while this hook's block is still active
# (stop_hook_active=true), it exits 0 so a failure Claude can't fix never loops.
# Skips silently when there is no package.json, no `typecheck` script, no git repo,
# or no changed TypeScript files.
set -uo pipefail

input="$(cat)"
if [[ "$(jq -r '.stop_hook_active // false' <<<"${input}")" == "true" ]]; then
  exit 0
fi

[[ -f package.json ]] || exit 0
jq -e '.scripts.typecheck' package.json >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

changed="$(git status --porcelain -- '*.ts' '*.tsx' '*.mts' '*.cts' 2>/dev/null)"
[[ -n "${changed}" ]] || exit 0

if [[ -f yarn.lock ]]; then
  runner=(yarn -s typecheck)
elif [[ -f pnpm-lock.yaml ]]; then
  runner=(pnpm -s typecheck)
else
  runner=(npm run -s typecheck)
fi

if ! output="$("${runner[@]}" 2>&1)"; then
  {
    echo "Typecheck failed (${runner[*]}). Fix these before finishing, or report them as unresolved:"
    tail -n 60 <<<"${output}"
  } >&2
  exit 2
fi
exit 0
