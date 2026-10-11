---
type: llm
focus: last_message
weight: 2
---
The repo has no git remote, no CI workflows, and a `test` package script; nothing in it says where it deploys, what dev or sandbox targets exist, how fixtures work or which data connectors it uses.

PASS if the agent's final message asks the operator explicit questions it then waits on (as a numbered list, since the question tool isn't available in this run) for values it could not detect, covering at least: the code host and repo slug, the deploy target or live URL, and the dev or sandbox targets; where a question offers options, exactly one is marked recommended and listed first; and it does not ask the operator what the test command is (it found the `test` script itself; listing it as detected or asking to confirm it is fine).

FAIL if the questions are only implied in prose without a clear list to answer, if a question with options has no recommended option or lists it after another, if any of those three undetectable values is filled in as settled without asking, if the agent asks the operator to supply the test command, or if it carries on as though it had the answers.
