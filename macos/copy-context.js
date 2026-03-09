#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const cp = require("child_process");

const PROFILES = {
  default: [".js", ".ts", ".py", ".kt"],
  web: [".js", ".ts", ".jsx", ".tsx", ".css", ".scss", ".html", ".vue", ".svelte"],
  android: [".kt", ".java", ".xml", ".gradle", ".kts"],
  python: [".py", ".pyi", ".toml", ".yaml", ".yml", ".ini"],
  allcode: [
    ".js", ".ts", ".jsx", ".tsx",
    ".py", ".pyi",
    ".kt", ".java", ".xml", ".gradle", ".kts",
    ".go", ".rs", ".c", ".h", ".cpp", ".hpp",
    ".cs", ".php", ".rb", ".swift", ".scala",
    ".html", ".css", ".scss", ".sql",
    ".json", ".toml", ".yaml", ".yml", ".md"
  ],
};

const DEFAULT_IGNORE_DIRS = new Set([
  ".git",
  ".svn",
  ".hg",
  "node_modules",
  "dist",
  "build",
  ".next",
  ".nuxt",
  ".output",
  "coverage",
  ".turbo",
  ".cache",
  ".parcel-cache",
  "venv",
  ".venv",
  "__pycache__",
  ".mypy_cache",
  ".pytest_cache",
  ".ruff_cache",
  ".idea",
  ".vscode",
  "out",
  "target",
  ".gradle",
  ".DS_Store",
]);

const DEFAULT_IGNORE_FILE_SUFFIXES = [
  ".min.js",
  ".bundle.js",
  ".map",
  ".lock",
  ".log",
  ".class",
  ".jar",
  ".war",
  ".apk",
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".pdf",
  ".zip",
  ".tar",
  ".gz",
  ".wasm",
];

const DEFAULTS = {
  profile: "default",
  stdout: false,
  gitTracked: false,
  gitChanged: false,
  maxFileBytes: 200 * 1024,
  maxTotalBytes: 2 * 1024 * 1024,
  maxFiles: 200,
  showSkipped: true,
  includeHidden: false,
  targetDir: null,
};

function parseArgs(argv) {
  const args = {
    ...DEFAULTS,
    extensions: new Set(PROFILES[DEFAULTS.profile]),
    extraIgnoreDirs: new Set(),
    extraIgnoreSuffixes: [],
    contextIgnore: true,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];

    if (arg === "--stdout") {
      args.stdout = true;
      continue;
    }

    if (arg === "--git-tracked") {
      args.gitTracked = true;
      continue;
    }

    if (arg === "--git-changed") {
      args.gitChanged = true;
      continue;
    }

    if (arg === "--no-skipped") {
      args.showSkipped = false;
      continue;
    }

    if (arg === "--include-hidden") {
      args.includeHidden = true;
      continue;
    }

    if (arg === "--no-contextignore") {
      args.contextIgnore = false;
      continue;
    }

    if (arg === "--profile" && argv[i + 1]) {
      const profile = argv[++i].trim();
      if (!PROFILES[profile]) {
        fail(`Unknown profile: ${profile}. Valid profiles: ${Object.keys(PROFILES).join(", ")}`);
      }
      args.profile = profile;
      args.extensions = new Set(PROFILES[profile]);
      continue;
    }

    if (arg === "--ext" && argv[i + 1]) {
      const raw = argv[++i];
      args.extensions = new Set(
        raw.split(",")
          .map((s) => s.trim())
          .filter(Boolean)
          .map((s) => (s.startsWith(".") ? s : `.${s}`))
      );
      continue;
    }

    if (arg === "--max-file-bytes" && argv[i + 1]) {
      args.maxFileBytes = parsePositiveInt(argv[++i], "--max-file-bytes");
      continue;
    }

    if (arg === "--max-total-bytes" && argv[i + 1]) {
      args.maxTotalBytes = parsePositiveInt(argv[++i], "--max-total-bytes");
      continue;
    }

    if (arg === "--max-files" && argv[i + 1]) {
      args.maxFiles = parsePositiveInt(argv[++i], "--max-files");
      continue;
    }

    if (arg === "--ignore-dir" && argv[i + 1]) {
      args.extraIgnoreDirs.add(argv[++i].trim());
      continue;
    }

    if (arg === "--ignore-suffix" && argv[i + 1]) {
      args.extraIgnoreSuffixes.push(argv[++i].trim());
      continue;
    }

    if (!args.targetDir) {
      args.targetDir = arg;
      continue;
    }

    fail(`Unknown argument: ${arg}`);
  }

  if (!args.targetDir) {
    args.targetDir = process.cwd();
  }

  return args;
}

function parsePositiveInt(value, flagName) {
  const n = Number(value);
  if (!Number.isInteger(n) || n <= 0) {
    fail(`${flagName} requires a positive integer, got: ${value}`);
  }
  return n;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function safeExec(command, cwd) {
  try {
    return cp.execSync(command, {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return null;
  }
}

function isGitRepo(rootDir) {
  return safeExec("git rev-parse --is-inside-work-tree", rootDir) === "true";
}

function getGitTrackedFiles(rootDir) {
  const out = safeExec("git ls-files", rootDir);
  if (!out) return null;
  return new Set(out.split("\n").map((s) => s.trim()).filter(Boolean));
}

function getGitChangedFiles(rootDir) {
  const out = safeExec("git diff --name-only HEAD", rootDir);
  if (!out) return new Set();
  return new Set(out.split("\n").map((s) => s.trim()).filter(Boolean));
}

function loadContextIgnore(rootDir) {
  const ignorePath = path.join(rootDir, ".contextignore");
  if (!fs.existsSync(ignorePath)) {
    return { names: new Set(), suffixes: [] };
  }

  const lines = fs.readFileSync(ignorePath, "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));

  const names = new Set();
  const suffixes = [];

  for (const line of lines) {
    if (line.startsWith("*.")) {
      suffixes.push(line.slice(1));
    } else {
      names.add(line);
    }
  }

  return { names, suffixes };
}

function shouldIgnoreDir(name, args, contextIgnore) {
  if (DEFAULT_IGNORE_DIRS.has(name)) return true;
  if (args.extraIgnoreDirs.has(name)) return true;
  if (contextIgnore.names.has(name)) return true;
  if (!args.includeHidden && name.startsWith(".")) return true;
  return false;
}

function shouldIgnoreFile(fileName, args, contextIgnore) {
  if (!args.includeHidden && fileName.startsWith(".")) return true;

  for (const suffix of DEFAULT_IGNORE_FILE_SUFFIXES) {
    if (fileName.endsWith(suffix)) return true;
  }

  for (const suffix of args.extraIgnoreSuffixes) {
    if (fileName.endsWith(suffix)) return true;
  }

  for (const suffix of contextIgnore.suffixes) {
    if (fileName.endsWith(suffix)) return true;
  }

  if (contextIgnore.names.has(fileName)) return true;

  return false;
}

function languageFromExtension(ext) {
  const map = {
    ".js": "js",
    ".jsx": "jsx",
    ".ts": "ts",
    ".tsx": "tsx",
    ".py": "python",
    ".pyi": "python",
    ".kt": "kotlin",
    ".kts": "kotlin",
    ".java": "java",
    ".xml": "xml",
    ".html": "html",
    ".css": "css",
    ".scss": "scss",
    ".sql": "sql",
    ".json": "json",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".toml": "toml",
    ".md": "markdown",
    ".go": "go",
    ".rs": "rust",
    ".c": "c",
    ".h": "c",
    ".cpp": "cpp",
    ".hpp": "cpp",
    ".cs": "csharp",
    ".php": "php",
    ".rb": "ruby",
    ".swift": "swift",
    ".scala": "scala",
    ".vue": "vue",
    ".svelte": "svelte",
    ".gradle": "groovy",
    ".ini": "ini",
  };
  return map[ext] || "";
}

function safeReadFile(filePath) {
  try {
    return fs.readFileSync(filePath, "utf8").replace(/\u0000/g, "");
  } catch (err) {
    return `/* Failed to read file: ${err.message} */`;
  }
}

function walk(dir, rootDir, args, contextIgnore, results, state) {
  if (state.stop) return;

  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch (err) {
    results.push({
      relativePath: path.relative(rootDir, dir) || ".",
      ext: "",
      skipped: true,
      reason: `Failed to read directory: ${err.code || "UNKNOWN"} - ${err.message}`,
      type: "dir-error",
    });
    return;
  }

  entries.sort((a, b) => a.name.localeCompare(b.name));

  for (const entry of entries) {
    if (state.stop) return;

    const fullPath = path.join(dir, entry.name);
    const relativePath = path.relative(rootDir, fullPath);

    if (entry.isDirectory()) {
      if (shouldIgnoreDir(entry.name, args, contextIgnore)) {
        state.skippedDirs.push(relativePath || entry.name);
        continue;
      }
      walk(fullPath, rootDir, args, contextIgnore, results, state);
      continue;
    }

    if (!entry.isFile()) continue;
    if (shouldIgnoreFile(entry.name, args, contextIgnore)) continue;

    const ext = path.extname(entry.name);
    if (!args.extensions.has(ext)) continue;

    if (args.gitTracked && state.gitTrackedFiles && !state.gitTrackedFiles.has(relativePath)) {
      continue;
    }

    if (args.gitChanged && state.gitChangedFiles && !state.gitChangedFiles.has(relativePath)) {
      continue;
    }

    let stat;
    try {
      stat = fs.statSync(fullPath);
    } catch (err) {
      results.push({
        relativePath,
        ext,
        skipped: true,
        reason: `Failed to stat file: ${err.code || "UNKNOWN"} - ${err.message}`,
        type: "stat-error",
      });
      continue;
    }

    if (results.filter((r) => !r.skipped).length >= args.maxFiles) {
      state.stop = true;
      state.stopReason = `Stopped after reaching max file count (${args.maxFiles}).`;
      return;
    }

    if (stat.size > args.maxFileBytes) {
      results.push({
        relativePath,
        ext,
        skipped: true,
        reason: `Skipped: file too large (${stat.size} bytes > ${args.maxFileBytes})`,
        size: stat.size,
        type: "too-large",
      });
      continue;
    }

    const content = safeReadFile(fullPath);
    const contentBytes = Buffer.byteLength(content, "utf8");

    results.push({
      relativePath,
      ext,
      skipped: false,
      content,
      size: stat.size,
      contentBytes,
      type: "included",
    });
  }
}

function buildTree(entries) {
  if (entries.length === 0) {
    return "- (no matching files found)";
  }
  return entries.map((entry) => `- ${entry.relativePath}`).join("\n");
}

function summarizeSkipped(skipped, limit = 20) {
  if (!skipped.length) return null;

  const lines = skipped.slice(0, limit).map((entry) => {
    return `- ${entry.relativePath}: ${entry.reason}`;
  });

  if (skipped.length > limit) {
    lines.push(`- ... and ${skipped.length - limit} more skipped entries`);
  }

  return lines.join("\n");
}

function buildOutput(rootDir, results, args, state) {
  const included = results.filter((r) => !r.skipped);
  const skipped = results.filter((r) => r.skipped);

  const totalIncludedBytes = included.reduce((sum, f) => sum + (f.contentBytes || 0), 0);
  const profileLabel = args.profile || "custom";

  const header = [
    "# Project Context",
    "",
    `- Root: ${rootDir}`,
    `- Profile: ${profileLabel}`,
    `- Included files: ${included.length}`,
    `- Skipped entries: ${skipped.length}`,
    `- Extensions: ${Array.from(args.extensions).sort().join(", ")}`,
    `- Total included bytes: ${totalIncludedBytes}`,
    args.gitTracked ? `- Mode: git-tracked` : null,
    args.gitChanged ? `- Mode: git-changed` : null,
    state.stopReason ? `- Stop reason: ${state.stopReason}` : null,
    "",
    "## File List",
    "",
    buildTree(included),
    "",
  ].filter(Boolean).join("\n");

  let output = header;
  let totalBytes = Buffer.byteLength(output, "utf8");

  if (args.showSkipped && skipped.length) {
    const skippedBlock = [
      "## Skipped Summary",
      "",
      "```text",
      summarizeSkipped(skipped),
      "```",
      "",
    ].join("\n");

    output += skippedBlock;
    totalBytes += Buffer.byteLength(skippedBlock, "utf8");
  }


  output += "\n---\n\n";
  totalBytes += Buffer.byteLength("---\n\n", "utf8");

  for (const entry of included) {
    const section = [
      `## File: ${entry.relativePath}`,
      "",
      `\`\`\`${languageFromExtension(entry.ext)}`,
      entry.content,
      "```",
      "",
    ].join("\n");

    const sectionBytes = Buffer.byteLength(section, "utf8");

    if (totalBytes + sectionBytes > args.maxTotalBytes) {
      output += [
        "## Output Truncated",
        "",
        "```text",
        `Stopped adding more files because total output would exceed ${args.maxTotalBytes} bytes.`,
        "```",
        "",
      ].join("\n");
      break;
    }

    output += section;
    totalBytes += sectionBytes;
  }

  return output;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const rootDir = path.resolve(args.targetDir);

  if (!fs.existsSync(rootDir)) {
    fail(`Path does not exist: ${rootDir}`);
  }

  const stat = fs.statSync(rootDir);
  if (!stat.isDirectory()) {
    fail(`Path is not a directory: ${rootDir}`);
  }

  if (args.gitTracked || args.gitChanged) {
    if (!isGitRepo(rootDir)) {
      fail(`Git mode requested, but this is not a git repo: ${rootDir}`);
    }
  }

  const contextIgnore = args.contextIgnore ? loadContextIgnore(rootDir) : { names: new Set(), suffixes: [] };

  const state = {
    stop: false,
    stopReason: "",
    skippedDirs: [],
    gitTrackedFiles: args.gitTracked ? getGitTrackedFiles(rootDir) : null,
    gitChangedFiles: args.gitChanged ? getGitChangedFiles(rootDir) : null,
  };

  const results = [];
  walk(rootDir, rootDir, args, contextIgnore, results, state);

  results.sort((a, b) => a.relativePath.localeCompare(b.relativePath));

  const output = buildOutput(rootDir, results, args, state);

  if (args.stdout) {
    process.stdout.write(output);
    return;
  }

  const outPath = path.join(rootDir, "context.txt");
  fs.writeFileSync(outPath, output, "utf8");
  console.log(`Wrote ${outPath}`);
}

main();