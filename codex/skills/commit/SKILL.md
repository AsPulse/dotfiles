---
name: commit
description: Create a git commit that matches the repository's conventions. Use when the user asks to commit changes or prepare a commit message.
metadata:
  short-description: Commit changes with a convention-matching message
---

# Commit

Create a commit for the current changes while matching the repository's conventions.

## Workflow

1. Inspect recent commits and identify the repository's message conventions:
   - language
   - whether Conventional Commits are used
   - common types and scopes
   - capitalization and body style
2. Inspect the current changes with `git status` and relevant diffs. Review staged and unstaged changes separately.
3. If the user gave extra instructions, follow them. For example:
   - commit only certain files
   - split the work into multiple commits
   - emphasize a specific intent in the message
4. Draft the commit message so it matches the repository's conventions exactly.
5. Show the full proposed commit message to the user and ask for approval. If the user wants edits, revise and confirm again.
6. After approval, stage only the intended files, create the commit, and verify success with `git status`.
7. If the branch is ahead of its remote after the commit, ask whether the user wants to push.

## Notes

- Prefer staging specific files over sweeping adds when the requested scope is limited.
- Do not skip pre-commit hooks.
- If a pre-commit hook fails, fix the issue, restage the affected files, and create a new commit instead of amending unless the user explicitly asks otherwise.
- Do not push automatically; ask first.
