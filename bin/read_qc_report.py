#!/usr/bin/env python3

import argparse
import pandas as pd


def parse_args():
    parser = argparse.ArgumentParser(
        description="Combine input, trimmed, and dehosted SeqKit summaries into a read QC report."
    )
    parser.add_argument("--input", required=True, help="Input SeqKit summary TSV")
    parser.add_argument("--trimmed", required=True, help="Trimmed SeqKit summary TSV")
    parser.add_argument("--dehosted", required=True, help="Dehosted SeqKit summary TSV")
    parser.add_argument("-o", "--output", required=True, help="Output read QC report TSV")
    return parser.parse_args()


def read_summary(path):
    return pd.read_csv(path, sep="\t")


def main():
    args = parse_args()

    input_df = read_summary(args.input)
    trimmed_df = read_summary(args.trimmed)
    dehosted_df = read_summary(args.dehosted)

    # KEY FIX 1: Check for duplicates using both 'sample' and 'platform'
    for name, df in [
        ("input", input_df),
        ("trimmed", trimmed_df),
        ("dehosted", dehosted_df),
    ]:
        if df[["sample", "platform"]].duplicated().any():
            duplicates = df.loc[df[["sample", "platform"]].duplicated(), ["sample", "platform"]].astype(str).agg(" - ".join, axis=1).unique()
            raise ValueError(
                f"Duplicate sample/platform combination(s) found in {name} summary: "
                f"{', '.join(duplicates)}"
            )

    # Rename stage-specific columns
    input_df = input_df.rename(
        columns={
            "num_reads": "input_num_reads",
            "total_bases": "input_total_bases",
            "min_len": "input_min_len",
            "avg_len": "input_avg_len",
            "max_len": "input_max_len",
        }
    )

    trimmed_df = trimmed_df.rename(
        columns={
            "num_reads": "trimmed_num_reads",
            "total_bases": "trimmed_total_bases",
            "min_len": "trimmed_min_len",
            "avg_len": "trimmed_avg_len",
            "max_len": "trimmed_max_len",
        }
    )

    dehosted_df = dehosted_df.rename(
        columns={
            "num_reads": "dehosted_num_reads",
            "total_bases": "dehosted_total_bases",
            "min_len": "dehosted_min_len",
            "avg_len": "dehosted_avg_len",
            "max_len": "dehosted_max_len",
        }
    )

    # Keep sample/platform/read_type from input
    input_cols = [
        "sample",
        "platform",
        "read_type",
        "input_num_reads",
        "input_total_bases",
        "input_avg_len",
    ]

    trimmed_cols = [
        "sample",
        "platform", # Need this for the merge
        "trimmed_num_reads",
        "trimmed_total_bases",
        "trimmed_avg_len",
    ]

    dehosted_cols = [
        "sample",
        "platform", # Need this for the merge
        "dehosted_num_reads",
        "dehosted_total_bases",
        "dehosted_avg_len",
    ]

    # KEY FIX 2: Merge on both 'sample' and 'platform'
    report = input_df[input_cols].merge(
        trimmed_df[trimmed_cols],
        on=["sample", "platform"],
        how="outer",
        validate="one_to_one",
    )

    report = report.merge(
        dehosted_df[dehosted_cols],
        on=["sample", "platform"],
        how="outer",
        validate="one_to_one",
    )

    # Make sure all samples are present at all stages
    required_counts = [
        "input_num_reads",
        "trimmed_num_reads",
        "dehosted_num_reads",
    ]

    missing = report[report[required_counts].isna().any(axis=1)]

    if not missing.empty:
        missing_ids = missing["sample"].astype(str) + " (" + missing["platform"].astype(str) + ")"
        raise ValueError(
            "Samples are missing from one or more QC stages: "
            + ", ".join(missing_ids)
        )

    # Calculate read retention percentages
    report["trimmed_pct"] = (
        report["trimmed_num_reads"]
        / report["input_num_reads"]
        * 100
    )

    report["dehosted_pct_of_trimmed"] = (
        report["dehosted_num_reads"]
        / report["trimmed_num_reads"]
        * 100
    )

    # Round percentages and average lengths
    report["trimmed_pct"] = report["trimmed_pct"].round(1)
    report["dehosted_pct_of_trimmed"] = (
        report["dehosted_pct_of_trimmed"].round(1)
    )


    report["input_avg_len"] = report["input_avg_len"].round(1)
    report["trimmed_avg_len"] = report["trimmed_avg_len"].round(1)
    report["dehosted_avg_len"] = report["dehosted_avg_len"].round(1)

    # Final column order
    report = report[
        [
            "sample",
            "platform",
            "read_type",
            "input_num_reads",
            "input_total_bases",
            "input_avg_len",
            "trimmed_num_reads",
            "trimmed_total_bases",
            "trimmed_avg_len",
            "trimmed_pct",
            "dehosted_num_reads",
            "dehosted_total_bases",
            "dehosted_avg_len",
            "dehosted_pct_of_trimmed"
        ]
    ]

    report.to_csv(args.output, sep=",", index=False)


if __name__ == "__main__":
    main()
