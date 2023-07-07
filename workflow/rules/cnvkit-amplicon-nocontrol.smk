bedtargets = 'results/cnvkit/'+bedname+'_target.bed'
bedname=bedname

rule cnvkit_autobin:
    input:
        bams = expand("results/bam_sorted_bwa/{sample}_sorted.bam", sample=glob_wildcards("results/bam_sorted_bwa/{sample}_sorted.bam").sample),
        targets = config["bed"],
        access = config["mappability"],
    output:
        output_target = 'results/cnvkit/{bedname}_target.bed',
        output_antitarget = 'results/cnvkit/{bedname}_antitarget.bed',
    params:
        extra = '--method amplicon',
        samplenames = samples.index
    threads: 1
    # wrapper:
    #     'http://dohlee-bio.info:9193/cnvkit/autobin',
    shell:
        'cnvkit.py autobin {input.bams} --targets {input.targets} --access {input.access} {params.extra}'


rule cnvkit_coverage:
    input:
        bam = 'results/bam_sorted_bwa/{sample}_sorted.bam',
        targets = 'results/cnvkit/'+bedname+'_target.bed',
        antitargets = 'results/cnvkit/'+bedname+'_antitarget.bed',
    output:
        target_coverage = 'results/cnvkit/{sample}.targetcoverage.cnn',
        antitarget_coverage = 'results/cnvkit/{sample}.antitargetcoverage.cnn',
    params:
        extra = '',
    threads: 1
    # wrapper:
    #     'http://dohlee-bio.info:9193/cnvkit/coverage'
    shell:
        'cnvkit.py coverage {input.bam} {input.targets} -o {output.target_coverage} {params.extra} && '
        'cnvkit.py coverage {input.bam} {input.antitargets} -o {output.antitarget_coverage} {params.extra}'

rule cnvkit_ref_generic:
    input:
        fasta=config["ref"],
        targets = bedtargets
    output:
        FlatReference_cnn = 'results/cnvkit/FlatReference.cnn',
    params:
        extra = '',
    threads: 1
    shell:
        'cnvkit.py reference -o {output.FlatReference_cnn} -f {input.fasta} -t {input.targets} {params.extra}'

rule cnvkit_fix:
    input:
        target_coverage = 'results/cnvkit/{sample}.targetcoverage.cnn',
        antitarget_coverage = 'results/cnvkit/{sample}.antitargetcoverage.cnn',
        reference = 'results/cnvkit/FlatReference.cnn',
    output:
        'results/cnvkit/{sample}.cnr'
    params:
        extra = '',
    threads: 1
    # wrapper:
    #     'http://dohlee-bio.info:9193/cnvkit/fix'
    shell:
        'cnvkit.py fix {input.target_coverage} {input.antitarget_coverage} {input.reference} -o {output} {params.extra}'

rule cnvkit_segment:
    input:
        copy_ratios = 'results/cnvkit/{sample}.cnr',
    output:
        'results/cnvkit/{sample}.cns',
    params:
        extra = '',
    threads: 1
    # wrapper:
    #     'http://dohlee-bio.info:9193/cnvkit/segment'
    shell:
        'cnvkit.py segment {input.copy_ratios} -o {output} {params.extra}'

rule cnvkit_scatter:
    input:
        copy_ratio = 'results/cnvkit/{sample}.cnr',
        segment = 'results/cnvkit/{sample}.cns',
    output:
        'results/cnvkit/{sample}_scatter.cnv.pdf'
    params:
        # Optional parameters. Omit if unneeded.
        extra = '',
        # Plot segment lines in this color. value can be any string
        # accepted by matplotlib, e.g. 'red' or '#CC0000'
        #segment_color = '',
        # Plot title. [Default: sample ID, from filename or -i]
        #title = '',
    threads: 1
    log: 'results/cnvkit/{sample}.log'
    # wrapper:
    #     'http://dohlee-bio.info:9193/cnvkit/scatter'
    shell:
        'cnvkit.py scatter {input.copy_ratio} --segment {input.segment} -o {output} {params.extra}'

rule cnvkit_diagram:
    input:
        copy_ratio = 'results/cnvkit/{sample}.cnr',
        segment = 'results/cnvkit/{sample}.cns',
    output:
        'results/cnvkit/{sample}_diagram.cnv.pdf'
    params:
        # Optional parameters. Omit if unneeded.
        extra = '',
        # Plot segment lines in this color. value can be any string
        # accepted by matplotlib, e.g. 'red' or '#CC0000'
        #segment_color = '',
        # Plot title. [Default: sample ID, from filename or -i]
        #title = '',
    threads: 1
    log: 'results/cnvkit/{sample}.log'
    # wrapper:
    #     'http://dohlee-bio.info:9193/cnvkit/diagram'
    shell:
        'cnvkit.py diagram {input.copy_ratio} --segment {input.segment} -o {output} {params.extra}'

# rule write_end_of_cnvkit:
#     input:
#         'results/cnvkit/{sample}_scatter.cnv.pdf',
#         'results/cnvkit/{sample}_diagram.cnv.pdf',
#     output:
#         'results/cnvkit/{sample}.cnvkit.done'
#     shell:
#         'touch {output}'

# rule cnvkit-batch-amplicon-nocontrol:
#     input:
#         fasta=config["ref"],
#         map="results/bam_sorted_bwa/{sample}_sorted.bam",
#         access=config["mappability"]
#     output:
#         targetbed="results/cnvkit/{bedname}.target.bed",
#         antitargetbed="results/cnvkit/{bedname}.antitarget.bed",
#         scatter="{sample}_sorted-scatter.png",
#         diagram="{sample}_sorted-diagram.pdf",
#         targetcoverage="{sample}_sorted.targetcoverage.cnn",
#         cns="{sample}_sorted.cns",
#         cnr="{sample}_sorted.cnr",
#         cnr="{sample}_sorted.cnr",
#         callcns="{sample}_sorted.call.cns",
#         bintestcns="{sample}_sorted.bintest.cns",
#         antitargetcoveragecnn="{sample}_sorted.antitargetcoverage.cnn",
#         callcns="{sample}_sorted.call.cns"
#     message:
#         "Running cnvkit batch amplicon no control for {sample}"
#     threads: 8
#     log:
#         "logs/cnvkit/{sample}_sorted.log"
#     conda:
#         "envs/cnvkit.yaml"
#     shell:
#         ""
        