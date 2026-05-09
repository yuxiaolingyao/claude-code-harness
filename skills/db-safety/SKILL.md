---
name: db-safety
description: Database operation safety review. Checks DDL/DML for destructive patterns, missing WHERE clauses, and migration risks.
model: auto
context: fork
allowed-tools: Read, Grep, Glob
---

# Database Safety Review

Review database-related code for destructive or risky operations. Language-agnostic, covers ORM and raw SQL.

## Review Checklist

### Destructive Operations
- `DROP TABLE` / `DROP DATABASE` / `DROP SCHEMA` — is there a confirmation or backup step?
- `TRUNCATE` — is this intentional? Does it need a safety gate?
- `DELETE FROM` without `WHERE` — will this wipe the entire table?
- `ALTER TABLE ... DROP COLUMN` — irreversible data loss, is there a rollback plan?
- `drizzle-kit push:force` or `prisma db push --force` — forced schema sync can drop tables

### Migration Safety
- Are migrations reversible? (check for `down` migration logic)
- Is the migration targeting the correct environment? (not accidentally running on production)
- Are there `IF EXISTS` / `IF NOT EXISTS` guards?
- For large tables: is there a batch/online migration strategy? (not locking the table for minutes)

### ORM Patterns
- `sequelize.sync({ force: true })` — drops all tables on startup
- `typeorm.synchronize: true` in production config
- Bulk `updateMany` / `deleteMany` without filters
- Raw query concatenation (`db.query("SELECT * FROM users WHERE id = " + userId)`)

### Data Integrity
- CASCADE deletes — are the downstream effects understood?
- Foreign key violations during migration order
- Unique constraint changes that may fail on existing data

## Output Format

| Severity | Category | File:Line | Issue | Fix |
|----------|----------|-----------|-------|-----|
| 🔴 Critical | Destructive | ... | ... | ... |
| 🟡 Warning | Migration | ... | ... | ... |
| 🔵 Note | Data Loss | ... | ... | ... |

End with risk summary: SAFE / NEEDS_REVIEW / DANGEROUS.
