process MASHFILTER {
    tag "${meta.id}"
    label 'process_low'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'biocontainers/python:3.12' }"

    input:
    tuple val(meta), path(screen_file)

    output:
    tuple val(meta), path("*keep_best.screen"), emit: screen
    //tuple val(meta), path("*.csv"), emit: csv
        tuple val("${task.process}"), val('python'), eval('python --version 2>&1 | sed -e "s/Python //g"'), emit: versions_python, topic: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    filter_mash.py -i ${screen_file} -o ${prefix}-keep_best.screen ${args}

    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // TODO nf-core: A stub section should mimic the execution of the original module as best as possible
    //               Have a look at the following examples:
    //               Simple example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bcftools/annotate/main.nf#L47-L63
    //               Complex example: https://github.com/nf-core/modules/blob/818474a292b4860ae8ff88e149fbcda68814114d/modules/nf-core/bedtools/split/main.nf#L38-L54
    """
    touch ${prefix}-keep_best.screen

    """
}

process SEQKIT_STATS_SUMMARY {
    tag "$meta.id"

    label 'process_low'

    conda "conda-forge::python=3.12"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/python%3A3.12'
        : 'quay.io/biocontainers/python:3.12'}"



    input:
    tuple val(meta), path(stats)

    output:
    tuple val(meta), path("*_summary.tsv"), emit: summary
    tuple val("${task.process}"), val('python'), eval('python --version 2>&1 | sed -e "s/Python //g"'), emit: versions_python, topic: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    seqstats_summary.py \\
        --input $stats \\
        --output ${prefix}_summary.tsv
    """
}
process READ_QCREPORT {
    tag "read_qc_report.${platform}"
    label 'process_low'

    conda "conda-forge::pandas=2.2.1"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/pandas:2.2.1'
        : 'quay.io/biocontainers/pandas:2.2.1'}"

    input:
    val platform
    path input_summary
    path trimmed_summary
    path dehosted_summary

    output:
    path "${prefix}_${platform}.csv", emit: csv
    tuple val("${task.process}"), val('python'), eval('python --version 2>&1 | sed -e "s/Python //g"'), emit: versions_python, topic: versions

    script:
    prefix = task.ext.prefix ?: "read.qcreport"
    """
    read_qc_report.py \\
        --input ${input_summary} \\
        --trimmed ${trimmed_summary} \\
        --dehosted ${dehosted_summary} \\
        --output ${prefix}_${platform}.csv
    """
}
process CREATE_MASTER_REPORT {
    tag "master_report"
    label 'process_low'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'biocontainers/python:3.12' }"

    input:
    path(all_consensus_fasta)
    path(all_consensus_report)
    path(read_qc_report)
    path(typing_report)
    path(nextclade_report)
    val(flu_db_ver)


    output:
    path("${prefix}.tsv"), emit: master_report
    tuple val("${task.process}"), val('python'), eval('python --version 2>&1 | sed -e "s/Python //g"'), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "master"

    """
    create_master_report.py \
        -f ${all_consensus_fasta} \
        --consensus-report ${all_consensus_report} \
        --read-qc-report ${read_qc_report} \
        --typing-report ${typing_report} \
        --nextclade-report ${nextclade_report} \
        --flu-db-ver ${flu_db_ver} \
        --nf-fluab-ver ${workflow.manifest.version} \
        -o ${prefix}.tsv
    """
}
