---
name: branch-rename
description: Rename the current branch based on existing commits and planned work, following repo conventions
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[new branch description or name]"
---

Rename the current branch by following these steps:

1. Gather context by running these in parallel:
   - `git branch --show-current` to get the current branch name (the one to rename).
   - `git branch -a --sort=-committerdate` to analyze naming conventions (pattern, separator, word casing, types used). If there are not enough local branches to determine conventions, also run `gh pr list --state merged --limit 20 --json headRefName -q '.[].headRefName'` to check branch names from past PRs. If still unclear, default to `type/kebab-case-description`.
   - `git log --oneline -20` (against the likely base branch if obvious) to see what commits this branch already contains.
2. Check whether the branch has been pushed to a remote with `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`. **If the branch has an upstream (already pushed)**, warn the user using AskUserQuestion before doing anything else. Put `cancel` as the FIRST option:
   - **cancel** — abort and do nothing
   - **rename locally only** — rename the local branch but leave the old remote branch in place
   - **rename and update remote** — rename locally, push the new name, and delete the old remote branch
   - If the user picks `cancel`, stop here.
3. Generate a new branch name:
   - If `$ARGUMENTS` looks like a valid branch name matching the repo's conventions, use it as-is.
   - If `$ARGUMENTS` is a description, generate a name following the conventions.
   - If no arguments, infer the intent from the existing commits. If the user has hinted at upcoming work, factor that in too. If the planned direction is ambiguous, ask the user with AskUserQuestion.
4. Present the old name, the proposed new name, and (if applicable) the chosen remote handling to the user using AskUserQuestion with options to approve or request changes.
5. After approval:
   - Local rename: `git branch -m <new-name>`
   - If the user chose `rename and update remote`: `git push origin -u <new-name>` then `git push origin --delete <old-name>`.
6. Verify with `git branch --show-current` and (if remote was updated) `git status -sb`.
