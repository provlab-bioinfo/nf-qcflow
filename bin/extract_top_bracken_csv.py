#!/usr/bin/env python
import csv
import sys

def extract_top_organisms_csv(bracken_file, sample_name, platform, top_n=4):
    results = {
        "Sample": sample_name,
        "Platform": platform
    }

    # Initialize defaults
    for i in range(1, top_n + 1):
        results[f"Match{i}"] = ""
        results[f"count{i}"] = 0
        results[f"perc{i}"] = 0.0

    with open(bracken_file, newline='') as infile:
        reader = csv.DictReader(infile, delimiter='\t')
        rows = sorted(reader, key=lambda x: int(float(x["new_est_reads"])), reverse=True)

        for i in range(top_n):
            if i < len(rows):
                results[f"Match{i+1}"] = rows[i]["name"]
                results[f"count{i+1}"] = int(float(rows[i]["new_est_reads"]))
                results[f"perc{i+1}"] = round(float(rows[i]["fraction_total_reads"]) * 100, 2)

    return results

def write_csv_rows(header, rows):
    writer = csv.DictWriter(sys.stdout, fieldnames=header)
    writer.writeheader()
    for row in rows:
        writer.writerow(row)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python extract_top_bracken_csv.py <bracken_output.tsv> <sample_name> <platform>")
        sys.exit(1)

    bracken_file = sys.argv[1]
    sample_name = sys.argv[2]
    platform = sys.argv[3]

    header = ["Sample", "Platform"]
    for i in range(1, 5):
        header.extend([f"Match{i}", f"count{i}", f"perc{i}"])

    row = extract_top_organisms_csv(bracken_file, sample_name, platform)

    # Put the single row in a list so we can sort it (useful if you later
    # modify this to read multiple files at once)
    rows = [row]

    # Sort the list of dictionaries by the "Sample" key
    rows.sort(key=lambda x: x["Sample"])

    write_csv_rows(header, rows)
