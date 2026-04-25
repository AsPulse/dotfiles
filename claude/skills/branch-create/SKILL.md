---
name: branch-create
description: Create a working branch from the current branch with a conventional name
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[branch description or name]"
---

Create a working branch by following these steps:

1. Run `git branch -a --sort=-committerdate` to list recent branches and analyze naming conventions (pattern, separator, word casing, types used). If there are not enough branches to determine conventions, also run `gh pr list --state merged --limit 20 --json headRefName -q '.[].headRefName'` to check branch names from past PRs. If still unclear, default to `type/kebab-case-description`.
2. Check the current branch with `git branch --show-current` — this is the base branch.
3. If `$ARGUMENTS` looks like a valid branch name matching the repo's conventions, use it as-is. If it's a description, generate a name following the conventions. If no arguments, ask the user what the branch is for using AskUserQuestion.
4. Present the base branch and proposed branch name to the user using AskUserQuestion with options to approve or request changes.
5. After approval, run `git checkout -b <branch-name>` and `git branch --show-current` to verify.
