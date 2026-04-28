---
name: branch-rename
description: Rename the current branch to a name that matches the repository's conventions and the actual work. Use when the user asks to rename a branch.
metadata:
  short-description: Rename the current branch to fit repo conventions
---

# Branch Rename

Rename the current branch based on its existing commits and any planned upcoming work.

## Workflow

1. Gather context:
   - identify the current branch name (the one to rename)
   - inspect recent local branch names to infer naming conventions
   - if local branches are not enough, also inspect recently merged PR branch names
   - skim the commits already on this branch to understand what it actually contains
2. Check whether the branch already has an upstream (i.e. has been pushed). If it has, warn the user before doing anything else and ask how to handle the remote. Offer at minimum:
   - cancel
   - rename only the local branch and leave the old remote branch alone
   - rename locally, push the new name, and delete the old remote branch
   If the user picks cancel, stop here.
3. Derive a new branch name:
   - if the user supplied a name and it already matches the repository's conventions, use it as-is
   - if the user supplied a description, generate a name from it
   - if the user gave no input, infer the intent from the existing commits, factoring in any upcoming work the user has hinted at; if the direction is still ambiguous, ask
4. Show the old name, the proposed new name, and (if applicable) the chosen remote handling to the user and ask for approval. If the user wants changes, revise and confirm again.
5. After approval:
   - rename the local branch
   - if the user chose to update the remote, push the new name with upstream tracking and delete the old remote branch
6. Verify that the checked-out branch is the expected one, and (if the remote was updated) that the branch is tracking the new remote correctly.

## Notes

- Default to a conservative convention such as `type/kebab-case-description` only when the repository does not provide a clearer pattern.
- Do not rename until the user has approved the final name.
- Never delete the old remote branch unless the user has explicitly approved that path.
