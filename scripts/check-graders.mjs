#!/usr/bin/env node
// Re-grades saved eval traces offline, with no model calls, so a grader can be
// written or fixed red/green against real runs instead of rerunning the case.
//
// usage: scripts/check-graders.mjs <case name or case dir> [traces dir]
//
// Traces come from scripts/run-evals.sh (save-eval-traces.sh), by default from
// plugin/evals/results/traces/<case>/<arm>-<n>/. Prints one row per grader and
// one column per run: PASS, FAIL or skip. A `*` marks a cell where the runner,
// grading the same run, reached the other verdict: the grader changed since,
// or this checker reads it differently from the runner.
//
// Checks regex graders on the trace, the last message and mock calls,
// tool_used and tool_order. Skips llm graders (they need a model), and
// file_exists and file-target regex graders (workspace files aren't saved).
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

function main() {
  const [caseArg, tracesArg] = process.argv.slice(2);
  if (!caseArg) return usage("usage: scripts/check-graders.mjs <case name or case dir> [traces dir]");
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
    .map((f) => ({ name: f.slice(0, -3), spec: frontmatter(readFileSync(join(caseDir, "graders", f), "utf8")) }));
  const skipped = new Map();
  const rows = graders.map((g) => [
    g.name,
    ...runs.map((run) => {
      const dir = join(tracesDir, run);
      const verdict = grade(g.spec, loadRun(dir));
      if (typeof verdict === "string") {
        skipped.set(g.name, verdict);
        return "skip";
      }
      const runner = runnerVerdict(dir, g.name);
      return (verdict ? "PASS" : "FAIL") + (runner !== undefined && runner !== verdict ? "*" : "");
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
  return { text, messages, mockCalls: existsSync(mocks) ? readFileSync(mocks, "utf8") : "" };
}

function runnerVerdict(dir, grader) {
  const file = join(dir, "graders.json");
  if (!existsSync(file)) return undefined;
  return JSON.parse(readFileSync(file, "utf8")).find((g) => g.name === grader)?.passed;
}

// true or false, or a string saying why the grader can't be checked offline.
function grade(spec, run) {
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
      return "llm graders need a model";
    case "file_exists":
      return "workspace files aren't saved with the trace";
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
  else if (typeof target === "object") return "file targets read workspace files, and workspace files aren't saved";
  else return `unknown regex target ${target}`;
  const flags = String(spec.flags ?? "");
  const match = String(spec.match ?? "contains");
  const count = match.match(/^count:(\d+)$/);
  if (count) return (text.match(new RegExp(spec.pattern, flags.includes("g") ? flags : flags + "g")) ?? []).length === Number(count[1]);
  const found = new RegExp(spec.pattern, flags).test(text);
  return match === "not_contains" ? !found : found;
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
