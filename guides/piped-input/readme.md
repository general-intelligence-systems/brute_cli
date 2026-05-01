# Piped Input

Pipe text into brute for non-interactive use.

## Basic Piping

```sh
echo "Refactor the database connection pool" | brute
cat instructions.txt | brute
```

## Combining Pipe with Prompt

```sh
git diff HEAD~1 | brute "Review this diff for bugs"
```

## Code Review

```sh
git diff main | brute "Review this diff. Flag bugs, security issues, and style problems."
```

## Explore a Codebase

```sh
brute -d ~/projects/unfamiliar-repo "Explain how authentication works in this project"
```
