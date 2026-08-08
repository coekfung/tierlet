# AGENTS.md

## Project Structure

- `Tierlet/`: SwiftUI macOS application.
- `TierletDaemon/`: Swift host for the privileged `tierletd` service.
- `TierletCore/`: Rust static library that integrates with EasyTier.
- `TierletIPC/`: XPC contracts shared by the app and daemon.
- `Resources/`: Embedded macOS service resources.
- `Tierlet.xcodeproj/`: Xcode project for the app and daemon targets.

## Reference Repositories

- For reference clones, check `.agent/git/<repo>` first and clone there if missing. This folder is git-ignored.

- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.
- Study how established products solve the problem before designing a solution. Adopt their proven patterns and conventions rather than inventing an approach from scratch.

## Development Workflow

- Read relevant files in full before making wide-ranging changes or performing an audit. Do not rely solely on search snippets.
- Keep changes focused and incremental. Prefer the smallest coherent change that can be reviewed and verified.
- After creating or modifying a test file, run the relevant tests and iterate until they pass.
- Run checks and tests appropriate to the scope of the change. Avoid expensive full builds or test suites unless they are requested or necessary for verification.
- Do not use real external services, credentials, or paid API calls in tests when a local or deterministic test harness is available.
- Write ad hoc scripts to a temporary directory, remove them after use, and do not embed large multi-line scripts directly in shell commands.

## Dependencies and Generated Files

- Treat dependency and lockfile changes as reviewed code. Check existing documentation and types before adding or upgrading a package.
- Use the project's documented package manager and safe installation defaults. Review dependency lifecycle scripts before allowing them to run.
- Update source-of-truth files and regenerate generated artifacts when needed. Do not edit generated files directly.

## Git and Collaboration

- Do not commit unless the user explicitly asks for a commit.
- Stage explicit file paths only, and inspect `git status` before committing.
- Preserve unrelated changes made by the user or other sessions. Do not use destructive commands such as `git reset --hard`, `git clean`, or broad staging commands.
- If a merge or rebase conflict affects a file not modified in the current task, stop and ask for direction.
- Never force-push.

## Documentation and Rule Overrides

- Update the relevant README, documentation, or changelog when a user-facing feature, architecture convention, or release behavior changes.
- If a requested change would intentionally override a project rule or remove functionality that appears intentional, ask for confirmation before proceeding.
