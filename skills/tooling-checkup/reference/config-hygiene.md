# Config hygiene: duplicates, memory, hooks, new skills (Phase 7)

The script checks in `config-audit.md` find broken files. This pass keeps
the whole agent setup small and true: each fact in one home, no stale memory,
hooks that still work, and no new skill that repeats one the user already has.

## Back up first

Before any edit to rules, settings, skills, or memory, copy them to a dated
folder, for example `~/.claude/backups/checkup-<date>/` (`CLAUDE.md`,
`settings.json`, the memory folder, and personal skills; skip folders an app
manages). Keep the last four checkup backups and delete older ones.

## One home per fact

For each rule, skill section, and memory, ask: is this its one right home?

| Kind of fact | Home |
|---|---|
| Applies to every task | the always-loaded rules source (shared rules, `AGENTS.md`) |
| A procedure with steps | a skill, linked from the rules in one line |
| Applies to some files only | a path-scoped rule |
| Who the user is, a decision, a pointer | a memory entry |
| Must never break | a hook, with the prose as the reason |

- Search for the same instruction in two places (`rg -n '<key phrase>'`
  across the rules, skills, and memory folders). Keep the best home. Replace
  the other copy with a one-line pointer, or delete it.
- Merge skills whose jobs overlap. Then update every reference to the
  renamed or removed skill.
- Move multi-step procedures out of always-loaded files into skills.
- When two places contradict each other and the intent is unclear, ask in the
  Phase 11 questionnaire. Do not guess.

## Memory hygiene

Skip this when the agent keeps no file memory.

- Re-check each memory that names a file, flag, version, branch, or state.
  Update it, or delete it when it is no longer true.
- Merge duplicate memories. Delete a memory that only restates a rule or a
  skill.
- The memory index has exactly one line per memory file, and every line
  points to a file that exists.
- Remove answered items from any open-questions memory.
- Dates are absolute ("2026-10-25", not "yesterday").

## Hooks

For each hook in the agent settings: does it still run, and is it still
wanted? Pipe-test it with a sample event:

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"echo hi"}}' | <hook command>; echo "exit $?"
```

A hook that errors on every call, or guards a rule that no longer exists, goes
to the questionnaire. Never change hooks or permissions without the user's yes.

## New upstream skills

After `agentbrew sync --pull` (Phase 3), list skills that changed since the
last run (`ls -lt ~/.claude/skills | head`). For each new one:

- Compare its description with the user's own skills. Two skills must not
  claim the same triggers.
- When a new skill covers a personal skill, propose a thin wrapper or the
  removal of the personal copy in the questionnaire.
- When a personal skill holds a generally useful step the upstream skill
  lacks, file it as a fix or task PR to that skill's source repo.

## Best-practice log

When a source page in `config-audit.md` changed a rule, note the date and the
change in one line in the report, and update the audit script or this file in
the same PR.
