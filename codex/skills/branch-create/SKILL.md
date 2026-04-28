---
name: branch-create
description: Create a working branch with a repository-appropriate name. Use when the user asks to start work on a new branch.
metadata:
  short-description: Create a branch that matches repo naming conventions
---

# Branch Create

Create a working branch from the current branch.

## Workflow

1. Inspect recent local branches. If that is not enough to infer naming conventions, inspect recently merged PR branch names as well.
2. Identify the current branch. Treat it as the base branch unless the user says otherwise.
3. If the user supplied a branch name and it already matches the repository's conventions, use it as-is. Otherwise derive a branch name from the user's description.
4. Show the base branch and proposed branch name to the user and ask for approval. If the user wants changes, revise and confirm again.
5. After approval, create the branch and verify that the checked-out branch is the expected one.

## Notes

- Default to a conservative convention such as `type/kebab-case-description` only when the repository does not provide a clearer pattern.
- Do not create the branch until the user has approved the final name.
