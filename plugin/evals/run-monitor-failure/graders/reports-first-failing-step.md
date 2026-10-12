---
type: llm
focus: last_message
weight: 2
---
CI run 2001 for PR #7 failed. In the `test` job, step 3 "Run tests" failed first: the test "drops empty tags" got `['a', '']` instead of `['a']`, because `normalizeTags` in src/tags.js keeps empty tags. Step 4 "Upload coverage" failed afterwards only because no coverage file was written. That makes the failure a real defect in the code, not a reporting artifact.

PASS if the final message (1) names "Run tests" in the test job as the first failing step (mentioning Upload coverage as a consequence is fine, naming it as the cause is not), (2) describes the failing assertion or the empty-tags bug, (3) says the failure is real (a genuine bug, not flaky or an artifact), and (4) offers to file an issue for it as a question or numbered options the operator answers, without claiming one was filed.

FAIL if any of the four is missing, if it names "Upload coverage" as the failure, if it calls the failure flaky or an artifact, or if it says an issue was already created.
