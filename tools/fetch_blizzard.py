"""Download the game's own UI code the tests run, into tests/blizzard/.

    python tools/fetch_blizzard.py

The fake game the tests use is Daylight UI's, and so is the list of the game's
files it needs and the pinned commit of Gethe/wow-ui-source they come from. This
script runs Daylight UI's own fetch script from the checkout the tests load
(DUI_ROOT, else .daylight/DaylightUI, else the owner's worktree; see
tests/ez_harness.lua) and points its output here. Blizzard's code is never
committed (.gitignore).
"""
import importlib.util
import os
import sys
from urllib import request as urlrequest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "tests", "blizzard")


def daylight_root():
    """The Daylight UI checkout, found the way tests/ez_harness.lua finds it."""
    env = os.environ.get("DUI_ROOT")
    candidates = [env] if env else [
        os.path.join(ROOT, ".daylight", "DaylightUI"),
        os.path.join(ROOT, "..", "..", "DaylightUI-worktrees", "ezcdm-pin", "DaylightUI"),
    ]
    for path in candidates:
        if path and os.path.isfile(os.path.join(path, "DaylightUI.toc")):
            return os.path.abspath(path)
    sys.exit("Daylight UI not found: clone it at the tag in tests/pin.lua into .daylight/DaylightUI, "
             "or set DUI_ROOT (see CONTRIBUTING.md).")


def get(url):
    req = urlrequest.Request(url, headers={"User-Agent": "wow-addon-tests"})
    with urlrequest.urlopen(req, timeout=90) as resp:
        return resp.read()


def main():
    if "--cdm" in sys.argv:
        sys.exit("--cdm rewrites Daylight UI's own catalogue; run it in Daylight UI's repo, not here.")
    script = os.path.join(daylight_root(), "tools", "fetch_blizzard.py")
    spec = importlib.util.spec_from_file_location("daylight_fetch_blizzard", script)
    fetch = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fetch)
    fetch.OUT = OUT
    fetch.get = get
    fetch.main()


if __name__ == "__main__":
    main()
