# Contributing

Start with an issue for changes that affect the architecture or deployment process. Small fixes can go directly to a pull request.

## Working on a change

1. Create a branch from `main` with a short, descriptive name.
2. Make a focused change. Update the relevant runbook and diagram if behavior changes.
3. Run the application tests and Terraform checks listed in the [README](README.md#tests).
4. Open a pull request explaining the problem, the change and what you tested.

Use clear commit messages such as `Fix ALB health check documentation`. Keep unrelated changes in separate pull requests.

## Infrastructure changes

Explain any new permissions, recurring costs, resource replacements or migration steps. Attach only sanitized plan summaries; Terraform plans and state can contain secrets. Live AWS testing must use an approved account and budget.

When changing a dependency, update the relevant requirements or provider lock file and run the checks again. Do not remove lock files to hide resolution errors.

## Reporting problems

Include reproduction steps, tool versions, expected behavior and the actual error. Remove account identifiers, hostnames and sensitive values from logs. For vulnerabilities, follow [SECURITY.md](SECURITY.md).

## Review checklist

- The change has a clear purpose and stays within scope.
- Tests cover changed behavior where appropriate.
- Documentation matches the implementation.
- No credentials, state, plan files or local configuration are included.
- Any AWS results are actual observations, with untested behavior identified.
