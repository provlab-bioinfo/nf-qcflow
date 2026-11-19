process SEQKIT_GREP {
    tag "$meta.id"
    label 'process_me'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/4f/4fe272ab9a519cf418160471a485b5ef50ea3f571a8e4555a826f70a4d8243ae/data'
        : 'community.wave.seqera.io/library/seqkit:2.13.0--05c0a96bf9fb2751'}"


    input:
    tuple val(meta), val(patterns)
    path refdb

    output:
    tuple val(meta), path("*.fasta"), emit: fasta
    tuple val("${task.process}"), val('seqkit'), eval('seqkit version | sed "s/seqkit v//"'), emit: versions_seqkit, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    seqkit grep --pattern ${patterns}  ${refdb} -o  ${prefix}.fasta

    """
}
