#!/usr/bin/env python3
import argparse, re, sys
from typing import Optional

# PEP 503 normalization: lowercase and replace runs of non-alnum with single '-'
def norm_name(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")

# Try to extract package name from a requirements line.
def extract_pkg_name(line: str) -> Optional[str]:
    s = line.strip()

    # Ignore comments/blank/options/editable/include lines
    if not s or s.startswith("#"):
        return None
    if s.startswith(("-", "--")):
        # Could be -r, --find-links, --index-url, -f, -e, etc.
        # Editable VCS with egg? try to parse egg name
        if s.startswith("-e "):
            m = re.search(r"[#&]egg=([A-Za-z0-9_.+-]+)", s)
            return norm_name(m.group(1)) if m else None
        return None

    # VCS/URL with #egg=NAME
    m = re.search(r"[#&]egg=([A-Za-z0-9_.+-]+)", s)
    if m:
        return norm_name(m.group(1))

    # PEP 508 direct URL: "name @ https://..."
    m = re.match(r"\s*([A-Za-z0-9_.+-]+)\s*@\s*\S+", s)
    if m:
        return norm_name(m.group(1))

    # Otherwise: name[extras]? <specifiers>? ; <markers>?
    # Strip markers after ';'
    s = s.split(";", 1)[0].strip()

    # Split off version specifiers (==,>=,<=,!=,~=,>,<) or whitespace
    m = re.match(r"\s*([A-Za-z0-9_.+-]+)", s)
    if not m:
        return None
    name = m.group(1)

    # Drop extras in name like foo[bar,baz]
    name = name.split("[", 1)[0]
    return norm_name(name)

def load_base_names(path: str) -> set:
    names = set()
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            pkg = extract_pkg_name(raw)
            if pkg:
                names.add(pkg)
    return names

def main():
    ap = argparse.ArgumentParser(description="Prune requirements by removing packages present in base list (ignoring versions/extras/markers).")
    ap.add_argument("--base", required=True, help="Path to base/common requirements (e.g., base-requirements.txt)")
    ap.add_argument("--req", required=True, help="Path to input requirements.txt")
    ap.add_argument("--out", default="-", help="Output file (default: stdout)")
    args = ap.parse_args()

    base_names = load_base_names(args.base)
    removed = []

    out_f = sys.stdout if args.out == "-" else open(args.out, "w", encoding="utf-8")
    try:
        with open(args.req, "r", encoding="utf-8") as inp:
            for line in inp:
                pkg = extract_pkg_name(line)
                if pkg and pkg in base_names:
                    removed.append(pkg)
                    continue
                out_f.write(line)
    finally:
        if out_f is not sys.stdout:
            out_f.close()

if __name__ == "__main__":
    main()
