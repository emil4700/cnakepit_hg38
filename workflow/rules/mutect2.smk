#ref_ref = str(Path("results") / "reference" / ref_file.stem) 
import os
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider

HTTP = HTTPRemoteProvider()

rule get_gnomad:
    input:
        HTTP.remote("www.bcgsc.ca/downloads/morinlab/reference/af-only-gnomad.hg38.vcf.gz", keep_local=True)
    output:
        config["germline-resource"]
    threads: 1
    shell:
        "mv {input} {output}"

rule get_gnomad_index:
    input:
        HTTP.remote("www.bcgsc.ca/downloads/morinlab/reference/af-only-gnomad.hg38.vcf.gz.tbi", keep_local=True)
    output:
        config["germline-resource-index"]
    threads: 1
    shell:
        "mv {input} {output}"

rule get_common_biallelic:
    input:
        HTTP.remote("http://storage.googleapis.com/gatk-best-practices/somatic-hg38/small_exac_common_3.hg38.vcf.gz", keep_local=True)
    output:
        config["common-biallelic"]
    threads: 1
    shell:
        "mv {input} {output}"

rule get_common_biallelic_index:
    input:
        HTTP.remote("http://storage.googleapis.com/gatk-best-practices/somatic-hg38/small_exac_common_3.hg38.vcf.gz.tbi", keep_local=True)
    threads: 1
    output:
        config["common-biallelic-index"]
    shell:
        "mv {input} {output}"

rule mutect2_bam:
    input:
        fasta=config["ref"],
        map="results/bam_sorted_bwa/{sample}_sorted.bam",
        dict="resources/reference/hg38.dict",
        idx="results/bam_sorted_bwa/{sample}_sorted.bam.bai",
        targets=config["bed_w_chr"],
        gnomad=config["germline-resource"],
        gnomad_index=config["germline-resource-index"]
    output:
        vcf="results/mutect2/unfiltered/{sample}.vcf.gz",
        f1r2="results/mutect2/f1r2/{sample}.tar.gz"
    #message:
        #"Testing Mutect2 with {wildcards.sample}"
    benchmark: "benchmarks/mutect2_bam/{sample}.txt"
    params:
        extra="--genotype-germline-sites true --genotype-pon-sites true --interval-padding 75"
    threads: 16
    log:
        "logs/mutect2/{sample}.log",
    conda:
        "../envs/primary_env.yaml"
    shell:
        "gatk Mutect2 -R {input.fasta} -I {input.map} -L {input.targets} -O {output.vcf} {params.extra} --germline-resource {input.gnomad} --f1r2-tar-gz {output.f1r2} --tmp-dir ${{TMPDIR}} &> {log}"

rule read_orientation_model:
    input:
        f1r2="results/mutect2/f1r2/{sample}.tar.gz",
        idx="results/bam_sorted_bwa/{sample}_sorted.bam.bai"
    output:
        "results/mutect2/read_orientation_model/{sample}.tar.gz"
    benchmark: "benchmarks/read_orientation_model/{sample}.txt"
    threads: 8
    log:
        "logs/read_orientation_model/{sample}.log"
    conda:
        "../envs/primary_env.yaml"
    shell:
        "gatk LearnReadOrientationModel -I {input.f1r2} -O {output} --tmp-dir ${{TMPDIR}} &> {log}"

rule get_pile_up_summaries:
    input:
        bam="results/bam_sorted_bwa/{sample}_sorted.bam",
        common=config["common-biallelic"],
    output:
        "results/mutect2/pile_up_summaries/{sample}.table"
    benchmark: "benchmarks/pile_up_summaries/{sample}.txt"
    threads: 8
    log:
        "logs/pile_up_summaries/{sample}.log"
    conda:  
        "../envs/primary_env.yaml"
    shell:
        "gatk GetPileupSummaries -I {input.bam} -V {input.common} -L {input.common} -O {output} --tmp-dir ${{TMPDIR}} &> {log}"

rule calculate_contamination:
    input:
        pileup="results/mutect2/pile_up_summaries/{sample}.table",
        reference=config["ref"],
        dict="resources/reference/hg38.dict"
    output:
        "results/mutect2/contamination/{sample}.txt"
    benchmark: "benchmarks/calculate_contamination/{sample}.txt"
    threads: 8
    log:
        "logs/calculate_contamination/{sample}.log"
    conda:
        "../envs/primary_env.yaml"
    shell:
        "gatk CalculateContamination -I {input.pileup} -O {output} --tmp-dir ${{TMPDIR}} &> {log}"

# rule mutect2_ref_dict:
#     input:
#         config["ref"]
#     output:
#         "resources/reference/hg38.dict"
#     conda:
#         "../envs/stats.yaml"
#     log:
#         "logs/mutect2_dict/mutect2_dict.log"
#     shell:
#         "samtools dict {input} > {output} 2> {log}"

# instead, get the dict from the web
rule get_ref_dict:
    input:
        HTTP.remote("storage.googleapis.com/genomics-public-data/resources/broad/hg38/v0/Homo_sapiens_assembly38.dict", keep_local=True)
    output:
        "resources/reference/hg38.dict"
    threads: 1
    benchmark: "benchmarks/get_ref_dict.log"
    shell:
        "mv {input} {output}"

rule filter_mutect_calls:
    input:
        vcf="results/mutect2/unfiltered/{sample}.vcf.gz",
        reference=config["ref"],
        rom="results/mutect2/read_orientation_model/{sample}.tar.gz",
        contamination_table="results/mutect2/contamination/{sample}.txt"
    threads: 8
    log:
        "logs/filter_mutect_calls/{sample}.log",
    conda:
        "../envs/primary_env.yaml"
    output:
        vcf_filt="results/mutect2/filtered/{sample}_filtered.vcf.gz",
    benchmark: "benchmarks/filter_mutect_calls/{sample}.txt"
    shell:
        "gatk FilterMutectCalls -R {input.reference} -V {input.vcf} --orientation-bias-artifact-priors {input.rom} --contamination-table {input.contamination_table}  -O {output.vcf_filt} --tmp-dir ${{TMPDIR}} &> {log}"

# for CNVkit, extract only variants classified as germline
rule extract_germline_variants:
    input:
        "results/mutect2/filtered/{sample}_filtered.vcf.gz"
    log: 
        "logs/extract_germline_variants/{sample}.log"
    output:
    threads: 1
        "results/mutect2/germline/{sample}_germline.vcf.gz"
    benchmark:
        "benchmarks/extract_germline_variants/{sample}.txt"
    shell:
        """bcftools view -i 'FILTER~"germline"' {input} | bgzip -c > {output} &> {log}"""