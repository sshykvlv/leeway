#!/bin/bash
# Снимает живые ответы usage-эндпоинтов в тестовые фикстуры.
# Токены не печатает.
set -euo pipefail
cd "$(dirname "$0")/.."
FIX=Tests/LimitBarTests/Fixtures; mkdir -p "$FIX"

CLAUDE_TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])")
curl -sf https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $CLAUDE_TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "User-Agent: claude-code/2.0.0" \
  -o "$FIX/claude-usage.json"

CODEX_TOKEN=$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.codex/auth.json')))['tokens']['access_token'])")
curl -sf https://chatgpt.com/backend-api/wham/usage \
  -H "Authorization: Bearer $CODEX_TOKEN" \
  -o "$FIX/codex-usage.json"

python3 - <<'EOF'
import json
for f in ("Tests/LimitBarTests/Fixtures/claude-usage.json",
          "Tests/LimitBarTests/Fixtures/codex-usage.json"):
    d = json.load(open(f))
    print(f, "→ top-level keys:", sorted(d.keys()))
EOF
