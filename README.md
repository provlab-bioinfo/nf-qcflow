# nf-qcflow

A comprehensive Nextflow bioinformatics pipeline for next-generation sequencing (NGS) data quality processing. nf-qcflow performs quality control, host sequence removal, contamination screening, and generates detailed statistical reports in both tabular and HTML formats. The pipeline supports both Illumina short-read and Oxford Nanopore long-read sequencing platforms.

A nf-qcflow analysis output demo page can be found at: [nf-qcflow_output_demo](https://github.com/xiaoli-dong/nf-qcflow/tree/main/docs/demo) page

## Pipeline Summary

nf-qcflow supports both short and long reads:

```mermaid
flowchart LR
    A[Samplesheet] --> B{Platform}
    
    B -->|Illumina| C[QC_SHORT: FASTQC → Seqkit]
    C --> C2{Trimmer}
    C2 -->|bbduk| C3A[BBDuk]
    C2 -->|fastp| C3B[fastp]
    C3A --> C4[Deacon]
    C3B --> C4
    C4 --> C5[Kraken2 → Bracken]
    
    B -->|Nanopore| D[QC_LONG: NanoPlot → Seqkit]
    D --> D2{Trimmer}
    D2 -->|fastplong| D3A[fastplong]
    D2 -->|porechop_chopper| D3B[Porechop → Chopper]
    D3A --> D4[Deacon]
    D3B --> D4
    D4 --> D5[Kraken2 → Bracken]
    
    C5 --> E[CSVTK CONCAT & SORT]
    D5 --> E
    E --> F[CSV to JSON]
    F --> G[Final HTML Report]
