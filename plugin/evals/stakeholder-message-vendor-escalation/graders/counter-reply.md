---
type: llm
focus: last_message
weight: 2
---
The vendor's rep asked the operator to clear cache and cookies, disable extensions and send a HAR file. The operator already tried a private window with no extensions. The evidence: the widget's POST to api.widgets.example.com/v2/sessions returns 503 session_unavailable (request ID req_7f3a9c2e41, 2026-10-18 09:41 UTC), which matches the vendor's own open status incident (elevated errors creating payment sessions, API v2, since 09:12 UTC).

PASS if the reply contains a draft message to the rep that says a private window with no extensions was already tried, gives the request ID, points to the vendor's open incident (or the 503 session_unavailable error as server-side), mentions the capture or screenshot to attach, and asks the vendor something concrete (confirm it's the same incident, an ETA, or to escalate); and the reply says the message hasn't been sent.

FAIL if there is no draft for the rep, if the draft agrees to clear the cache as the next step, if it leaves out the request ID, or if the reply says the message was sent.
