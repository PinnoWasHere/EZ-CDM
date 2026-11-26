"""Pick and run the tests that cover the files you changed.

From the repo root:
    python tools/affected.py                         your uncommitted changes (needs git)
    python tools/affected.py --since main            changed since a commit, plus uncommitted
    python tools/affected.py --files Grammar.lua     these files only
    python tools/affected.py --list ...              say which tests and why, run nothing

A change to a shipped Lua file runs the checks that read every shipped file
(load, hygiene, guards, idle cost), the file's own tests and the tests built on
it, and every test that names it. A file no test covers is reported: run the
whole suite (luajit tests/run.lua --par) once before you push.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

# Read every shipped file: a few seconds together, so any shipped change runs them.
EVERY_SHIPPED = ["test_load", "test_hygiene", "test_guards", "test_lag"]
# The .toc decides what loads and what ships.
TOC_TESTS = ["test_load", "test_hygiene", "test_guards"]
# The every-class sweep: Grammar, Draft, Effects and the Bridge they read, for each class.
SWEEP = ["test_sweep_a", "test_sweep_b", "test_sweep_c", "test_sweep_d", "test_sweep_e", "test_sweep_f",
         "test_sweep_g", "test_sweep_h", "test_sweep_i", "test_sweep_j", "test_sweep_k", "test_sweep_l",
         "test_sweep_m", "test_sweep_n", "test_sweep_o", "test_sweep_p", "test_sweep_q", "test_sweep_r",
         "test_sweep_s", "test_sweep_t", "test_sweep_u", "test_sweep_v", "test_sweep_w", "test_sweep_looks_a", "test_sweep_looks_b"]
# A shipped file's own tests and the tests of the files built on it. Drawer reads
# Draft; Draft reads Grammar and Effects; all of them read Bridge. Grammar reads the
# aura links and Effects. Start reads Grammar's words, and shares the editor's hooks
# with Drawer. Tour lights Start's and Drawer's parts. Effects' tests write
# through Draft.
BUILT_ON = {
    "Bridge.lua": ["test_bridge", "test_grammar", "test_draft", "test_start", "test_drawer", "test_effects", "test_tour"] + SWEEP,
    "Grammar.lua": ["test_grammar", "test_draft", "test_start", "test_drawer", "test_effects", "test_tour"] + SWEEP,
    "AuraLinks.lua": ["test_grammar", "test_draft", "test_drawer", "test_effects"] + SWEEP,
    "Effects.lua": ["test_effects", "test_grammar", "test_draft", "test_drawer"] + SWEEP,
    "Draft.lua": ["test_draft", "test_drawer", "test_effects"] + SWEEP,
    "Start.lua": ["test_start", "test_drawer", "test_tour"],
    "Drawer.lua": ["test_drawer", "test_start", "test_tour"],
    "Tour.lua": ["test_tour"],
    "Looks.lua": ["test_looks", "test_overlay", "test_drawer", "test_draft"] + SWEEP,
}
# The harness itself: the load test proves it still loads Daylight UI and EZ-CDM.
HARNESS = {"tests/ez_harness.lua", "tests/run.lua", "tests/pin.lua"}
# Data a helper reads with dofile, which the require scan below can't see.
DATA_OF = {"tests/spell_facts.lua": "classworld"}
IGNORED = ("tools/", "docs/", ".github/", ".daylight/", "tests/blizzard/")


def run_git(*args):
    try:
        res = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                             errors="replace")
    except OSError:
        return ""
    return res.stdout if res.returncode == 0 else ""


def changed(since=None):
    names = set(run_git("diff", "--name-only", since or "HEAD").split())
    names |= set(run_git("ls-files", "--others", "--exclude-standard").split())
    return sorted(names)


def text_of(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read()
    except OSError:
        return ""


def requires_of(text):
    return set(re.findall(r'require\("([\w_]+)"\)', text))


def test_files(dirs):
    """name -> { text, requires } for every test file in the given tests folders.
    requires holds every helper a test reaches, through other helpers too."""
    found, helpers = {}, {}
    for d in dirs:
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.endswith(".lua") and not f.startswith("test_"):
                    helpers[f[:-4]] = requires_of(text_of(os.path.join(d, f)))
    for d in dirs:
        for sub, prefix in (("", ""), ("repro", "repro/")):
            folder = os.path.join(d, sub)
            if not os.path.isdir(folder):
                continue
            for f in sorted(os.listdir(folder), key=str.lower):
                if not f.endswith(".lua") or (not prefix and not f.startswith("test_")):
                    continue
                text = text_of(os.path.join(folder, f))
                reach, todo = set(), list(requires_of(text))
                while todo:
                    m = todo.pop()
                    if m not in reach:
                        reach.add(m)
                        todo.extend(helpers.get(m, ()))
                found[prefix + f[:-4]] = {"text": text, "requires": reach}
    return found


def shipped():
    """The Lua files EZ-CDM's .toc lists."""
    files = set()
    for line in text_of(os.path.join(ROOT, "EZ-CDM.toc")).splitlines():
        line = line.strip().replace("\\", "/")
        if line.endswith(".lua") and not line.startswith("#"):
            files.add(line)
    return files


def pick(files, tests):
    """(tests -> why, files no test covers) for paths relative to the repo root."""
    picked, uncovered = {}, []
    ship = shipped()

    def add(names, why):
        for n in names:
            if n in tests and n not in picked:
                picked[n] = why

    for f in files:
        base = os.path.basename(f)
        stem = base[:-4] if base.endswith(".lua") else base
        if f.startswith(IGNORED) or f.endswith(".md"):
            continue
        if f in HARNESS:
            add(["test_load"], f)
            uncovered.append(f)
        elif f.endswith(".toc"):
            add(TOC_TESTS, f)
        elif f in ship or (f.endswith(".lua") and "/" not in f):
            add(EVERY_SHIPPED, "every shipped Lua change")
            add(BUILT_ON.get(f, []), f)
            add([n for n, t in tests.items() if f in t["text"]], f)
        elif f.startswith("tests/"):
            name = f[len("tests/"):-4] if f.endswith(".lua") else None
            if name in tests:
                add([name], f)
            elif stem == "guards_allow":
                add(["test_guards"], f)
            else:
                helper = DATA_OF.get(f, stem)
                users = [n for n, t in tests.items() if helper in t["requires"]]
                add(users, f)
                if not users:
                    uncovered.append(f)
        else:
            uncovered.append(f)
    return picked, uncovered


def report_and_run(files, picked, uncovered, only_list, cwd, runner="tests/run.lua"):
    if picked:
        print("%d test file(s) for %d changed file(s):" % (len(picked), len(files)))
        for name in sorted(picked):
            print("  %-28s %s" % (name, picked[name]))
    else:
        print("No test covers these changes (%s)." % ", ".join(files[:6]))
    if uncovered:
        print("Not covered on its own (%s%s): run `luajit %s --par` once before you push."
              % (", ".join(uncovered[:6]), " ..." if len(uncovered) > 6 else "", runner))
    if not picked:
        return 0
    cmd = ["luajit", runner, "--par", "--only"] + sorted(picked)
    print("$ " + " ".join(cmd))
    if only_list:
        return 0
    sys.stdout.flush()
    res = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    print("\n".join((res.stdout + res.stderr).strip().splitlines()[-30:]))
    return res.returncode


def relative(path, root):
    path = path.replace("\\", "/")
    if os.path.isabs(path):
        rel = os.path.relpath(path, root).replace("\\", "/")
        if not rel.startswith("../"):
            return rel
    return path[2:] if path.startswith("./") else path


def parse(argv, root):
    only_list = "--list" in argv
    since = argv[argv.index("--since") + 1] if "--since" in argv and argv.index("--since") + 1 < len(argv) else None
    if "--files" in argv:
        files = [relative(a, root) for a in argv[argv.index("--files") + 1:] if not a.startswith("--")]
    else:
        files = None
    return files, since, only_list


def main(argv):
    files, since, only_list = parse(argv, ROOT)
    if files is None:
        files = changed(since)
    if not files:
        print("Nothing changed (without git, name the files: --files Grammar.lua).")
        return 0
    tests = test_files([os.path.join(ROOT, "tests")])
    picked, uncovered = pick(files, tests)
    return report_and_run(files, picked, uncovered, only_list, ROOT)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
