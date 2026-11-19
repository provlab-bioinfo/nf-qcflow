process SEQKIT_STATS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/4f/4fe272ab9a519cf418160471a485b5ef50ea3f571a8e4555a826f70a4d8243ae/data'
        : 'community.wave.seqera.io/library/seqkit:2.13.0--05c0a96bf9fb2751'}"


    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.tsv"), emit: stats
    tuple val("${task.process}"), val('seqkit'), eval('seqkit version | sed "s/seqkit v//"'), emit: versions_seqkit, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def platform = meta.platform
    def read_type = meta.single_end ? 'single' : 'paired'

    """
    seqkit stats \\
        $args \\
        ${reads} \\
        -o ${prefix}.tsv

    awk -v sample="${meta.id}" \\
        -v platform="${platform}" \\
        -v read_type="${read_type}" '
    BEGIN {
        OFS="\\t"
    }
    NR == 1 {
        print "sample", "platform", "read_type", \$0
        next
    }
    {
        print sample, platform, read_type, \$0
    }' ${prefix}.tsv > ${prefix}.tmp.tsv

    mv ${prefix}.tmp.tsv ${prefix}.tsv

    """
}
