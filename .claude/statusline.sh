#!/bin/bash
# Status line: shows active workflow name for current session
# Receives JSON context via stdin from Claude Code

STATE_FILE="/Users/hem/Developer/my-daily-sprints/.claude/workflow_state.json"
INPUT=$(cat)

if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Get transcript_path from stdin as unique session identifier
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -n "$TRANSCRIPT" ]; then
  # Derive TTY ID from transcript path (same hash approach as workflow hooks)
  TTY_ID=$(printf '%s' "$TRANSCRIPT" | md5 -q 2>/dev/null | cut -c1-8)

  # Try session-specific lookup first
  WORKFLOW=$(jq -r --arg id "$TTY_ID" '
    .session_workflows[$id].workflow // empty
  ' "$STATE_FILE" 2>/dev/null)
fi

# Fall back to global active_workflow
if [ -z "$WORKFLOW" ]; then
  WORKFLOW=$(jq -r '.active_workflow // empty' "$STATE_FILE" 2>/dev/null)
fi

if [ -n "$WORKFLOW" ]; then
  echo "$WORKFLOW"
fi
