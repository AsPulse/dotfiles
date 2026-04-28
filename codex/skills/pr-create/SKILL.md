---
name: pr-create
description: Create a GitHub pull request for the current branch. Use when the user asks to open, prepare, or draft a PR.
metadata:
  short-description: Create a pull request from the current branch
---

# PR Create

Create a pull request for the current branch.

## Workflow

1. Determine the base branch. Use the user's argument if they provided one. Otherwise prefer `main` or `master`, or infer the default branch from the repository.
2. Inspect the work before proposing anything. Review recent commits and the diff against the base branch so you understand the scope and intent of the change.
3. Check whether the current branch has unpushed commits. If pushing is required before the PR can be created, explain that clearly and ask for approval before pushing.
4. Review at least 3-5 recently merged PRs so you can infer the repository's title and description conventions. Pay attention to whether PR bodies are usually empty, very short, structured, or limited to issue-closing tags such as `Closes #123`. Also inspect a few of your own recently merged PRs (`--author @me`) so you can match your past style when the repository allows variation between authors.
5. Summarize the observed PR body convention to yourself before drafting. Match that convention in the proposal: if bodies are usually empty, keep the body empty; if they are usually minimal, keep it minimal; if they usually include issue-closing tags or another repeated pattern, preserve that pattern. Do not add extra explanatory sections just because they are common elsewhere.
6. Draft a concise PR title and body that follow the repository's conventions.
7. Show the proposed title and body to the user and ask for approval. Briefly state the convention you observed so the user can confirm the match. If the user wants changes, revise and confirm again.
8. After approval, create the PR with `gh pr create --web`.
9. Report the created PR URL or any blocking condition.

## Notes

- Do not create the PR until the user has approved the title and body.
- If the repository is not ready for a PR because the branch is unpublished or authentication is missing, explain the blocker before taking further action.
- Keep the title short and descriptive unless the repository clearly prefers a longer format.
- Repository convention is more important than generic PR best practices. Prefer matching the local pattern over adding standard sections such as summaries, test plans, or checklists.
