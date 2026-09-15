---
description: Audit the project for security issues using available repository-native tooling
agent: plan
---

Perform a read-only security audit for the requested scope: $ARGUMENTS

First discover the repository's manifests, configured scanners, dependency audit commands, and relevant security checks. Run only tools that are actually available. If no scanner or Snyk integration is configured, state that limitation clearly and provide the closest evidence-based audit without claiming a Snyk result. Report findings with severity, file or dependency references, remediation, commands run, and residual uncertainty.
