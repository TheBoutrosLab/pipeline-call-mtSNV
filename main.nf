nextflow.enable.dsl=2

include {
    run_validate_PipeVal as validate_input_PipeVal
    run_validate_PipeVal as validate_output_PipeVal
} from './external/pipeline-Nextflow-module/modules/PipeVal/validate/main.nf'

include { extract_mtDNA } from './module/extract_mtDNA_workflow.nf'
include { align_mtDNA } from './module/align_mtDNA_MToolBox_workflow'
include { call_mtSNV } from './module/call_mtSNV_mitoCaller_workflow'

log.info """\
======================================
C A L L - M T S N V
======================================
Boutros Lab

    Current Configuration:
    - pipeline:
        name: ${workflow.manifest.name}
        version: ${workflow.manifest.version}

    - input:
        ${params.input_string}
        gmapdb = ${params.gmapdb}
        mt_reference_genome = ${params.mt_ref_genome_dir}
        cram_reference_genome = ${params.cram_reference_genome}

    - output:
        output_dir: ${params.output_dir_base}

    - options:
        sample_mode = ${params.sample_mode}
        save_intermediate_files = ${params.save_intermediate_files}
        cache_intermediate_pipeline_steps = ${params.cache_intermediate_pipeline_steps}

    ------------------------------------
    Starting workflow...
    ------------------------------------
    """
    .stripIndent()

Channel
    .fromList(params.input_list)
    .set { ich }

Channel
    .fromList(params.validation_list)
    .set { input_validation }

workflow{

    meta_base = Channel.value([
        output_dir_base: params.output_dir_base,
        log_output_dir: params.log_output_dir
        ])

    input_validate_meta = meta_base.map{ base_m ->
        [
            docker_image: params.pipeval_docker_image,
            validate_extra_args: params.getOrDefault('validate_extra_args', '')
        ] + base_m
    }

    output_validate_meta = meta_base.map{ base_m ->
        [
            docker_image: params.pipeval_docker_image
        ] + base_m
    }

    validate_input_PipeVal(input_validate_meta.combine(input_validation))

    validate_input_PipeVal.out.validation_result.collectFile(
        name: "input_validation.txt",
        storeDir: "${params.output_dir_base}/validation"
    )

    validate_input(input_validate_meta, input_validation)

    extract_mtDNA(ich)

    align_mtDNA(extract_mtDNA.out.extracted_mt_reads)

    call_mtSNV(align_mtDNA.out.bam_for_mitoCaller)

    validate_output_PipeVal(input_validate_meta.combine(align_mtDNA.out.bam_ch.mix(call_mtSNV.out.vcf_gz)))

    validate_output_PipeVal.out.validation_result.collectFile(
        name: "output_validation.txt",
        storeDir: "${params.output_dir_base}/validation"
    )
}
