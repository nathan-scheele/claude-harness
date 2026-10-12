// Checks a live-verifier Bash command and denies anything that could write.
// Reads the PreToolUse input on stdin; prints a deny decision, or nothing to allow.
// Allowlist, not denylist: a command passes only if every part of it is a known
// read (file and git inspection, gh reads, curl GET/HEAD), the Project config's
// fixture reset command, or a data-connector CLI the Project config marks read-only.
// Anything it can't parse is denied.
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const AGENT = /(^|:)live-verifier$/;

const REASON_SUFFIX =
  " live-verifier's Bash is read-only: file and git inspection, gh reads, curl GET/HEAD," +
  " the Project config fixture reset command, and data-connector CLIs it marks read-only." +
  " Use the browser tools for UI checks; report anything that needs a write instead of doing it.";

function main() {
  let input;
  try {
    input = JSON.parse(readFileSync(0, "utf8"));
  } catch {
    return deny("could not read the hook input.");
  }
  if (input.tool_name !== "Bash" || !AGENT.test(String(input.agent_type ?? ""))) return;
  let reason;
  try {
    reason = check(String(input.tool_input?.command ?? ""), loadConfig(input.cwd));
  } catch (err) {
    reason = `guard error (${err.message}).`;
  }
  if (reason) deny(reason);
}

function deny(reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: `Blocked: ${reason}${REASON_SUFFIX}`,
      },
    }) + "\n",
  );
}

// Project config (docs/agents/harness.md): the fixture reset command and the
// CLIs listed as read-only data connectors, found by section heading and key.
function loadConfig(cwd) {
  const config = { reset: null, readOnlyClis: [] };
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
      const m = line.match(/^\s*-\s*\*\*[^*]+\*\*:\s*CLI\s+`([^`]+)`\s*;\s*read-only\s*$/i);
      if (m) config.readOnlyClis.push(m[1].trim().split(/\s+/));
    }
  }
  return config;
}

function check(command, config) {
  if (config.reset && command.trim() === config.reset) return null;
  const parsed = tokenize(command);
  if (typeof parsed === "string") return parsed;
  for (const words of parsed) {
    if (words.length === 0) continue;
    const reason = checkSimple(words, config);
    if (reason) return reason;
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
  "base64", "shasum", "sha256sum", "md5", "md5sum", "cd", "jq",
]);

function checkSimple(words, config) {
  const [prog, ...args] = words;
  if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(prog)) return "environment assignment before a command.";
  if (prog.includes("/")) return `\`${prog}\`: run programs by bare name.`;
  // A variable that makes up a whole word could expand to a flag such as -XPOST.
  if (words.some((w) => w.startsWith("$"))) return "a variable used as a whole argument.";
  for (const cli of config.readOnlyClis) {
    if (cli.every((w, n) => words[n] === w)) return null;
  }
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

function checkCurl(args) {
  const SHORT_BOOL = new Set([..."sSLfIiGkv46g"]);
  const SHORT_VALUE = new Set([..."HAwmuberYyXod"]);
  const LONG_BOOL = new Set([
    "--silent", "--show-error", "--location", "--fail", "--fail-with-body", "--head", "--include",
    "--get", "--insecure", "--verbose", "--compressed", "--globoff", "--http1.1", "--http2",
    "--no-progress-meter", "--ipv4", "--ipv6", "--location-trusted", "--raw", "--no-buffer", "--path-as-is",
  ]);
  const LONG_VALUE = {
    "--header": "", "--user-agent": "", "--write-out": "", "--max-time": "", "--connect-timeout": "",
    "--retry": "", "--retry-delay": "", "--retry-max-time": "", "--user": "", "--oauth2-bearer": "",
    "--cookie": "", "--referer": "", "--range": "", "--url": "", "--max-redirs": "",
    "--request": "X", "--output": "o", "--data": "d", "--data-urlencode": "d", "--data-raw": "d", "--data-ascii": "d",
  };
  const opts = [];
  for (let n = 0; n < args.length; n++) {
    const a = args[n];
    if (a.startsWith("--")) {
      if (LONG_BOOL.has(a)) {
        if (a === "--get") opts.push(["G"]);
        continue;
      }
      if (!(a in LONG_VALUE)) return `\`curl ${a}\` is not allowed.`;
      if (n + 1 >= args.length) return `\`curl ${a}\` needs a value.`;
      opts.push([LONG_VALUE[a], args[++n]]);
    } else if (a.startsWith("-") && a.length > 1) {
      for (let k = 1; k < a.length; k++) {
        const ch = a[k];
        if (SHORT_BOOL.has(ch)) {
          if (ch === "G") opts.push(["G"]);
          continue;
        }
        if (!SHORT_VALUE.has(ch)) return `\`curl -${ch}\` is not allowed.`;
        const value = k + 1 < a.length ? a.slice(k + 1) : args[++n];
        if (value === undefined) return `\`curl -${ch}\` needs a value.`;
        opts.push([ch, value]);
        break;
      }
    }
  }
  const get = opts.some(([o]) => o === "G");
  for (const [o, value] of opts) {
    if (o === "X" && !["GET", "HEAD"].includes(value.toUpperCase())) return `\`curl -X ${value}\` is a write.`;
    if (o === "o" && value !== "/dev/null") return "`curl -o` writes a file.";
    if (o === "d" && !get) return "`curl -d` sends a POST (add -G to send it as a query string).";
  }
  return null;
}

main();
