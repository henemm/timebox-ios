#!/bin/bash
# Creates/removes __infra__ override token for infrastructure edits
# Usage: ./scripts/infra_token.sh [create|remove]

TOKEN_FILE="$(cd "$(dirname "$0")/.." && pwd)/.claude/user_override_token.json"
ACTION="${1:-create}"

if [ "$ACTION" = "remove" ]; then
    rm -f "$TOKEN_FILE"
    echo "Infra token removed."
elif [ "$ACTION" = "create" ]; then
    cat > "$TOKEN_FILE" << EOF
{
  "version": 2,
  "tokens": {
    "__infra__": {
      "created": "$(date -u +%Y-%m-%dT%H:%M:%S)",
      "granted_by": "user_prompt"
    }
  }
}
EOF
    echo "Infra token created (1h TTL)."
else
    echo "Usage: $0 [create|remove]"
    exit 1
fi
