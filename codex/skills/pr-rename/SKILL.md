---
name: pr-rename
description: Rename a pull request and/or revise its description so it matches the repository's conventions and the current commits. Use when the user asks to rename, retitle, or rewrite the body of a PR.
metadata:
  short-description: Rename a PR or revise its description
---

# PR Rename

Update the title and/or body of an existing pull request so they match the repository's conventions and the actual changes on the branch.

## Workflow

1. Identify the target PR. If the user supplied a PR number, use it. Otherwise resolve the PR from the current branch. If no PR is found, ask the user which PR to edit.
2. Fetch the existing PR's title, body, head/base branches, URL, and commits so you can reason about what the PR actually contains.
3. Inspect at least 3-5 recently merged PRs in the repository to infer title and body conventions. Also inspect a few of your own recently merged PRs (`--author @me`) so you can match your past style when the repository allows variation between authors. Pay attention to whether bodies are usually empty, very short, structured, or limited to issue-closing tags such as `Closes #123`.
4. If past PRs follow an issue-closing convention, check whether the existing PR body already includes a close reference and whether one should be added or updated:
   - look through the conversation history for issue numbers that were referenced or implied during the work
   - if unclear, list recent open issues and check whether any of them matches the changes
   - apply the close reference using the repository's exact convention
5. Draft an updated title and/or body that match the observed conventions. Preserve any user-authored content already in the body unless the user explicitly asks to rewrite it from scratch.
6. Show the old vs new title and body to the user and ask for approval. Offer the user the choice of updating only the title, only the body, or both. If the user wants changes, revise and confirm again.
7. After approval, edit the PR with the appropriate fields. Omit any field the user did not approve for update. Use a HEREDOC for the body so its formatting is preserved.
8. Verify the result by reading the PR back, and report the URL.

## Notes

- Do not edit the PR until the user has approved the final title and body.
- Repository convention is more important than generic PR best practices. Prefer matching the local pattern over adding standard sections such as summaries, test plans, or checklists.
- Do not silently rewrite user-authored body content. If the existing body has hand-written notes, preserve them unless the user has clearly asked to replace the body.
