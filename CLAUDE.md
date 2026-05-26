# Project Claude Code Rules

## Project conventions
- Follow existing project structure, naming, and style.
- Reuse existing project utilities, helpers, fixtures, and test patterns before adding new code.
- Put extraction code in the most reusable project-approved location.
- Do not introduce new folders or abstractions unless needed.

## Testing conventions
- Prefer existing project fixture formats and test helpers.
- Prefer fixture-based tests over mocks when practical.
- If a dry run is used to capture data, keep extraction code out of production paths unless explicitly intended.
- Remove temporary extraction code after fixture generation unless it is clearly reusable.

## Review conventions
- Keep summaries short.
- Highlight behavior changes and risky files first.
- Call out project-specific cleanup or follow-up items if needed.
