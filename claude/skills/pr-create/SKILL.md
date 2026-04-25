---
name: pr-create
description: Create a pull request with an appropriate title, opening in browser
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[base-branch]"
---

Create a pull request for the current branch by following these steps:

1. Run `git log` and `git diff` against the base branch to understand all changes (default base: main or master, or use `$ARGUMENTS` if provided)
2. Check if the current branch has unpushed commits (`git status -sb` or compare with remote tracking branch). If there are unpushed changes, ask the user for confirmation before pushing them.
3. Check the repository's existing PR title and description style by running these in parallel:
   - `gh pr list --state merged --limit 10 --json number,title,body` for the repository's overall conventions
   - `gh pr list --state merged --author @me --limit 5 --json number,title,body` for your own recent PRs
4. If past PRs follow an issue-closing convention (e.g. `- close #N`, `closes #N`, `fixes #N`), find any issue this PR should close:
   - Look through the conversation history for issue numbers that were referenced or implied during the work
   - If unclear, run `gh issue list --state open --limit 20 --json number,title,body` and check whether any open issue matches the changes
   - Include the close reference in the PR body following the repo's exact convention
5. Analyze the commits and diff to generate an appropriate, concise PR title and description that matches the repository's conventions
6. Present the generated title and description to the user using AskUserQuestion with options to approve as-is or request changes. If the user requests changes, revise accordingly and confirm again.
7. Run: `gh pr create --title "<generated title>" --body "<generated description>" --web` (if `$ARGUMENTS` was provided, also pass `--base $ARGUMENTS`)

Keep the title short and descriptive, following the style of existing PRs in the repository.
