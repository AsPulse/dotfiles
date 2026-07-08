---
name: pr-rename
description: Rename a pull request and/or revise its description based on the current commits
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[PR number or revision instructions]"
---

Rename a pull request and/or revise its description by following these steps:

1. Identify the target PR. If `$ARGUMENTS` starts with a number, treat it as the PR number; otherwise resolve from the current branch with `gh pr view --json number,title,body,headRefName,baseRefName,url,commits`. If no PR is found for the current branch, ask the user which PR to edit.
2. Check the repository's existing PR title and description style by running these in parallel:
   - `gh pr list --state merged --limit 10 --json number,title,body` for the repository's overall conventions
   - `gh pr list --state merged --author @me --limit 5 --json number,title,body` for your own recent PRs
3. If past PRs follow an issue-closing convention (e.g. `- close #N`, `closes #N`, `fixes #N`), check whether the existing PR body already includes a close reference and whether one should be added or updated:
   - Look through the conversation history for issue numbers that were referenced or implied during the work
   - If unclear, run `gh issue list --state open --limit 20 --json number,title,body` and check whether any open issue matches the changes
   - Include or update the close reference in the PR body following the repo's exact convention
4. Based on the PR's commits and diff, generate an updated title and/or body that matches the repository's conventions. Preserve any user-authored content in the existing body unless `$ARGUMENTS` explicitly asks to rewrite it from scratch.
5. Present the proposed changes (old vs new for both title and body) to the user using AskUserQuestion. Options: `update title and body` / `update title only` / `update body only` / `request changes`. If the user requests changes, revise accordingly and confirm again.
6. After approval, run `gh pr edit <number> --title "<new title>" --body "<new body>"` (omit `--title` or `--body` for fields that are not being updated; use HEREDOC for the body to preserve formatting).
7. Run `gh pr view <number> --json title,body,url` to verify the result and report the URL.
