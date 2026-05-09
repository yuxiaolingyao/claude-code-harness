---
name: simplify
description: Review changed code for reuse, quality, and efficiency. Finds redundancy, over-abstraction, and dead code.
context: fork
allowed-tools: Read, Grep, Glob
---

# Simplify

Review code changes for unnecessary complexity. The goal: minimum code that solves the problem.

## Checklist

### Redundancy
- Are there duplicate code blocks that should be extracted?
- Are there repeated patterns with only minor variations?
- Are there unused imports, variables, or functions?

### Over-Abstraction
- Are there abstractions used only once? (inline them)
- Are there interfaces with a single implementation? (remove them)
- Is there inheritance that could be composition?
- Is there future-proofing for requirements that don't exist?

### Verbosity
- Can the same logic be expressed in fewer lines without losing clarity?
- Are there unnecessary intermediate variables?
- Are there redundant comments that restate the code?
- Are there manual getter/setter pairs that a library/framework could generate?

### Dead Code
- Are there functions/methods never called?
- Are there feature flags always on/off?
- Are there TODO comments that will never be addressed?

## Rules

1. Three similar lines is better than a premature abstraction
2. Don't DRY until the third duplication
3. Remove don't comment-out
4. Prefer deleting unused code over deprecation warnings

## Output

List each finding with file:line, issue, and recommended action. End with a summary: X issues found, Y lines saveable.
