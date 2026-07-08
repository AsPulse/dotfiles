---
name: issue-create
description: Create a GitHub issue by interviewing the user and following repository conventions
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[rough idea or topic]"
---

Create a GitHub issue by interviewing the user and following repository conventions.

This skill has three distinct phases. **Each phase must fully complete before moving to the next.**

1. **Investigation** — Silently gather repository conventions and available metadata
2. **Interview** — Ask the user all necessary questions and get explicit approval of every detail
3. **Execution** — Create the issue exactly as approved

**CRITICAL: Do NOT run any `gh issue create` or `gh api graphql` mutation until the user has approved every detail in Phase 2. Phase 3 must not begin until the user gives final approval.**

---

## Phase 1: Investigation (silent — no user interaction)

Gather all information needed to guide the interview. Do not ask the user anything yet.

### 1a: Identify the repository

- Run `gh repo view --json nameWithOwner,id -q '.nameWithOwner'` to get the current repo
- If not in a git repo or no remote, ask the user which repo to use (the only exception to "no questions in Phase 1")

### 1b: Analyze issue conventions

Run `gh issue list --limit 20 --state all --json number,title,body,labels,milestone` and analyze:

- **Language**: English, Japanese, or other
- **Title format**: Conventional Commit-like (`feat(scope): ...`), prefix-based (`[bug] ...`, `scope: ...`), or freeform
- **Body style**: Whether issues typically have a body, and if so, what structure (template, checklist, freeform, or empty)
- **Labels**: What labels exist and how they are used

### 1c: Discover available metadata

Run these in parallel. If any fail (feature not enabled, no permission), silently skip.

- `gh label list --json name,description --limit 50`
- `gh api repos/{owner}/{repo}/milestones --jq '.[].title'`
- `gh api graphql -f query='query { repository(owner:"{owner}",name:"{repo}") { issueTypes(first:20) { nodes { id name } } } }'`
- `gh project list --owner {owner} --json title,number --limit 10`

### 1d: Check issue templates

- `ls .github/ISSUE_TEMPLATE/` or `gh api repos/{owner}/{repo}/contents/.github/ISSUE_TEMPLATE`
- If templates exist, read them to understand expected structure

---

## Phase 2: Interview (all decisions made here — nothing executed)

Use AskUserQuestion to gather every detail from the user. Adapt questions based on what was discovered in Phase 1.

If `$ARGUMENTS` is provided, use it as the starting point. Skip questions already answered by the arguments.

### 2a: Core content

Ask about the core issue. Adapt your question to what you already know from `$ARGUMENTS`:

- **What is this issue about?** (if not clear from arguments)
- **Issue type**: Based on the repo's conventions, ask about the type. If the repo uses issue types (Feature/Bug/Task), present those. If it uses label-based categorization, present the relevant labels. If neither, skip.

### 2b: Title and body proposal

Based on the user's description and the repo's conventions:

- **Generate a title** matching the repo's naming convention (format, language, casing)
- **Generate a body** matching the repo's style (or leave empty if that's the convention)
- Present both to the user for approval/adjustment using AskUserQuestion

### 2c: Metadata (ask only what's relevant)

Only ask about metadata that the repository actually uses. Skip anything that has no existing data or is clearly irrelevant. Present sensible defaults and let the user confirm or change.

For each of the following, only ask if the repo has the feature configured:

- **Labels**: Suggest appropriate labels based on the issue content and existing label conventions. Present as a multi-select.
- **Milestone**: Only if milestones exist. Suggest the most likely one or let the user pick.
- **Assignee**: Ask if the user wants to assign someone (suggest `@me` as default)
- **Issue type**: Only if the repo has issue types enabled (the GraphQL feature). Suggest based on content.
- **Parent issue**: Ask if this is a sub-issue of an existing issue. If yes, get the parent issue number.
- **Blocked by / Blocking**: Ask if this issue has dependency relationships with other issues.
- **Project**: Only if projects exist for the owner. If so, ask which project (if any) to add it to.

Combine related questions into single AskUserQuestion calls (up to 4 questions per call) to minimize back-and-forth. Skip metadata entirely if the repo has no labels, milestones, projects, or issue types.

### 2d: Final confirmation

Present a complete summary of everything that will be created:

- Title
- Body (or "(empty)" if none)
- All metadata (labels, milestone, assignee, issue type, parent, blocking, project)

Ask the user to approve with AskUserQuestion. Options: "Create this issue" / "Edit something".
If the user wants edits, loop back to the relevant sub-step. **Do not proceed to Phase 3 until the user selects "Create this issue".**

---

## Phase 3: Execution (only after full approval)

### 3a: Create the issue

Choose the creation method based on what features are needed:

**Simple case** (no issue type, no parent, no blocking relationships) — use `gh issue create`:

```bash
gh issue create --title "title" --body "$(cat <<'EOF'
body content here
EOF
)" --label "label1" --label "label2" --milestone "name" --assignee "@me" --project "Name"
```

**Complex case** (issue type, parent, or blocking relationships needed) — use GraphQL `createIssue` mutation:

```bash
gh api graphql -f query='
  mutation {
    createIssue(input: {
      repositoryId: "REPO_NODE_ID"
      title: "title"
      body: "body"
      labelIds: ["LA_..."]
      milestoneId: "MI_..."
      assigneeIds: ["MDQ6..."]
      issueTypeId: "IT_..."
      parentIssueId: "I_..."
    }) {
      issue { number url }
    }
  }
'
```

### 3b: Post-creation setup

If blocking relationships were approved:

```bash
gh api graphql -f query='
  mutation {
    addBlockedBy(input: {
      issueId: "CREATED_ISSUE_ID"
      blockingIssueId: "BLOCKING_ISSUE_ID"
    }) { clientMutationId }
  }
'
```

If a project was specified and needs item-add:

```bash
gh project item-add PROJECT_NUMBER --owner OWNER --url ISSUE_URL
```

### 3c: Report result

Show the user the created issue URL and a summary of what was set.
