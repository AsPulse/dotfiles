---
name: issue-create
description: Create a GitHub issue that matches the repository's conventions. Use when the user asks to open, draft, or prepare an issue.
metadata:
  short-description: Create a GitHub issue with approved metadata
---

# Issue Create

Create a GitHub issue by first gathering repository conventions, then confirming every detail with the user before creating anything.

## Workflow

### 1. Investigate silently

Before asking questions, gather the repository context:

- identify the current repository
- inspect recent issues to understand title, body, and label conventions
- discover available labels, milestones, projects, and issue types when those features are enabled
- inspect issue templates if the repository uses them

If you cannot identify the repository from the current directory, ask the user which repository to use.

### 2. Confirm the issue with the user

Use the investigation results to guide the conversation.

1. Clarify the issue topic if the request is still too vague.
2. Propose a title and body that match the repository's conventions.
3. Ask only about metadata that the repository actually supports and that seems relevant:
   - labels
   - milestone
   - assignee
   - issue type
   - parent issue
   - blocking relationships
   - project
4. Present a complete summary of the final issue and ask for explicit approval.

### 3. Create the issue

After approval:

1. Create the issue using the simplest command that supports the approved metadata.
2. If advanced metadata requires GraphQL, use that path carefully.
3. Apply any approved follow-up actions such as project assignment or blocking links.
4. Report the created issue URL and the applied metadata.

## Notes

- Do not create the issue until the user has approved the final title, body, and metadata.
- Skip unsupported metadata quietly rather than turning missing repository features into user-facing noise.
- Prefer fewer, higher-signal questions over a long interview.
