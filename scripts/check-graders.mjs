#!/usr/bin/env node
// Re-grades saved eval traces offline, so a grader can be written or fixed
// red/green against real runs instead of rerunning the case.
//
// usage: scripts/check-graders.mjs <case name or case dir> [traces dir] [--llm [--judge-model <model>]]
//
// Traces come from scripts/run-evals.sh (save-eval-traces.sh), by default from
// plugin/evals/results/traces/<case>/<arm>-<n>/. Prints one row per grader and
// one column per run: PASS, FAIL or skip. A `*` marks a cell where the runner,
// grading the same run, reached the other verdict: the grader changed since,
// or this checker reads it differently from the runner.
//
// Checks regex graders on the trace, the last message, mock calls and the
// workspace files save-eval-traces.sh kept (a file the run didn't make reads
// as empty), tool_used and tool_order, with no model calls. With --llm it also
// runs each llm grader's judge three times per run, as the runner does, and
// takes the majority; a split vote shows its PASS count, e.g. FAIL(1/3), and
// the judge's reason for each FAIL vote on a with-plugin run is listed under
// the table. The
// judge is `claude -p` on the runner's default judge model (haiku), or the
// command in CHECK_GRADERS_JUDGE, which reads the prompt on stdin and starts
// its answer with PASS or FAIL. Skips file_exists graders: a saved file
// doesn't say whether the run or the fixture made it.
import { spawnSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const JUDGE_VOTES = 3;

function main() {
  const args = process.argv.slice(2);
  const opts = { llm: false, judgeModel: "haiku" };
  const positional = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--llm") opts.llm = true;
    else if (args[i] === "--judge-model") opts.judgeModel = args[++i];
    else positional.push(args[i]);
  }
  const [caseArg, tracesArg] = positional;
  if (!caseArg) {
    return usage("usage: scripts/check-graders.mjs <case name or case dir> [traces dir] [--llm [--judge-model <model>]]");
  }
  const caseDir = caseArg.includes("/") ? resolve(caseArg) : join(ROOT, "plugin/evals", caseArg);
  const name = basename(caseDir);
  const tracesDir = tracesArg ? resolve(tracesArg) : join(ROOT, "plugin/evals/results/traces", name);
  if (!existsSync(join(caseDir, "graders"))) return usage(`check-graders: no graders/ in ${caseDir}`);
  const runs = existsSync(tracesDir)
    ? readdirSync(tracesDir).filter((d) => existsSync(join(tracesDir, d, "trace.jsonl"))).sort(byArmThenNumber)
    : [];
  if (runs.length === 0) {
    return usage(`check-graders: no saved traces in ${tracesDir}; run scripts/run-evals.sh --case ${name} first`);
  }

  const graders = readdirSync(join(caseDir, "graders"))
    .filter((f) => f.endsWith(".md"))
    .sort()
    .map((f) => {
      const text = readFileSync(join(caseDir, "graders", f), "utf8");
      return { name: f.slice(0, -3), spec: { ...frontmatter(text), body: body(text) } };
    });
  const skipped = new Map();
  const failVotes = [];
  const rows = graders.map((g) => [
    g.name,
    ...runs.map((run) => {
      const dir = join(tracesDir, run);
      const result = grade(g.spec, loadRun(dir), opts);
      if (typeof result === "string") {
        skipped.set(g.name, result);
        return "skip";
      }
      const { pass, label, fails = [] } = typeof result === "boolean" ? { pass: result, label: "" } : result;
      if (!run.startsWith("without")) for (const why of fails) failVotes.push(`${g.name} ${run}: ${why}`);
      const runner = runnerVerdict(dir, g.name);
      return (pass ? "PASS" : "FAIL") + label + (runner !== undefined && runner !== pass ? "*" : "");
    }),
  ]);

  const widths = [Math.max(6, ...graders.map((g) => g.name.length)), ...runs.map((r) => Math.max(r.length, 5))];
  const line = (cells) => cells.map((c, i) => c.padEnd(widths[i])).join("  ").trimEnd();
  console.log(`${name}: ${runs.length} saved runs in ${tracesDir}\n`);
  console.log(line(["grader", ...runs]));
  for (const r of rows) console.log(line(r));
  if (rows.some((r) => r.some((c) => c.endsWith("*")))) {
    console.log("\n* the runner reached the other verdict on this run (grader changed since, or read differently here)");
  }
  for (const [g, why] of skipped) console.log(`skip ${g}: ${why}`);
  if (failVotes.length) {
    console.log("\nthe judge's reason for each FAIL vote on a with-plugin run:");
    for (const v of failVotes) console.log(`  ${v}`);
  }
}

function usage(message) {
  console.error(message);
  process.exitCode = 2;
}

function byArmThenNumber(a, b) {
  const [, armA, nA] = a.match(/^(.*)-(\d+)$/) ?? [, a, 0];
  const [, armB, nB] = b.match(/^(.*)-(\d+)$/) ?? [, b, 0];
  return armA === armB ? nA - nB : armA === "with" ? -1 : armB === "with" ? 1 : armA.localeCompare(armB);
}

function loadRun(dir) {
  const text = readFileSync(join(dir, "trace.jsonl"), "utf8");
  const messages = text.split("\n").filter(Boolean).flatMap((l) => {
    try {
      return [JSON.parse(l)];
    } catch {
      return [];
    }
  });
  const mocks = join(dir, "mock-calls.jsonl");
  const workspace = join(dir, "workspace");
  return {
    text,
    messages,
    mockCalls: existsSync(mocks) ? readFileSync(mocks, "utf8") : "",
    workspace: existsSync(workspace) ? workspace : null,
  };
}

function runnerVerdict(dir, grader) {
  const file = join(dir, "graders.json");
  if (!existsSync(file)) return undefined;
  return JSON.parse(readFileSync(file, "utf8")).find((g) => g.name === grader)?.passed;
}

// true or false, { pass, label } for a judged llm grader, or a string saying
// why the grader can't be checked offline.
function grade(spec, run, opts) {
  switch (spec.type) {
    case "regex":
      return gradeRegex(spec, run);
    case "tool_used": {
      const n = toolCalls(run).filter((c) => matchesCall(c, spec)).length;
      return n >= Number(spec.min ?? 1) && n <= Number(spec.max ?? Infinity);
    }
    case "tool_order": {
      const calls = toolCalls(run);
      const before = calls.findIndex((c) => matchesCall(c, spec.before ?? {}));
      const after = calls.findIndex((c) => matchesCall(c, spec.after ?? {}));
      return before >= 0 && after >= 0 && before < after;
    }
    case "llm":
      return opts.llm ? judge(spec, run, opts) : "llm graders need a model: add --llm to run the judge";
    case "file_exists":
      return "a saved workspace file doesn't say whether the run or the fixture made it";
    default:
      return `unknown grader type ${spec.type}`;
  }
}

function gradeRegex(spec, run) {
  const target = spec.target ?? "last_message";
  let text;
  if (target === "trace") text = run.text;
  else if (target === "mock_calls") text = run.mockCalls;
  else if (target === "last_message") text = lastMessage(run);
  else if (typeof target === "object") {
    if (!run.workspace) return "this run's traces were saved without its workspace files; rerun the case to get them";
    const file = join(run.workspace, String(target.path));
    text = existsSync(file) ? readFileSync(file, "utf8") : "";
  } else return `unknown regex target ${target}`;
  const flags = String(spec.flags ?? "");
  const match = String(spec.match ?? "contains");
  const count = match.match(/^count:(\d+)$/);
  if (count) return (text.match(new RegExp(spec.pattern, flags.includes("g") ? flags : flags + "g")) ?? []).length === Number(count[1]);
  const found = new RegExp(spec.pattern, flags).test(text);
  return match === "not_contains" ? !found : found;
}

// Runs the llm grader's judge JUDGE_VOTES times on what the runner shows it
// (the focus) and takes the majority, or says why it couldn't.
function judge(spec, run, opts) {
  const focus = String(spec.focus ?? "last_message");
  let evidence;
  if (focus === "last_message") evidence = lastMessage(run);
  else if (focus === "mock_calls") evidence = run.mockCalls;
  else if (focus === "trace") {
    // The runner's judge sees only the first and last 12 messages.
    const lines = run.text.split("\n").filter(Boolean);
    evidence = (lines.length > 24 ? [...lines.slice(0, 12), "…", ...lines.slice(-12)] : lines).join("\n");
  } else return `unknown llm focus ${focus}`;
  const prompt =
    "You are grading one run of an automated test of a Claude Code plugin. Apply the grading instructions to the evidence.\n\n" +
    `Grading instructions:\n${spec.body.trim()}\n\nEvidence (${focus}):\n${evidence}\n\n` +
    "Answer with PASS or FAIL as your first word, then one sentence saying why.";
  let passes = 0;
  const fails = [];
  for (let i = 0; i < JUDGE_VOTES; i++) {
    const r = process.env.CHECK_GRADERS_JUDGE
      ? spawnSync(process.env.CHECK_GRADERS_JUDGE, { input: prompt, encoding: "utf8", shell: true, timeout: 120_000 })
      : spawnSync(
          "claude",
          ["-p", "--model", opts.judgeModel, "--tools", "", "--strict-mcp-config", "--no-session-persistence"],
          { input: prompt, encoding: "utf8", timeout: 120_000 },
        );
    const answer = String(r.stdout ?? "").trim();
    const vote = answer.match(/^\W*(PASS|FAIL)\b/i)?.[1]?.toUpperCase();
    if (!vote) return `the judge gave no PASS or FAIL (${String(r.stderr || r.stdout || r.error || "").trim().slice(0, 120)})`;
    if (vote === "PASS") passes++;
    else fails.push(answer.replace(/^\W*FAIL\b\W*/i, "").replace(/\s+/g, " ").slice(0, 300) || "(no reason given)");
  }
  const pass = passes * 2 > JUDGE_VOTES;
  return { pass, label: passes === 0 || passes === JUDGE_VOTES ? "" : `(${passes}/${JUDGE_VOTES})`, fails };
}

function lastMessage(run) {
  const result = run.messages.findLast((m) => m.type === "result" && typeof m.result === "string");
  if (result) return result.result;
  const last = run.messages.findLast((m) => m.type === "assistant" && !m.parent_tool_use_id);
  return (last?.message?.content ?? []).filter((c) => c.type === "text").map((c) => c.text).join("\n");
}

// Every tool call in the trace, the main session's and subagents', in order.
function toolCalls(run) {
  return run.messages.flatMap((m) =>
    m.type === "assistant" && Array.isArray(m.message?.content)
      ? m.message.content.filter((c) => c.type === "tool_use").map((c) => ({ name: c.name, input: JSON.stringify(c.input ?? {}) }))
      : [],
  );
}

// The subagent tool is Agent in grader specs and Task in some traces.
const canonical = (tool) => (tool === "Task" ? "Agent" : tool);

function matchesCall(call, spec) {
  if (canonical(call.name) !== canonical(spec.tool)) return false;
  return spec.input_match === undefined || new RegExp(spec.input_match).test(call.input);
}

// The YAML subset grader frontmatter uses: `key: value` lines, quoted and
// plain scalars, flow maps (`{tool: Bash, input_match: '...'}`), one level of
// indented block map, and comment lines.
function frontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return {};
  const spec = {};
  let block = null;
  for (const raw of m[1].split("\n")) {
    if (/^\s*(#|$)/.test(raw)) continue;
    const kv = raw.match(/^(\s*)([\w-]+):\s*(.*)$/);
    if (!kv) continue;
    const [, indent, key, rest] = kv;
    if (indent && block) {
      block[key] = scalar(rest);
    } else if (rest === "") {
      block = spec[key] = {};
    } else {
      block = null;
      spec[key] = scalar(rest);
    }
  }
  return spec;
}

// A grader file's text after its frontmatter: an llm grader's judge prompt.
function body(text) {
  return text.replace(/^---\n[\s\S]*?\n---\n?/, "");
}

function scalar(src) {
  const s = src.trim();
  if (s.startsWith("'")) return s.slice(1, s.lastIndexOf("'")).replaceAll("''", "'");
  if (s.startsWith('"')) return JSON.parse(s.slice(0, s.lastIndexOf('"') + 1));
  if (s.startsWith("{")) return flowMap(s.slice(1, s.lastIndexOf("}")));
  return s.replace(/\s+#.*$/, "");
}

function flowMap(body) {
  const map = {};
  let i = 0;
  while (i < body.length) {
    const kv = body.slice(i).match(/^\s*([\w-]+):\s*/);
    if (!kv) break;
    i += kv[0].length;
    let j = i;
    if (body[j] === "'" || body[j] === '"') {
      const q = body[j];
      for (j++; j < body.length; j++) {
        if (body[j] === q && q === "'" && body[j + 1] === "'") j++;
        else if (body[j] === "\\" && q === '"') j++;
        else if (body[j] === q) break;
      }
      j++;
    }
    while (j < body.length && body[j] !== ",") j++;
    map[kv[1]] = scalar(body.slice(i, j));
    i = j + 1;
  }
  return map;
}

main();
