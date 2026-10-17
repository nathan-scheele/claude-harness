// PreToolUse checks. Reads the hook input on stdin; prints a deny decision, or
// nothing to allow.
//
// Harness browser page tools, for every agent: pages open in the background and
// are never brought to the front (S10).
//
// The read-only subagents' Bash (live-verifier, data-digest): denies anything
// that could write. Allowlist, not denylist: a command passes only if every
// part of it is a known read (file and git inspection, gh reads, curl
// GET/HEAD), the Project config's fixture reset command (live-verifier only),
// or a read through a Project config data connector: any command of a
// read-only CLI, or a listed read of a read-write one. Anything it can't parse
// is denied.
//
// data-digest's other tools: it inherits the session's tools, because the
// operator's connector servers can't be named in its frontmatter in advance.
// An MCP call passes only if it is on a Project config connector server that is
// read-only, or is one of a read-write server's listed reads. A Write passes
// only if it creates a new data file (an extract) outside hidden directories.
// Any other tool passes only if it is on a short list of reads (DIGEST_READS).
import { existsSync, readFileSync } from "node:fs";
import { extname, isAbsolute, join, relative, resolve, sep } from "node:path";

const AGENT = /(^|:)(live-verifier|data-digest)$/;
const BROWSER = "mcp__plugin_harness_browser__";

const EXTRACT_TYPES = [".csv", ".tsv", ".json", ".jsonl", ".ndjson", ".txt"];
// Tools data-digest may use unchecked. Bash, Write and MCP tools are checked;
// anything else is denied.
const DIGEST_READS = new Set(["Read", "Grep", "Glob", "WebFetch", "WebSearch", "ToolSearch", "Skill", "TodoWrite"]);

const BASH_READS = "Bash is read-only: file and git inspection, gh reads, curl GET/HEAD,";
const HAND_BACK = " Hand back any write as a PREPARED, NOT EXECUTED payload instead of running it.";
const BASH_REASON = {
  "live-verifier":
    ` live-verifier's ${BASH_READS} the Project config fixture reset command, and reads through its data connectors.` +
    " Use the browser tools for UI checks; report anything that needs a write instead of doing it.",
  "data-digest": ` data-digest's ${BASH_READS} and reads through the Project config data connectors.${HAND_BACK}`,
};
const MCP_REASON =
  " data-digest calls only the MCP servers the Project config lists under Data connectors:" +
  " any tool of a read-only one, and only the listed reads of a read-write one." +
  ` If a read you need isn't listed, report BLOCKED.${HAND_BACK}`;
const WRITE_REASON =
  ` data-digest writes only extracts: a new ${EXTRACT_TYPES.join(", ")} file at the path the caller gave,` +
  " never over an existing file or into a hidden directory.";
const TOOL_REASON =
  ` data-digest reads, digests and hands back: ${[...DIGEST_READS].join(", ")}, read-only Bash,` +
  ` connector MCP reads, and Write for a new extract.${HAND_BACK}`;
const FOCUS_REASON = " The Harness browser must never take the operator's focus (S10).";

function main() {
  let input;
  try {
    input = JSON.parse(readFileSync(0, "utf8"));
  } catch {
    return deny("could not read the hook input.", "");
  }
  const tool = String(input.tool_name ?? "");
  if (tool.startsWith(BROWSER)) {
    const reason = checkFocus(tool.slice(BROWSER.length), input.tool_input ?? {});
    if (reason) return deny(reason, FOCUS_REASON);
  }
  const agent = String(input.agent_type ?? "").match(AGENT)?.[2];
  const guard = agent && guardFor(agent, tool);
  if (!guard) return;
  let reason;
  try {
    reason = guard.check(input.tool_input ?? {}, input.cwd);
  } catch (err) {
    reason = `guard error (${err.message}).`;
  }
  if (reason) deny(reason, guard.why);
}

// The check a read-only subagent's tool call must pass, or null if it needs none.
function guardFor(agent, tool) {
  if (tool === "Bash") {
    return {
      why: BASH_REASON[agent],
      check: (input, cwd) => {
        const config = loadConfig(cwd);
        // Resetting fixtures is live-verifier's job.
        return check(String(input.command ?? ""), agent === "live-verifier" ? config : { ...config, reset: null });
      },
    };
  }
  if (agent !== "data-digest" || DIGEST_READS.has(tool)) return null;
  if (tool.startsWith("mcp__")) return { why: MCP_REASON, check: (_, cwd) => checkMcp(tool, loadConfig(cwd)) };
  if (tool === "Write") return { why: WRITE_REASON, check: (input, cwd) => checkWrite(String(input.file_path ?? ""), cwd) };
  return { why: TOOL_REASON, check: () => `\`${tool}\` is not on data-digest's tool list.` };
}

function deny(reason, why) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: `Blocked: ${reason}${why}`,
      },
    }) + "\n",
  );
}

function checkFocus(tool, input) {
  if (tool === "new_page" && input.background !== true) return "open pages with `background: true`.";
  if (tool === "select_page" && input.bringToFront === true) return "don't pass `bringToFront: true`.";
  return null;
}

// Project config (docs/agents/harness.md): the fixture reset command and the
// data connectors, found by section heading and key. A connector line (format
// in skills/setup-harness/project-config.md) allows the whole CLI or server
// when it is read-only, else only its listed reads (words after the CLI
// command, or tool names on the server). A read-write connector without reads
// allows nothing.
function loadConfig(cwd) {
  const config = { reset: null, cliReads: [], mcpReads: [] };
  const file = cwd ? join(cwd, "docs/agents/harness.md") : null;
  if (!file || !existsSync(file)) return config;
  let section = "";
  for (const line of readFileSync(file, "utf8").split("\n")) {
    const heading = line.match(/^##\s+(.+?)\s*$/);
    if (heading) {
      section = heading[1].toLowerCase();
      continue;
    }
    if (section === "fixtures") {
      const m = line.match(/^\s*-\s*\*\*Reset\*\*:\s*`([^`]+)`\s*$/);
      if (m) config.reset = m[1].trim();
    } else if (section === "data connectors") {
      const m = line.match(
        /^\s*-\s*\*\*[^*]+\*\*:\s*(CLI|MCP server)\s+`([^`]+)`[^;]*;\s*(read-only|read-write)\s*(?:;\s*reads:\s*(.*?))?\s*$/i,
      );
      if (!m) continue;
      const [, kind, name, access, listed] = m;
      const reads = access.toLowerCase() === "read-only" ? [""] : [...(listed ?? "").matchAll(/`([^`]+)`/g)].map((r) => r[1]);
      for (const read of reads) {
        if (kind.toUpperCase() === "CLI") config.cliReads.push(`${name} ${read}`.trim().split(/\s+/));
        else config.mcpReads.push([name.trim(), read.trim()]);
      }
    }
  }
  return config;
}

function check(command, config) {
  if (config.reset && command.trim() === config.reset) return null;
  const parsed = tokenize(command);
  if (typeof parsed === "string") return parsed;
  // After a `cd`, a connector CLI spelled as a relative path could be a
  // different program.
  let moved = false;
  for (const words of parsed) {
    if (words.length === 0) continue;
    const reason = checkSimple(words, moved ? { ...config, cliReads: config.cliReads.filter((r) => !r[0].includes("/")) } : config);
    if (reason) return reason;
    moved ||= words[0] === "cd";
  }
  return null;
}

// Splits a command line into simple commands (on | || && ; and newlines), each a
// list of unquoted words. Returns a reason string for anything it won't allow:
// command or process substitution, unquoted expansions, subshells, background
// jobs, heredocs, and output redirection anywhere but /dev/null.
function tokenize(src) {
  const commands = [[]];
  let word = null;
  const words = () => commands[commands.length - 1];
  const endWord = () => {
    if (word !== null) words().push(word);
    word = null;
  };
  const newCommand = () => {
    endWord();
    commands.push([]);
  };
  const readTarget = (from) => {
    let j = from;
    while (src[j] === " " || src[j] === "\t") j++;
    let target = "";
    while (j < src.length && !/[\s|&;<>()]/.test(src[j])) target += src[j++];
    return [target, j];
  };

  let i = 0;
  while (i < src.length) {
    const c = src[i];
    if (c === "'") {
      const end = src.indexOf("'", i + 1);
      if (end < 0) return "unterminated quote.";
      word = (word ?? "") + src.slice(i + 1, end);
      i = end + 1;
    } else if (c === '"') {
      let j = i + 1;
      let text = "";
      for (; j < src.length && src[j] !== '"'; j++) {
        const d = src[j];
        if (d === "\\" && j + 1 < src.length) {
          text += src[++j];
        } else if (d === "`") {
          return "command substitution.";
        } else if (d === "$") {
          const rest = src.slice(j + 1);
          const simple = rest.match(/^([A-Za-z_][A-Za-z0-9_]*|\{[A-Za-z_][A-Za-z0-9_]*\})/);
          if (simple) {
            text += "$" + simple[0];
            j += simple[0].length;
          } else if (/^[({]/.test(rest)) {
            return "command substitution or parameter expansion.";
          } else {
            text += "$";
          }
        } else {
          text += d;
        }
      }
      if (j >= src.length) return "unterminated quote.";
      word = (word ?? "") + text;
      i = j + 1;
    } else if (c === "\\") {
      if (src[i + 1] === "\n") {
        i += 2;
        continue;
      }
      word = (word ?? "") + (src[i + 1] ?? "");
      i += 2;
    } else if (c === " " || c === "\t") {
      endWord();
      i++;
    } else if (c === "\n" || c === ";") {
      newCommand();
      i++;
    } else if (c === "|") {
      newCommand();
      i += src[i + 1] === "|" || src[i + 1] === "&" ? 2 : 1;
    } else if (c === "&") {
      if (src[i + 1] === "&") {
        newCommand();
        i += 2;
      } else if (src[i + 1] === ">") {
        const [target, j] = readTarget(i + (src[i + 2] === ">" ? 3 : 2));
        if (target !== "/dev/null") return "output redirection to a file.";
        i = j;
      } else {
        return "background job.";
      }
    } else if (c === ">") {
      if (word !== null && !/^\d+$/.test(word)) return "output redirection to a file.";
      word = null; // a leading fd number belongs to the redirection
      let j = i + 1;
      if (src[j] === ">" || src[j] === "|") j++;
      if (src[j] === "&") {
        const m = src.slice(j + 1).match(/^(\d+|-)/);
        if (!m) return "output redirection to a file.";
        i = j + 1 + m[0].length;
        continue;
      }
      if (src[j] === "(") return "process substitution.";
      const [target, k] = readTarget(j);
      if (target !== "/dev/null") return "output redirection to a file.";
      i = k;
    } else if (c === "<") {
      if (src[i + 1] === "<") return "heredoc or here-string.";
      if (src[i + 1] === "(") return "process substitution.";
      endWord();
      const [target, j] = readTarget(i + 1);
      if (!target) return "input redirection without a file.";
      i = j;
    } else if (c === "`") {
      return "command substitution.";
    } else if (c === "$") {
      return src[i + 1] === "(" ? "command substitution." : "unquoted variable expansion.";
    } else if (c === "(" || c === ")") {
      return "subshell.";
    } else if (c === "#" && word === null) {
      while (i < src.length && src[i] !== "\n") i++;
    } else {
      word = (word ?? "") + c;
      i++;
    }
  }
  endWord();
  for (const ws of commands) if (ws.includes("{") || ws.includes("}")) return "command grouping.";
  return commands;
}

const READERS = new Set([
  "cat", "head", "tail", "grep", "egrep", "fgrep", "wc", "cut", "tr", "ls", "pwd",
  "date", "echo", "printf", "basename", "dirname", "realpath", "stat", "diff", "cmp",
  "comm", "sleep", "true", "false", "test", "[", "which", "column", "nl", "od",
  "shasum", "sha256sum", "md5", "md5sum", "cd", "jq",
]);

function checkSimple(words, config) {
  const [prog, ...args] = words;
  if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(prog)) return "environment assignment before a command.";
  // A variable that makes up a whole word could expand to a flag such as -XPOST.
  if (words.some((w) => w.startsWith("$"))) return "a variable used as a whole argument.";
  // A connector CLI runs as the Project config spells it, path and all.
  for (const read of config.cliReads) {
    if (read.every((w, n) => words[n] === w)) return null;
  }
  if (prog.includes("/")) return `\`${prog}\`: run programs by bare name.`;
  if (READERS.has(prog)) return null;
  switch (prog) {
    case "rg":
      return args.some((a) => a.startsWith("--pre")) ? "`rg --pre` runs a program." : null;
    case "sort":
      return args.some((a) => /^-[^-]*o/.test(a) || a.startsWith("--output") || a.startsWith("--compress"))
        ? "`sort -o` writes a file."
        : null;
    case "uniq":
      return positionals(args, ["-f", "-s", "-w"]).length > 1 ? "`uniq` with an output file." : null;
    case "find":
      return args.some((a) => /^-(delete|exec|execdir|ok|okdir|fprint|fprint0|fprintf|fls)$/.test(a))
        ? "`find` that deletes, runs commands or writes files."
        : null;
    case "git":
      return checkGit(args);
    case "gh":
      return checkGh(args);
    case "curl":
      return checkCurl(args);
    default:
      return `\`${prog}\` is not on the read-only command list.`;
  }
}

// An extract is a new data file. Hidden path parts are checked from the repo
// down when the file is inside it (so a repo under a dot directory still
// works), else along the whole path.
function checkWrite(file, cwd) {
  if (!file) return "a Write without a file path.";
  const base = cwd || process.cwd();
  const path = resolve(base, file);
  const inside = relative(base, path);
  const parts = (inside && !inside.startsWith("..") && !isAbsolute(inside) ? inside : path).split(sep);
  if (parts.some((part) => part.startsWith("."))) return "a write into a hidden directory or file.";
  if (!EXTRACT_TYPES.includes(extname(path).toLowerCase())) return "a write that isn't a data extract.";
  if (existsSync(path)) return "a write over an existing file.";
  return null;
}

// Tools are named mcp__<server>__<tool>, with the server as the Project config
// spells it.
function checkMcp(tool, config) {
  const reads = config.mcpReads.filter(([server]) => tool.startsWith(`mcp__${server}__`));
  if (reads.length === 0) return `\`${tool}\` is not on a Project config data connector.`;
  return reads.some(([server, read]) => read === "" || tool === `mcp__${server}__${read}`)
    ? null
    : `\`${tool}\` is not a listed read of its connector.`;
}

function positionals(args, valueFlags) {
  const out = [];
  for (let n = 0; n < args.length; n++) {
    if (valueFlags.includes(args[n])) n++;
    else if (!args[n].startsWith("-") || args[n] === "-") out.push(args[n]);
  }
  return out;
}

const GIT_READS = new Set([
  "log", "show", "diff", "status", "rev-parse", "ls-files", "ls-tree", "ls-remote",
  "blame", "describe", "merge-base", "cat-file", "for-each-ref", "shortlog", "grep",
  "rev-list", "show-ref", "name-rev",
]);
const GIT_BRANCH_FLAGS = new Set([
  "--show-current", "-a", "--all", "-r", "--remotes", "-v", "-vv", "--verbose", "--list", "-l",
]);

function checkGit(args) {
  let n = 0;
  while (n < args.length && args[n].startsWith("-")) {
    if (args[n] === "-C") n += 2;
    else if (args[n] === "--no-pager") n++;
    else return `\`git ${args[n]}\` is not allowed.`;
  }
  const [sub, ...rest] = args.slice(n);
  if (!sub) return null;
  if (rest.some((a) => a.startsWith("--output") || a === "--ext-diff" || a === "-O" || a.startsWith("--open-files"))) {
    return "git output to a file or external program.";
  }
  const ok = (() => {
    if (GIT_READS.has(sub)) return true;
    if (sub === "branch") return rest.every((a) => GIT_BRANCH_FLAGS.has(a));
    if (sub === "remote") return rest.length === 0 || ["-v", "--verbose", "get-url", "show"].includes(rest[0]);
    if (sub === "config") return ["--get", "--get-all", "--get-regexp", "--list", "-l"].includes(rest[0]);
    if (sub === "stash") return ["list", "show"].includes(rest[0]);
    if (sub === "worktree") return rest[0] === "list";
    if (sub === "tag") return rest.length === 0 || (["-l", "--list"].includes(rest[0]) && !rest.some((a) => /^-[dafsmFu]$|^--(delete|force)/.test(a)));
    return false;
  })();
  return ok ? null : `\`git ${sub}\` can change the repo.`;
}

const GH_READS = {
  issue: ["view", "list", "status"],
  pr: ["view", "list", "status", "checks", "diff"],
  run: ["view", "list", "watch"],
  repo: ["view"],
  release: ["view", "list"],
  workflow: ["view", "list"],
  search: ["issues", "prs", "repos", "code", "commits"],
  label: ["list"],
  auth: ["status"],
  cache: ["list"],
};

function checkGh(args) {
  const [sub, action, ...rest] = args;
  if (args.some((a) => a === "--web" || a === "-w")) return "`gh --web` opens a browser window.";
  if (sub === "api") return checkGhApi(args.slice(1));
  if (sub === "status" && !action) return null;
  return GH_READS[sub]?.includes(action) ? null : `\`gh ${args.slice(0, 2).join(" ")}\` is not a read.`;
}

function checkGhApi(args) {
  const VALUE = { "-X": "method", "--method": "method", "-f": "field", "--raw-field": "field", "-F": "field",
    "--field": "field", "-H": "", "--header": "", "-q": "", "--jq": "", "-t": "", "--template": "",
    "--hostname": "", "--cache": "", "-p": "", "--preview": "", "--input": "input" };
  const BOOL = new Set(["--paginate", "--slurp", "-i", "--include", "--silent", "--verbose"]);
  let method = null;
  const fields = [];
  const endpoints = [];
  for (let n = 0; n < args.length; n++) {
    let a = args[n];
    let value;
    if (BOOL.has(a)) continue;
    const long = a.match(/^(--[a-z-]+)=(.*)$/s);
    const short = a.match(/^(-[XfFHqtp])(.+)$/s);
    if (long && long[1] in VALUE) [a, value] = [long[1], long[2]];
    else if (short) [a, value] = [short[1], short[2]];
    else if (a in VALUE) value = args[++n];
    else if (a.startsWith("-")) return `\`gh api ${a}\` is not allowed.`;
    else {
      endpoints.push(a);
      continue;
    }
    if (value === undefined) return `\`gh api ${a}\` needs a value.`;
    if (VALUE[a] === "method") method = value.toUpperCase();
    if (VALUE[a] === "field") fields.push(value);
    if (VALUE[a] === "input") return "`gh api --input` sends a request body.";
  }
  if (endpoints[0] === "graphql") {
    if (fields.some((f) => /\bmutation\b/i.test(f) || /^[^=]*=@/.test(f))) return "GraphQL mutation.";
    return method && method !== "POST" && method !== "GET" ? `\`gh api -X ${method}\` is a write.` : null;
  }
  if (method && method !== "GET" && method !== "HEAD") return `\`gh api -X ${method}\` is a write.`;
  if (fields.length && method !== "GET") return "`gh api` with fields sends a POST.";
  return null;
}

// curl options it allows, by what they mean for the check: "get" (-G, send data
// as a query string), "method", "output", "data", or "" (harmless). A boolean
// option takes no value.
const CURL_SHORT_BOOL = { s: "", S: "", L: "", f: "", I: "", i: "", G: "get", k: "", v: "", 4: "", 6: "", g: "" };
const CURL_SHORT_VALUE = { H: "", A: "", w: "", m: "", u: "", b: "", e: "", r: "", Y: "", y: "",
  X: "method", o: "output", d: "data" };
const CURL_LONG_BOOL = Object.fromEntries([
  "--silent", "--show-error", "--location", "--fail", "--fail-with-body", "--head", "--include",
  "--insecure", "--verbose", "--compressed", "--globoff", "--http1.1", "--http2",
  "--no-progress-meter", "--ipv4", "--ipv6", "--location-trusted", "--raw", "--no-buffer", "--path-as-is",
].map((o) => [o, ""]).concat([["--get", "get"]]));
const CURL_LONG_VALUE = {
  "--header": "", "--user-agent": "", "--write-out": "", "--max-time": "", "--connect-timeout": "",
  "--retry": "", "--retry-delay": "", "--retry-max-time": "", "--user": "", "--oauth2-bearer": "",
  "--cookie": "", "--referer": "", "--range": "", "--url": "", "--max-redirs": "",
  "--request": "method", "--output": "output",
  "--data": "data", "--data-urlencode": "data", "--data-raw": "data", "--data-ascii": "data",
};

function checkCurl(args) {
  const opts = []; // [kind, value]
  for (let n = 0; n < args.length; n++) {
    const a = args[n];
    if (a.startsWith("--")) {
      if (a in CURL_LONG_BOOL) {
        opts.push([CURL_LONG_BOOL[a]]);
        continue;
      }
      if (!(a in CURL_LONG_VALUE)) return `\`curl ${a}\` is not allowed.`;
      if (n + 1 >= args.length) return `\`curl ${a}\` needs a value.`;
      opts.push([CURL_LONG_VALUE[a], args[++n]]);
    } else if (a.startsWith("-") && a.length > 1) {
      for (let k = 1; k < a.length; k++) {
        const ch = a[k];
        if (ch in CURL_SHORT_BOOL) {
          opts.push([CURL_SHORT_BOOL[ch]]);
          continue;
        }
        if (!(ch in CURL_SHORT_VALUE)) return `\`curl -${ch}\` is not allowed.`;
        const value = k + 1 < a.length ? a.slice(k + 1) : args[++n];
        if (value === undefined) return `\`curl -${ch}\` needs a value.`;
        opts.push([CURL_SHORT_VALUE[ch], value]);
        break;
      }
    }
  }
  const get = opts.some(([kind]) => kind === "get");
  for (const [kind, value] of opts) {
    if (kind === "method" && !["GET", "HEAD"].includes(value.toUpperCase())) return `\`curl -X ${value}\` is a write.`;
    if (kind === "output" && value !== "/dev/null") return "`curl -o` writes a file.";
    if (kind === "data" && !get) return "`curl -d` sends a POST (add -G to send it as a query string).";
  }
  return null;
}

main();
