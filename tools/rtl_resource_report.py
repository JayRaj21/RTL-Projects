#!/usr/bin/env python3
"""Report synthesized FPGA resource usage (LUTs, FFs, DSPs, BRAMs, carry
chains) for a Verilog RTL file, using Yosys as the synthesis backend.

Usage:
    rtl_resource_report.py FILE.v [FILE2.v ...] [--top MODULE] [--family ice40|ecp5|xilinx|gowin] [--json]

If --top is omitted, every module defined directly in the given file(s) is
synthesized as its own top (useful for files like traffic_light.v that
define multiple independent modules).
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
from collections import defaultdict

# Map each family's synth command and its primitive-name -> resource-category
# classification. Only the families with a fully open-source Yosys backend
# are included, so this needs no vendor toolchain.
FAMILIES = {
    "ice40": {
        "synth_cmd": "synth_ice40",
        "categories": {
            "LUT": re.compile(r"^SB_LUT"),
            "FF": re.compile(r"^SB_DFF"),
            "CARRY": re.compile(r"^SB_CARRY"),
            "DSP": re.compile(r"^SB_MAC16"),
            "BRAM": re.compile(r"^SB_RAM"),
            "IO": re.compile(r"^SB_IO"),
        },
    },
    "ecp5": {
        "synth_cmd": "synth_ecp5",
        "categories": {
            "LUT": re.compile(r"^LUT4"),
            "FF": re.compile(r"^(TRELLIS_FF|FD1P3)"),
            "CARRY": re.compile(r"^CCU2C"),
            "DSP": re.compile(r"^MULT18X18D"),
            "BRAM": re.compile(r"^(DP16KD|PDPW16KD)"),
        },
    },
    "xilinx": {
        "synth_cmd": "synth_xilinx",
        "categories": {
            "LUT": re.compile(r"^LUT\d"),
            "FF": re.compile(r"^(FD|FDRE|FDCE|FDPE|FDSE)"),
            "CARRY": re.compile(r"^CARRY4"),
            "DSP": re.compile(r"^DSP48"),
            "BRAM": re.compile(r"^RAMB"),
        },
    },
    "gowin": {
        "synth_cmd": "synth_gowin",
        "categories": {
            "LUT": re.compile(r"^LUT\d"),
            "FF": re.compile(r"^(DFF|FD)"),
            "DSP": re.compile(r"^PADD9"),
            "BRAM": re.compile(r"^(SDPB|SP)"),
        },
    },
}

MODULE_RE = re.compile(r"^\s*module\s+(\w+)", re.MULTILINE)


def find_modules(files):
    names = []
    for f in files:
        with open(f) as fh:
            text = fh.read()
        names.extend(MODULE_RE.findall(text))
    return names


def run_yosys(files, top, synth_cmd):
    reads = " ".join(f"read_verilog {f};" for f in files)
    script = f"{reads} {synth_cmd} -top {top}"
    proc = subprocess.run(
        ["yosys", "-p", script],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"yosys failed for top={top}:\n{proc.stderr}")
    return proc.stdout


CELL_LINE_RE = re.compile(r"^\s{5}(\S+)\s+(\d+)\s*$")


def parse_stats(yosys_output, top):
    # Grab the "=== <top> ===" ... cell table block (the last, fully-mapped one).
    blocks = re.findall(
        rf"=== {re.escape(top)} ===\n(.*?)(?=\n===|\Z)", yosys_output, re.DOTALL
    )
    if not blocks:
        raise RuntimeError(f"could not find stats block for {top}")
    block = blocks[-1]
    cells = {}
    in_cells = False
    for line in block.splitlines():
        if "Number of cells:" in line:
            in_cells = True
            continue
        if in_cells:
            m = CELL_LINE_RE.match(line)
            if m:
                cells[m.group(1)] = int(m.group(2))
            elif line.strip() == "":
                break
    return cells


def categorize(cells, categories):
    summary = defaultdict(int)
    other = defaultdict(int)
    for name, count in cells.items():
        matched = False
        for cat, pattern in categories.items():
            if pattern.match(name):
                summary[cat] += count
                matched = True
                break
        if not matched:
            other[name] += count
    return summary, other


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+", help="Verilog source file(s)")
    ap.add_argument("--top", help="Top module to synthesize (default: every module in the file)")
    ap.add_argument("--family", choices=FAMILIES.keys(), default="ice40", help="Target FPGA family (default: ice40)")
    ap.add_argument("--json", action="store_true", help="Emit machine-readable JSON instead of a table")
    args = ap.parse_args()

    if shutil.which("yosys") is None:
        sys.exit("error: yosys not found on PATH. Install it with: sudo apt-get install yosys")

    fam = FAMILIES[args.family]
    tops = [args.top] if args.top else find_modules(args.files)
    if not tops:
        sys.exit("error: no modules found in the given file(s)")

    results = {}
    for top in tops:
        try:
            out = run_yosys(args.files, top, fam["synth_cmd"])
            cells = parse_stats(out, top)
            summary, other = categorize(cells, fam["categories"])
            results[top] = {"summary": dict(summary), "raw_cells": cells, "unclassified": dict(other)}
        except RuntimeError as e:
            results[top] = {"error": str(e)}

    if args.json:
        print(json.dumps(results, indent=2))
        return

    for top, res in results.items():
        print(f"\n=== {top} ({args.family}) ===")
        if "error" in res:
            print(f"  ERROR: {res['error']}")
            continue
        if not res["summary"]:
            print("  (no cells synthesized)")
        for cat, count in sorted(res["summary"].items()):
            print(f"  {cat:<8} {count}")
        if res["unclassified"]:
            print("  other:")
            for name, count in sorted(res["unclassified"].items()):
                print(f"    {name:<20} {count}")


if __name__ == "__main__":
    main()
