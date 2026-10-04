#!/usr/bin/env python3
"""Scan the Git index, not ignored local secrets/WIP; report paths/rules only."""
import os
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def main() -> int:
    scanner = os.environ.get("GITLEAKS_BIN", "gitleaks")
    if shutil.which(scanner) is None:
        raise SystemExit("Install Gitleaks 8.30.1 (see docs/security.md); scanner is mandatory")
    files = subprocess.check_output(["git", "ls-files", "-z"]).decode().split("\0")
    blocked = [p for p in files if p and (p.endswith("master.key") or
               (p.startswith("config/credentials/") and p.endswith(".key")) or
               (Path(p).name.startswith(".env") and not p.endswith(".example")))]
    if blocked:
        raise SystemExit("Secret paths in Git index: " + ", ".join(blocked))
    with tempfile.TemporaryDirectory(prefix="leadpulse-secret-scan-") as directory:
        root = Path(directory)
        for filename in filter(None, files):
            path = root / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            # Inspect exact staged bytes; do not ingest the user's unstaged WIP.
            path.write_bytes(subprocess.check_output(["git", "show", f":{filename}"]))
        report = root / "scan-report.json"
        args = [scanner, "dir", str(root), "--redact=100", "--no-banner", "--exit-code=1",
                "--report-format=json", f"--report-path={report}"]
        result = subprocess.run(args, check=False, capture_output=True)
        if report.exists():
            findings = json.loads(report.read_text())
            for finding in findings:
                print(f"{finding['File']}:{finding['StartLine']} rule={finding['RuleID']}")
        print(f"Secret scan exit code: {result.returncode}")
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
