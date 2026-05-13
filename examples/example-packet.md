# Review packet

## Summary
Add a JWT auth middleware in `src/auth/middleware.ts` that validates Bearer tokens against the user table and attaches `req.user` for downstream handlers.

## Specific focus questions
- Does the rate-limit handling do anything if the user is anonymous?
- Is token expiry checked correctly in all paths?
- Any obvious injection risk in how we look up the user?

## Changed files
```
 src/auth/middleware.ts        | 58 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 src/auth/index.ts             |  3 ++
 tests/auth/middleware.test.ts | 41 +++++++++++++++++++++++++++++++++++++++++
 3 files changed, 102 insertions(+)
```

## Diff
```diff
diff --git a/src/auth/middleware.ts b/src/auth/middleware.ts
new file mode 100644
index 0000000..0e1a2b3
--- /dev/null
+++ b/src/auth/middleware.ts
@@ -0,0 +1,58 @@
+import { Request, Response, NextFunction } from "express";
+import jwt from "jsonwebtoken";
+import { db } from "../db";
+
+export async function requireAuth(req: Request, res: Response, next: NextFunction) {
+  const header = req.headers.authorization;
+  if (!header || !header.startsWith("Bearer ")) {
+    return res.status(401).json({ error: "missing token" });
+  }
+  const token = header.slice(7);
+  try {
+    const payload = jwt.verify(token, process.env.JWT_SECRET!) as { sub: string };
+    const user = await db.query(`SELECT * FROM users WHERE id = '${payload.sub}'`);
+    if (!user) return res.status(401).json({ error: "invalid token" });
+    (req as any).user = user;
+    next();
+  } catch (e) {
+    return res.status(401).json({ error: "invalid token" });
+  }
+}
```
