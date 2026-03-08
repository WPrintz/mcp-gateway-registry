# Claude Coding Rules

Coding standards for the MCP Gateway Registry. Full examples and verbose patterns are in `CLAUDE.md.bak`.

## Core Principles
- Write code with minimal complexity for maximum maintainability and clarity
- Choose simple, readable solutions over clever or complex implementations
- Prioritize code that any team member can confidently understand, modify, and debug

## Pull Request Evaluation

When evaluating pull requests for merge, adopt the **Merge Specialist** persona defined in [TEAM.md](TEAM.md). A PR with failing tests should NEVER be approved for merge.

## Technology Stack
- **Package management**: Always use `uv` and `pyproject.toml` -- never `pip` directly
- **Data processing**: `polars` (not `pandas`)
- **Web APIs**: `fastapi` (not `flask`)
- **Formatting/linting**: `ruff`
- **Type checking**: `mypy`
- **Testing**: `pytest`
- **Security scanning**: `bandit`

## Code Style
- Private functions: prefix with `_`, place at top of file
- Functions: max 30-50 lines, two blank lines between definitions
- One function parameter per line
- Type annotations: use Python 3.10+ syntax (PEP 604/585) -- `X | None` not `Optional[X]`, `list[dict]` not `List[Dict]`
- Use Pydantic `BaseModel` for class definitions
- `main()` should orchestrate control flow, not implement business logic
- Multi-line imports: `from module import (func1, func2)`
- Constants at file top, not inside functions. Use `constants.py` for many.
- Google-style docstrings for all public functions
- Avoid deep nesting (max 2-3 levels); use early returns
- Use `@lru_cache` where appropriate for expensive computations
- Validate after changes: `uv run python -m py_compile <file>` (Python), `bash -n <file>` (shell)

### Logging
Use this format across the project:
```python
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s,p%(process)s,{%(filename)s:%(lineno)d},%(levelname)s,%(message)s",
)
```
Pretty-print dicts in log messages: `json.dumps(data, indent=2, default=str)`

## Error Handling
- Use specific exception types, never bare `except:`
- Fail fast with clear, actionable error messages
- Use custom exceptions for domain-specific errors
- Always log exceptions with context

## Testing
```bash
# Run all tests (parallel)
uv run pytest tests/ -n 8

# Prerequisites: MongoDB must be running (docker ps | grep mongo)
# Tests auto-set DOCUMENTDB_HOST=localhost, use mongodb-ce backend
```
- All unit tests must pass before PR submission
- Minimum 35% coverage required (configured in pyproject.toml)
- CI runs via GitHub Actions on PRs to `main`/`develop`
- See [.github/workflows/registry-test.yml](.github/workflows/registry-test.yml) for CI config

## Security
- Validate and sanitize all user inputs; use Pydantic for request/response models
- Never log sensitive information (passwords, tokens, PII)
- Never hardcode secrets -- use environment variables
- Use parameterized queries for database operations
- Never bind servers to `0.0.0.0` unless necessary; prefer `127.0.0.1`
- `# nosec` comments must always include clear justification
- Run scans: `uv run bandit -r src/`

### Subprocess Rules
- Always use list form, never `shell=True`
- Always add timeout
- Handle `TimeoutExpired` and `CalledProcessError`

### SQL Rules
- Always use parameterized queries for values
- Validate table/column names against allowlists
- Return query + params as `tuple[str, tuple]`

### Security Review Checklists

**Subprocess:** list form (no `shell=True`), timeout specified, error handling (`TimeoutExpired`, `CalledProcessError`), commands hardcoded (no user input), `# nosec` justified

**SQL:** parameterized queries for all values, table/column validated against allowlists, no string formatting for values, `# nosec` documented

## Development Workflow
```bash
# Format + lint + security + types + tests
uv run ruff check --fix . && uv run ruff format . && uv run bandit -r src/ && uv run mypy src/ && uv run pytest
```

### Ruff Configuration (see `pyproject.toml`)
- Target: Python 3.10+, line length: 100
- Auto-enforces PEP 585 (`UP006`), PEP 604 (`UP007`), import sorting (`I001`)

## Scratchpad
`.scratchpad/` is gitignored and holds temporary planning docs, design sketches, session notes, and task tracking. Not for long-term documentation.

## Platform Naming
- Always "Amazon Bedrock" (never "AWS Bedrock")

## GitHub Commit and PR Guidelines
- Never include "Generated with [Claude Code]" or "Co-Authored-By: Claude" messages
- Keep commit messages clean, professional, focused on the "why"
- No emojis anywhere: code, docs, logs, shell scripts, comments

## GitHub Issue Management
- Always check available labels with `gh label list` before creating issues
- Only use existing labels; suggest new ones in comments

## Docker
- Always `set -e` in scripts
- Login to ECR before pushing; create repository if it doesn't exist
- For ARM64: add QEMU setup before build

## Federated Registry Implementation Workflow

When implementing the federated registry feature, follow this 3-agent workflow for each sub-feature:

### Agent Roles
1. **Writer Agent** - Implement code following CLAUDE.md standards
2. **Reviewer Agent** - Analyze time/space complexity, evaluate trade-offs, check production readiness
3. **Tester Agent** - Write property-based tests, integration tests, validate acceptance criteria

### Workflow Per Sub-Feature
1. Writer implements -> 2. Reviewer analyzes -> 3. Writer addresses feedback -> 4. Tester validates -> 5. Update plan if new scope -> 6. Final validation

### Quality Gates
- All acceptance criteria verified with tests
- Reviewer approved production readiness
- Property-based tests cover invariants
- No TODO or FIXME left unaddressed
- Code compiles without warnings
- Existing tests still pass

## CloudFormation Workshop

The `cloudformation/aws-ecs/` directory contains the AWS ECS/Fargate deployment of the MCP Gateway Registry, packaged as a Workshop Studio workshop.

- **Porting checklist:** [`cloudformation/aws-ecs/docs/porting-checklist.md`](cloudformation/aws-ecs/docs/porting-checklist.md) -- lessons learned, carry-forward fixes (template-level vs app-level), open issues, and upgrade checklists from the v1.0.12 -> v1.0.15 -> v1.0.16 porting effort. **Read this before starting a new version branch.**
