# Review response

## Verdict
BLOCK

## Reason
There's a SQL injection in the user lookup and a couple of correctness issues that should be addressed before merging.

## Findings

### Bugs
- `src/auth/middleware.ts:13` — `jwt.verify` may throw if `JWT_SECRET` is undefined. The `!` postfix silences TypeScript but doesn't protect runtime. Fail-fast at startup with a clear error if the env var is missing.
- `src/auth/middleware.ts:14` — `db.query` returns an array of rows even for ID lookups. `if (!user)` will always be falsy because an empty array is truthy. Use `user.length === 0` or fetch a single row.

### Security
- `src/auth/middleware.ts:14` — **SQL injection.** `payload.sub` is interpolated directly into the SQL string. Use a parameterized query: `db.query('SELECT * FROM users WHERE id = ?', [payload.sub])`. A maliciously crafted JWT (or a JWT minted with a leaked secret) could exfiltrate or modify the database.
- `src/auth/middleware.ts:13` — `jwt.verify` with no algorithm whitelist is vulnerable to the algorithm-confusion class of attacks. Pass `{ algorithms: ['HS256'] }` (or whatever you actually use).

### Quality / style
- `src/auth/middleware.ts:16` — `(req as any).user` defeats the type system. Extend the Express `Request` interface via module augmentation in a `types.d.ts` so `req.user` is typed everywhere.

### Suggestions (non-blocking)
- The middleware does not handle rate limiting at all (per your question). If anonymous abuse is a concern, add a separate IP-based rate-limit middleware before this one.
- Consider returning `WWW-Authenticate: Bearer` on 401 responses for spec-compliance.

## What I checked
- The diff of `src/auth/middleware.ts`
- The contract between this middleware and how `req.user` is used in downstream handlers (inferred — those handlers weren't in the packet)

## What I did NOT check
- The actual SQL schema for the `users` table
- The test file `tests/auth/middleware.test.ts` — mentioned in the file list but not shown in the diff
- Whether `JWT_SECRET` rotation is handled anywhere
- Performance under high request volume
