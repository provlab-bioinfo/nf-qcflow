process BRACKEN_GETTOPMATCHES {
    label 'process_single'

    conda "conda-forge::python=3.12"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.12' :
        'biocontainers/python:3.12' }"

    input:
    tuple val(meta), path(default_bracken_output)

    output:
    tuple val(meta), path("*.csv"), emit: csv
    tuple val("${task.process}"), val('python'), eval('python --version 2>&1 | sed -e "s/Python //g"'), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '1.2' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    extract_top_bracken_csv.py ${default_bracken_output} ${meta.id} ${meta.platform} > ${prefix}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        combine_kreports.py: ${VERSION}
    END_VERSIONS
    """

}
