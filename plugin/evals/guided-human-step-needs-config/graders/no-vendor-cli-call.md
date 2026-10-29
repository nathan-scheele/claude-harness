---
type: file_exists
# The vendor CLIs create their call log on the first call: no call at all.
path: .fake-vendors/calls.log
exists: false
---
With the connectors unset, the agent doesn't guess that bin/mailctl or bin/hostctl is the way to read either system.
