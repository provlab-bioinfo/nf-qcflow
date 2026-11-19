process DEACON_FILTER {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/deacon:0.15.0--hdd79491_0':
        'quay.io/biocontainers/deacon:0.15.0--hdd79491_0' }"


    input:
    tuple val(meta), path(index), path(reads)

    output:
    tuple val(meta), path("${prefix}*.fastq.gz") , emit: fastq_filtered
    tuple val(meta), path("${prefix}*.json"), emit: log
    tuple val("${task.process}"), val('deacon'), eval('deacon --version | head -n1 | sed "s/deacon //g"'), emit: versions_deacon, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def platform = meta.platform ?: 'unknown'
    def base_prefix = task.ext.prefix ?: meta.id
    prefix = "${base_prefix}.${platform}"

    def read_type = (reads instanceof List) ? "-o ${prefix}.deacon_1.fastq.gz -O ${prefix}.deacon_2.fastq.gz" : " -o ${prefix}.deacon.fastq.gz"

    """
    deacon \\
        filter \\
        --threads ${task.cpus} \\
        $args \\
	    --summary ${prefix}.deacon.json \\
        -d $index \\
        $reads \\
        ${read_type}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        deacon: \$(deacon --version | head -n1 | sed 's/deacon //g')
    END_VERSIONS
    """

}
