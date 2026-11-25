# ADR 0007: AGENTS.md and markdown task files drive the work

- **Status:** accepted (2026-11-25)

## Decision

The project's working memory lives in the repo:
- `AGENTS.md` holds the rules, as the single source of truth for every AI tool. Tool-specific files only point to it.
- `tasks/BACKLOG.md` lists ordered tasks with acceptance criteria.
- `tasks/PROGRESS.md` is the handoff log, newest first.
- `tasks/QUESTIONS.md` holds decisions for the owner.
- `docs/` holds the plan and design.

## Why

- Any AI harness can continue the project with only a clone of the repo.
- No dependence on a particular tool's memory or chat history.
- Small, testable tasks with explicit acceptance criteria make AI-written code reviewable by a non-programmer owner.

## Consequences

- Agents must update BACKLOG and PROGRESS in every task (Definition of done).
- The owner may mirror the backlog in GitHub Issues or a project board, but the markdown files stay authoritative.
