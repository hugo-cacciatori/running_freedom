"""Build a self-contained mod archive from an explicit runtime-file allowlist."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FILES = ("manifest.json", "main.lua", "README.md", "LICENSE")


def build():
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    version = manifest["version"]
    folder = "dev" if "-dev" in version else f"v{version}"
    output = ROOT / "dist" / folder
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"running_freedom-{version}.zip"
    # Fixed member timestamps make repeated packages byte-identical.
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for name in FILES:
            info = zipfile.ZipInfo(f"running_freedom/{name}", (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, (ROOT / name).read_bytes())
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / "SHA256SUMS.txt").write_text(f"{digest}  {archive.name}\n", encoding="ascii")
    print(archive)
    return archive


if __name__ == "__main__":
    build()
