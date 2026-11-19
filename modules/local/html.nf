process COPY_HTML_DIR {
    tag "html_report"
    label 'process_single'

    input:
    path sourceDir

    output:
    path "**", emit: files

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    cp -a ${sourceDir}/. .
    """
}

process COPY_VERSIONS_TO_HTMLDIR {
    tag "copy_versions_to_html"
    label 'process_single'

    input:
    path versions_yml

    output:
    path "data/qcflow_software_versions.yml", emit: versions_yml

    script:
    """
    mkdir -p data
    cp ${versions_yml} data/qcflow_software_versions.yml
    """
}
process CSV2JSON_FOR_HTML_DATATABLE {
    tag "$meta.id"
    label 'process_single'

    conda "conda-forge::pandas=1.4.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.4.3' :
        'biocontainers/pandas:1.4.3' }"

    input:
    tuple val(meta), path(csv)

    output:
    tuple val(meta), path("*.json"), emit: json
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"


    """
    csv2json.py ${args} ${csv} ${prefix}.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        pandas: \$(python -c "import pkg_resources; print(pkg_resources.get_distribution('pandas').version)")
    END_VERSIONS
    """
}
