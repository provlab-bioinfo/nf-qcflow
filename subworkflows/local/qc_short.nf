include { CSVTK_SORT } from '../../modules/nf-core/csvtk/sort/main'
include {
    CSVTK_CONCAT as CSVTK_CONCAT_STATS_INPUT ;
    CSVTK_CONCAT as CSVTK_CONCAT_STATS_TRIMMED ;
    CSVTK_CONCAT as CSVTK_CONCAT_STATS_DEHOSTED ;
    CSVTK_CONCAT as CSVTK_CONCAT_TOPMATCHES ;
    CSVTK_CONCAT as CSVTK_CONCAT_REPORT
} from '../../modules/nf-core/csvtk/concat/main'

include { FASTP } from '../../modules/nf-core/fastp/main'
include { BBMAP_BBDUK } from '../../modules/nf-core/bbmap/bbduk/main'
include {
    SEQKIT_STATS as SEQKIT_STATS_INPUT ;
    SEQKIT_STATS as SEQKIT_STATS_TRIMMED ;
    SEQKIT_STATS as SEQKIT_STATS_DEHOSTED
} from '../../modules/local/seqkit/stats/main'
include {
    SEQKIT_STATS_SUMMARY as SEQKIT_STATS_SUMMARY_INPUT ;
    SEQKIT_STATS_SUMMARY as SEQKIT_STATS_SUMMARY_TRIMMED ;
    SEQKIT_STATS_SUMMARY as SEQKIT_STATS_SUMMARY_DEHOSTED ;
    READ_QCREPORT
} from "../../modules/local/misc.nf"
include { DEACON_FILTER } from '../../modules/local/deacon/filter/main'
include { KRAKEN2_KRAKEN2 } from '../../modules/local/kraken2/kraken2/main.nf'
include { BRACKEN_BRACKEN } from '../../modules/local/bracken/bracken/main'
include { BRACKEN_GETTOPMATCHES } from '../../modules/local/bracken/gettopmatches/main'
include {
    FASTQC as FASTQC_INPUT;
    FASTQC as FASTQC_TRIMMED;
    FASTQC as FASTQC_DEHOSTED

 } from '../../modules/nf-core/fastqc/main'


workflow QC_SHORT {
    take:
    short_reads

    main:

    /*
     * Input read statistics
     */
    FASTQC_INPUT(short_reads)

    SEQKIT_STATS_INPUT(short_reads)

    CSVTK_CONCAT_STATS_INPUT(
        SEQKIT_STATS_INPUT.out.stats.map { _cfg, stats -> stats }.collect().map { files ->
            tuple(
                [id: "seqstats.input_illumina"],
                files,
            )
        },
        "tsv",
        "tsv",
    )
    SEQKIT_STATS_SUMMARY_INPUT(CSVTK_CONCAT_STATS_INPUT.out.csv)

    /*
     * trim reads
     */
    def discard_trimmed_pass = false
    def save_trimmed_fail = false
    def save_merged = false
    // Resolve adapter once: Path if set (fail-fast on missing), else []
    def adapter_fasta = []

    if (params.adapter_fasta) {
        def f = file(params.adapter_fasta, checkIfExists: true)
        if (!f.isFile()) {
            error("params.adapter_fasta is not a regular file: ${params.adapter_fasta}")
        }
        def firstChar = f.withReader { it.readLine()?.take(1) }
        if (firstChar != '>') {
            error("params.adapter_fasta is not a valid FASTA (no '>' header): ${params.adapter_fasta}")
        }
        adapter_fasta = f
    }

    //default
    if (params.short_trimmer == 'bbduk') {
        BBMAP_BBDUK(short_reads, adapter_fasta)

        //get rid of zero size contig file and avoid the downstream crash
        BBMAP_BBDUK.out.reads
            .filter { _meta, reads ->
                def readsList = reads instanceof List ? reads : [reads]
                readsList.size() > 0 && readsList.every { f -> f != null && f.exists() && f.size() > 0 }
            }
            .set { trimmed_reads }
    }
    else if (params.short_trimmer == 'fastp') {
        save_trimmed_fail = false
        discard_trimmed_pass = false
        save_merged = false
        FASTP(
            short_reads.map { _meta, fastqs ->
                [_meta, fastqs, adapter_fasta]
            },
            discard_trimmed_pass,
            save_trimmed_fail,
            save_merged,
        )

        //get rid of zero size contig file and avoid the downstream crash

        FASTP.out.reads
            .filter { _meta, reads ->
                def readsList = reads instanceof List ? reads : [reads]
                readsList.size() > 0 && readsList.every { f -> f != null && f.exists() && f.size() > 0 }
            }
            .set { trimmed_reads }
    }
    FASTQC_TRIMMED(trimmed_reads)

    SEQKIT_STATS_TRIMMED(trimmed_reads)

    CSVTK_CONCAT_STATS_TRIMMED(
        SEQKIT_STATS_TRIMMED.out.stats.map { _cfg, stats -> stats }.collect().map { files ->
            tuple(
                [id: "seqstats.trimmed_illumina"],
                files,
            )
        },
        "tsv",
        "tsv",
    )

    SEQKIT_STATS_SUMMARY_TRIMMED(CSVTK_CONCAT_STATS_TRIMMED.out.csv)

    /*
     * Host removal
     */

    trimmed_reads
        .combine(channel.value(params.deacon_refdb))
        .map { meta, fastqs, refdb -> [meta, refdb, fastqs] }
        .set { ch_input_deacon }

    DEACON_FILTER(ch_input_deacon)


    /*
     * Remove zero-size / empty dehosted FASTQ files
     */

    DEACON_FILTER.out.fastq_filtered
        .filter { _meta, reads ->
            def readsList = reads instanceof List ? reads : [reads]
            readsList.every { f -> f != null && f.exists() && f.size() > 0 } && readsList.sum { f -> f.countFastq() } > 0
        }
        .set { qcreads }

    FASTQC_DEHOSTED(qcreads)

    SEQKIT_STATS_DEHOSTED(qcreads)

    CSVTK_CONCAT_STATS_DEHOSTED(
        SEQKIT_STATS_DEHOSTED.out.stats.map { _cfg, stats -> stats }.collect().map { files ->
            tuple(
                [id: "seqstats.dehosted_illumina"],
                files,
            )
        },
        "tsv",
        "tsv",
    )

    SEQKIT_STATS_SUMMARY_DEHOSTED(CSVTK_CONCAT_STATS_DEHOSTED.out.csv)

    /*
     * Taxonomic classification
     */

    KRAKEN2_KRAKEN2(qcreads, params.kraken2_db, false, true)
    //ch_software_versions = ch_software_versions.mix(KRAKEN2_KRAKEN2.out.versions)

    BRACKEN_BRACKEN(KRAKEN2_KRAKEN2.out.report, params.kraken2_db)
    BRACKEN_GETTOPMATCHES(BRACKEN_BRACKEN.out.reports)
    CSVTK_CONCAT_TOPMATCHES(
        BRACKEN_GETTOPMATCHES.out.csv.map { _meta, csv -> csv }.collect().map { csvs ->
            tuple([id: "reads.topmatches_illumina"], csvs)
        },
        'csv',
        'csv',
    )
    // 3. Sort by Sample (col 1) then Platform (col 2)
    CSVTK_SORT(CSVTK_CONCAT_TOPMATCHES.out.csv, 'csv', 'csv')

    READ_QCREPORT(
        "illumina",

        SEQKIT_STATS_SUMMARY_INPUT.out.summary.map { meta, summary ->
            summary
        },
        SEQKIT_STATS_SUMMARY_TRIMMED.out.summary.map { meta, summary ->
            summary
        },
        SEQKIT_STATS_SUMMARY_DEHOSTED.out.summary.map { meta, summary ->
            summary
        },
    )

    emit:
    qcreads
    report_qc = READ_QCREPORT.out.csv
    report_topmatches = CSVTK_SORT.out.sorted
}
