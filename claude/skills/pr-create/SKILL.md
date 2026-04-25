---
name: pr-create
description: Create a pull request with an appropriate title, opening in browser
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[base-branch]"
---

Create a pull request for the current branch by following these steps:

1. Run `git log` and `git diff` against the base branch to understand all changes (default base: main or master, or use `$ARGUMENTS` if provided)
2. Check if the current branch has unpushed commits (`git status -sb` or compare with remote tracking branch). If there are unpushed changes, ask the user for confirmation before pushing them.
3. Run `gh pr list --state merged --limit 5 --json number,title,body` to check the repository's existing PR title and description style
4. Analyze the commits and diff to generate an appropriate, concise PR title and description that matches the repository's conventions
5. Present the generated title and description to the user using AskUserQuestion with options to approve as-is or request changes. If the user requests changes, revise accordingly and confirm again.
6. Run: `gh pr create --title "<generated title>" --body "<generated description>" --web` (if `$ARGUMENTS` was provided, also pass `--base $ARGUMENTS`)

Keep the title short and descriptive, following the style of existing PRs in the repository.
