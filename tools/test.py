"""Run the native-loader integration suite without opening a game window."""
import argparse
import os
from pathlib import Path

from lupa.luajit21 import LuaRuntime


def run(engine, mod):
    suite = Path(__file__).resolve().parents[1] / "tests" / "integration.lua"
    previous = Path.cwd()
    try:
        os.chdir(engine)
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.globals().MOD_PATH = os.path.relpath(mod, engine).replace("\\", "/")
        lua.execute(suite.read_text(encoding="utf-8"))
    finally:
        os.chdir(previous)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--mod", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    run(args.engine.resolve(), args.mod.resolve())
