#!/usr/bin/env python3

import argparse
import csv
import sys
from collections import defaultdict

def parse_args():
    parser = argparse.ArgumentParser(description="Summarize SeqKit statistics at the sample level.")
    parser.add_argument("-i", "--input", required=True, help="Input SeqKit TSV file")
    parser.add_argument("-o", "--output", required=True, help="Output sample-level summary TSV file")
    return parser.parse_args()

def format_number(value):
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        return f"{value:.1f}"
    return str(value)

def get_read_type_from_filename(filename):
    if "_R1" in filename: return "R1"
    if "_R2" in filename: return "R2"
    if ".deacon_1." in filename: return "R1"
    if ".deacon_2." in filename: return "R2"
    return None

def get_actual_platform(filename):
    return "nanopore" if "_long" in filename else "illumina"

def summarize_paired(sample, platform, rows):
    r1_rows = []
    r2_rows = []

    for row in rows:
        read = get_read_type_from_filename(row["file"])
        if read == "R1":
            r1_rows.append(row)
        elif read == "R2":
            r2_rows.append(row)
        else:
            raise ValueError(
                f"Sample '{sample}' (platform '{platform}') is marked as paired, but file "
                f"'{row['file']}' cannot be identified as R1 or R2."
            )

    if len(r1_rows) != 1:
        raise ValueError(f"Sample '{sample}' (platform '{platform}') must have exactly one R1 record, but found {len(r1_rows)}.")
    if len(r2_rows) != 1:
        raise ValueError(f"Sample '{sample}' (platform '{platform}') must have exactly one R2 record, but found {len(r2_rows)}.")

    r1 = r1_rows[0]
    r2 = r2_rows[0]

    r1_reads = int(r1["num_seqs"])
    r2_reads = int(r2["num_seqs"])

    if r1_reads != r2_reads:
        raise ValueError(f"Sample '{sample}' (platform '{platform}') has unequal read counts: R1={r1_reads}, R2={r2_reads}.")

    total_bases = int(r1["sum_len"]) + int(r2["sum_len"])
    min_len = min(int(r1["min_len"]), int(r2["min_len"]))
    max_len = max(int(r1["max_len"]), int(r2["max_len"]))
    avg_len = total_bases / (r1_reads * 2)

    return {
        "sample": sample, "platform": platform, "read_type": "paired",
        "num_reads": r1_reads, "total_bases": total_bases,
        "min_len": min_len, "avg_len": avg_len, "max_len": max_len,
    }

def summarize_single(sample, platform, rows):
    if len(rows) != 1:
        raise ValueError(
            f"Sample '{sample}' (platform '{platform}') is marked as single-end, "
            f"but found {len(rows)} records."
        )
    row = rows[0]
    num_reads = int(row["num_seqs"])
    total_bases = int(row["sum_len"])
    avg_len = total_bases / num_reads

    return {
        "sample": sample, "platform": platform, "read_type": "single",
        "num_reads": num_reads, "total_bases": total_bases,
        "min_len": int(row["min_len"]), "avg_len": avg_len, "max_len": int(row["max_len"]),
    }

def main():
    args = parse_args()

    required_columns = {
        "sample", "platform", "read_type", "file",
        "num_seqs", "sum_len", "min_len", "max_len",
    }

    samples = defaultdict(list)

    with open(args.input, "r", newline="") as infile:
        reader = csv.DictReader(infile, delimiter="\t")

        if reader.fieldnames is None:
            raise ValueError("Input file is empty or has no header.")

        missing = required_columns - set(reader.fieldnames)
        if missing:
            raise ValueError(f"Input file is missing required columns: {', '.join(sorted(missing))}")

        for row in reader:
            # 1. Degenerate platform
            if row["platform"] == "hybrid":
                true_platform = get_actual_platform(row["file"])
            else:
                true_platform = row["platform"]

            # 2. Correct read_type based on file name
            # Nanopore files are structurally single-end.
            if true_platform == "nanopore":
                true_read_type = "single"
            else:
                true_read_type = row["read_type"]

            row["platform"] = true_platform
            row["read_type"] = true_read_type

            key = (row["sample"], true_platform)
            samples[key].append(row)

    results = []

    for (sample, platform), rows in samples.items():
        read_types = {row["read_type"] for row in rows}

        if len(read_types) != 1:
             raise ValueError(
                f"Sample '{sample}' (platform '{platform}') has inconsistent read_type values: "
                f"{', '.join(sorted(read_types))}."
            )

        read_type = next(iter(read_types))

        if read_type == "paired":
            result = summarize_paired(sample, platform, rows)
        elif read_type == "single":
            result = summarize_single(sample, platform, rows)
        else:
            raise ValueError(f"Sample '{sample}' (platform '{platform}') has unsupported read_type '{read_type}'.")

        results.append(result)

    results.sort(key=lambda x: (x["sample"], x["platform"]))

    fieldnames = ["sample", "platform", "read_type", "num_reads", "total_bases", "min_len", "avg_len", "max_len"]

    with open(args.output, "w", newline="") as outfile:
        writer = csv.DictWriter(outfile, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()

        for result in results:
            writer.writerow({
                "sample": result["sample"],
                "platform": result["platform"],
                "read_type": result["read_type"],
                "num_reads": result["num_reads"],
                "total_bases": result["total_bases"],
                "min_len": result["min_len"],
                "avg_len": format_number(result["avg_len"]),
                "max_len": result["max_len"],
            })

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
