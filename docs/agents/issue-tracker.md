# Issue tracker: GitHub Issues

Issues and specs for this repo live in GitHub Issues on `ArmmGh/stashtop`. Use the `gh` CLI.

## Conventions

- The product spec is `docs/SPEC.md` in the repo; larger new specs are published as an issue (and linked from the spec if they change it).
- One issue per ticket. Triage state is a label (see `triage-labels.md`).
- Blocking edges use GitHub's native issue dependencies ("blocked by"), with a `## Blocked by` section in the body as a readable fallback.
- Comments and conversation history live in the issue's comments.

## When a skill says "publish to the issue tracker"

Create a GitHub issue with `gh issue create`, applying the triage label.

## When a skill says "fetch the relevant ticket"

`gh issue view <number> --comments`.
