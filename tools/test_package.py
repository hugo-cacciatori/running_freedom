"""Check the packaged mod in an isolated, external headless engine fixture.

This verifies packaging and native behavior, not a full graphical game install.
The temporary fixture is retained for inspection; its path is printed.
"""
import argparse
from pathlib import Path
import shutil
import tempfile
import zipfile

from test import run


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--archive", required=True, type=Path)
    args = parser.parse_args()
    engine = args.engine.resolve()
    archive = args.archive.resolve()
    stage = Path(tempfile.mkdtemp(prefix="running-freedom-check-"))
    print(f"External fixture: {stage}", flush=True)
    for name in ("src", "tests", "data"):
        shutil.copytree(engine / name, stage / name)
    with zipfile.ZipFile(archive) as bundle:
        expected = {f"running_freedom/{name}" for name in
                    ("manifest.json", "main.lua", "README.md", "LICENSE")}
        if set(bundle.namelist()) != expected:
            raise ValueError("Archive contains missing or unexpected files")
        bundle.extractall(stage / "mods")
    run(stage, stage / "mods" / "running_freedom")
