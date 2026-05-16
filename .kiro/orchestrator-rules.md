# Kiro Orchestrator Rules

## Sub-agent Invocation Limits

**CRITICAL RULE**: When executing spec tasks through the orchestrator:

- **NEVER invoke more than 1 sub-agent at a time**
- Always wait for the previous sub-agent to complete before invoking the next one
- Do NOT use parallel sub-agent invocations even if tasks appear independent
- This prevents rate limiting and ensures stable execution

### Correct Pattern (Sequential)

```
1. Invoke sub-agent for Task 5
2. Wait for completion
3. Invoke sub-agent for Task 6
4. Wait for completion
5. Continue...
```

### Incorrect Pattern (Parallel - DO NOT USE)

```
❌ Invoke sub-agent for Task 5 AND Task 6 simultaneously
❌ Multiple invoke_sub_agent calls in the same turn
```

## Reason

The system has rate limits on concurrent sub-agent executions. Attempting to run multiple sub-agents simultaneously will result in "Too many requests" errors and failed task execution.

## Implementation

When orchestrating spec execution:
- Execute tasks one at a time
- Report progress after each task completion
- Continue to the next task only after the previous one succeeds
