---
name: commit
description: Commit changes with auto-generated message following project conventions
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[instructions]"
---

Commit the current changes by following these steps:

## Step 1: Analyze commit conventions

Run `git log -10 --format="----%n%B"` to retrieve recent commit messages (including body) and analyze:

- **Language**: English, Japanese, or other
- **Conventional Commits**: Whether the format `type(scope): description` is used
  - If yes, list the types used (feat, fix, chore, docs, ci, etc.)
  - If yes, list the scopes used (project-specific patterns)
  - Whether the description starts with lowercase or uppercase
- **Body**: Whether commits include a body (lines after the first line), and if so, what style

If 10 commits are not enough to determine the conventions clearly, fetch more with a larger limit.

## Step 2: Understand current changes

Run `git status` (without -uall flag) and `git diff` (both staged and unstaged) to understand what has changed.

## Step 3: Follow user instructions

If `$ARGUMENTS` is provided, follow those instructions. Examples:
- Specifying which files to commit
- Requesting to split changes into multiple commits
- Any other commit-related instructions

If no arguments are provided, commit all changes in a single commit.

## Step 4: Generate commit message

Based on the conventions discovered in Step 1, generate an appropriate commit message. Match the style exactly — same language, same format, same capitalization, same body style.

## Step 5: Confirm with the user

Present the generated commit message to the user using AskUserQuestion with three options:
- **as-is (commit only)** — approve the message and commit without pushing
- **as-is (commit + push)** — approve the message, commit, and push to remote
- **request changes** — ask for adjustments to the message

Show the full commit message (title and body if applicable) in the question.
If the user requests changes, adjust the message and confirm again with the same three options.

## Step 6: Execute the commit (and push if requested)

After approval:
1. Stage the appropriate files with `git add` (prefer specific files over `git add -A`)
2. Create the commit using HEREDOC format for the message
3. Run `git status` to verify success
4. If the user chose "commit + push", run `git push`

Do NOT skip pre-commit hooks.
If a pre-commit hook fails, fix the issue, re-stage, and create a NEW commit (do not amend).
