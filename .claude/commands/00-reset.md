# Reset Workflow

Reset the workflow state to start fresh.

## When to Use

| Situation | Action |
|-----------|--------|
| Workflow completed successfully | `/00-reset` |
| Need to abort current workflow | `/00-reset` |
| Starting a completely new task | `/00-reset` |

## What Happens

Archives and removes the active workflow.

## Execute Reset

```bash
python3 .claude/hooks/workflow.py complete
```

Or if the workflow is stuck/broken:
```bash
# List active workflows
python3 .claude/hooks/workflow.py list

# Start fresh
python3 .claude/hooks/workflow.py start "new-workflow-name"
```

## Next Steps

After reset, start a new workflow:

```
/10-bug [description]    → Bug analysis & fix
/11-feature [description] → Feature planning
/01-context              → Manual context generation
```

---

*Use reset for clean starts. Don't carry state from abandoned work.*
