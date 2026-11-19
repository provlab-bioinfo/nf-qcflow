process BRACKEN_BRACKEN {
    tag "$meta.id"
    label 'process_low'

    //version 3.x has errors: "Error: no reads found. Please check your Kraken report,
    // added -t 0 solve the problems

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bracken%3A3.1--h9948957_0':
        'biocontainers//bracken%3A3.1--h9948957_0' }"


    input:
    tuple val(meta), path(kraken_report)
    path database

    output:
    tuple val(meta), path(bracken_report)        , emit: reports
    tuple val(meta), path(bracken_report_kraken_style), emit: txt
    tuple val("${task.process}"), val('bracken'), eval('bracken -v | cut -f2 -d"v"'), topic: versions, emit: versions_bracken

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""
    prefix = task.ext.prefix ?: "${meta.id}"
    bracken_report = "${prefix}.bracken_report.tsv"
    bracken_report_kraken_style = "${prefix}.bracken_report.kraken_style.txt"
    //LEVEL          level to estimate abundance at [options: D,P,C,O,F,G,S,S1,etc] (default: S)
    """
    LEVEL="S"

    if [ ! -s "${kraken_report}" ]; then
        echo "Empty report"
        exit 0
    fi

    if ! grep -q \$'\\tS\\t' "${kraken_report}"; then
        if grep -q \$'\\tG\\t' "${kraken_report}"; then LEVEL="G"
        elif grep -q \$'\\tF\\t' "${kraken_report}"; then LEVEL="F"
        elif grep -q \$'\\tO\\t' "${kraken_report}"; then LEVEL="O"
        elif grep -q \$'\\tC\\t' "${kraken_report}"; then LEVEL="C"
        elif grep -q \$'\\tP\\t' "${kraken_report}"; then LEVEL="P"
        elif grep -q \$'\\tK\\t' "${kraken_report}"; then LEVEL="K"
        elif grep -q \$'\\tD\\t' "${kraken_report}"; then LEVEL="D"
        else LEVEL="NA"
        fi
    fi

    echo "Using LEVEL: \$LEVEL"

    if [ "\$LEVEL" = "NA" ]; then
        echo "No suitable taxonomic level found in Kraken report"
        touch '${bracken_report}'
        touch '${bracken_report_kraken_style}'
    else
        bracken ${args} \\
            -d '${database}' \\
            -i '${kraken_report}' \\
            -l \$LEVEL \\
            -o '${bracken_report}' \\
            -w '${bracken_report_kraken_style}' \\
            -t 0
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    bracken_report = "${prefix}.bracken_report.tsv"
    bracken_report_kraken_style = "${prefix}.bracken_report.kraken_style.txt"
    """
    touch ${prefix}.bracken_report.tsv
    touch ${bracken_report_kraken_style}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """
}
