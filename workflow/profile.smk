# 2022 Benjamin J Perry
# MIT License
# Copyright (c) 2022 Benjamin J Perry
# Version: 1.0
# Maintainer: Benjamin J Perry
# Email: ben.perry@agresearch.co.nz

#configfile: "config/config.yaml"


import os


FID, = glob_wildcards("'results/02_kneaddata/{sample}.fastq'")


onstart:
    print(f"Working directory: {os.getcwd()}")
    print("TOOLS: ")
    os.system('echo "  bash: $(which bash)"')
    os.system('echo "  PYTHON: $(which python)"')
    os.system('echo "  CONDA: $(which conda)"')
    os.system('echo "  SNAKEMAKE: $(which snakemake)"')
    print(f"Env TMPDIR = {os.environ.get('TMPDIR', '<n/a>')}")
    os.system('echo "  PYTHON VERSION: $(python --version)"')
    os.system('echo "  CONDA VERSION: $(conda --version)"')


rule all:
    input:
        # expand('results/04_braken/{sample}.GTDB.centrifuge.k2report.T1.bracken.genus.report', sample=FID),
        # expand('results/04_braken/{sample}.GTDB.centrifuge.k2report.T1.bracken.species.report', sample=FID),
        # expand('results/03_humann3Uniref50EC/{sample}_pathcoverage.tsv', sample=FID),
        'results/centrifuge.counts.all.txt',
        'results/centrifuge.counts.bracken.T10.genus.txt',
        # 'results/centrifuge.counts.bracken.T1.species.txt',
        # expand('results/kraken2GTDB/{sample}.GTDB.k2report', sample = FID),
        # expand('results/brackenGenus/{sample}.breport', sample = FID),
        'results/kraken2.bracken.genus.report.txt',



#TODO: consider using an input function to filter the seqkit summary tables for input to the profile.smk pipeline



localrules: generateCentrifugeSampleSheet



rule generateCentrifugeSampleSheet:
    output:
        sampleSheet='resources/centrifugeSampleSheet.tsv',
    threads:2
    shell: 
        './workflow/scripts/generate_centrifuge_sample_sheet.sh -d results/02_kneaddata -p fastq -o {output.sampleSheet} '


rule centrifugeGTDB:
    input:
        sampleSheet='resources/centrifugeSampleSheet.tsv'
    output:
        out=expand('results/03_centrifuge/{sample}.GTDB.centrifuge', sample=FID),
        report=expand('results/03_centrifuge/{sample}.GTDB.centrifuge.report', sample=FID),
    log:
        'logs/centrifuge.GTDB.multi.log'
    conda:
        'centrifuge'
    threads: 32
    resources:
        mem_gb = lambda wildacards, attempt: 140 + ((attempt -1) + 20),
        time = "06:00:00"
    shell:
        'centrifuge ' 
        '-x /bifo/scratch/2022-BJP-GTDB/2022-BJP-GTDB/centrifuge/GTDB '
        '--sample-sheet {input.sampleSheet} '
        '-t '
        '--threads {threads} '
        '&> {log} '



rule centrifugeKrakenReport:
    input:
        centrifuge='results/03_centrifuge/{sample}.GTDB.centrifuge',
    output:
        centrifugeKraken2='results/03_centrifuge/{sample}.GTDB.centrifuge.k2report'
    log:
        'logs/centirifuge){sample}.centrifuge.to.kraken2.log'
    conda:
        'centrifuge'
    threads: 2
    shell:
        'centrifuge-kreport '
        '-x /bifo/scratch/2022-BJP-GTDB/2022-BJP-GTDB/centrifuge/GTDB '
        '{input.centrifuge} > '
        '{output.centrifugeKraken2}'



rule brackenCentrifugeGenus:
    input:
        centrifugeKraken2='results/03_centrifuge/{sample}.GTDB.centrifuge.k2report',
    output:
        braken='results/04_braken/{sample}.GTDB.centrifuge.k2report.T10.bracken.genus',
        brakenReport='results/04_braken/{sample}.GTDB.centrifuge.k2report.T10.bracken.genus.report',
    log:
        'logs/centrifuge/{sample}.centrifuge.bracken.genus.GTDB.log'
    conda:
        'kraken2'
    threads: 2 
    shell:
        'bracken '
        '-d /bifo/scratch/2022-BJP-GTDB/2022-BJP-GTDB/kraken/GTDB '
        '-i {input.centrifugeKraken2} '
        '-o {output.braken} '
        '-w {output.brakenReport} '
        '-r 80 '
        '-l G '
        '-t 10 '
        '&> {log} '


rule brackenCentrifugeSpecies:
    input:
        centrifugeKraken2='results/03_centrifuge/{sample}.GTDB.centrifuge.k2report',
    output:
        braken='results/04_braken/{sample}.GTDB.centrifuge.k2report.T10.bracken.species',
        brakenReport='results/04_braken/{sample}.GTDB.centrifuge.k2report.T10.bracken.species.report',
    log:
        'logs/centrifuge/{sample}.centrifuge.bracken.species.GTDB.log'
    conda:
        'kraken2'
    threads: 2 
    shell:
        'bracken '
        '-d /bifo/scratch/2022-BJP-GTDB/2022-BJP-GTDB/kraken/GTDB '
        '-i {input.centrifugeKraken2} '
        '-o {output.braken} '
        '-w {output.brakenReport} '
        '-r 80 '
        '-l S '
        '-t 10 '
        '&> {log} '


rule humann3Uniref50EC:
    input:
        kneaddataReads='results/02_kneaddata/{sample}.fastq'
    output:
        genes = 'results/03_humann3Uniref50EC/{sample}_genefamilies.tsv',
        pathways = 'results/03_humann3Uniref50EC/{sample}_pathabundance.tsv',
        pathwaysCoverage = 'results/03_humann3Uniref50EC/{sample}_pathcoverage.tsv'
    log:
        'logs/humann3/{sample}.human3.uniref50EC.log'
    conda:
        'biobakery'
    threads: 16
    resources:
        mem_gb= lambda wildcards, attempt: 24 + ((attempt - 1) + 12) 
    message:
        'humann3 profiling with uniref50EC: {wildcards.samples}\n'
    shell:
        'humann3 '
        '--memory-use minimum '
        '--threads {threads} '
        '--bypass-nucleotide-search '
        '--search-mode uniref50 '
        '--protein-database /bifo/scratch/2022-BJP-GTDB/biobakery/humann3/unirefECFilt '
        '--input-format fastq '
        '--output results/03_humann3Uniref50EC '
        '--input {input.kneaddataReads} '
        '--output-basename {wildcards.samples} '
        '--o-log {log} '
        '--remove-temp-output '



rule combineCentrifugeReports:
    input:
        expand('results/03_centrifuge/{sample}.GTDB.centrifuge.k2report', sample=FID),
    output:
        'results/03_centrifuge/rough.counts.all.txt'
    conda:
        'kraken2'
    threads: 2
    shell:
        'combine_kreports.py -o {output} -r {input} '



rule combineBrackenGenusReports:
    input:
        expand('results/04_braken/{sample}.GTDB.centrifuge.k2report.T10.bracken.genus', sample=FID),
    output:
        'results/centrifuge.counts.bracken.T10.genus.txt'
    conda:
        'kraken2'
    threads: 2
    shell:
        'combine_bracken_outputs.py -o {output} --files {input} '



rule combineBrackenSpeciesReports:
    input:
        expand('results/04_braken/{sample}.GTDB.centrifuge.k2report.T10.bracken.species', sample=FID),
    output:
        'results/centrifuge.counts.bracken.T10.species.txt'
    conda:
        'kraken2'
    threads: 2
    shell:
        'combine_bracken_outputs.py -o {output} --files {input} '



rule formatCombinedCentrifugeReport:
    input:
        'results/03_centrifuge/rough.counts.all.txt'
    output:
        'results/centrifuge.counts.all.txt'
    threads: 2
    shell:
        'workflow/scripts/reformat_centrifuge_count_matrix.sh -i {input} -p results/03_centrifuge && '
        'mv results/03_centrifuge/clean.count.matrix.txt {output} '



rule kraken2GTDB:
    # taxonomic profiling 
    input:
        KDRs = 'results/02_kneaddata/{sample}.fastq'
    output: 
        k2OutputGTDB = 'results/kraken2GTDB/{sample}.GTDB.kraken2',
        k2ReportGTDB = 'results/kraken2GTDB/{sample}.GTDB.k2report'
    log:
        'logs/kraken2GTDB/{sample}.kraken2.GTDB.log'
    conda:
        'kraken2'
    threads: 20
    resources: 
        # dynamic memory allocation: start with 400G and increment by 20G with every failed attempt 
        mem_gb=lambda wildcards, attempt: 400 + ((attempt - 1) * 20),
    shell:
        'kraken2 '
        '--use-names '
        '--db /dataset/2022-BJP-GTDB/scratch/2022-BJP-GTDB/kraken/GTDB '
        '-t {threads} '
        '--report {output.k2ReportGTDB} '
        '--report-minimizer-data '
        '{input.KDRs} > {output.k2OutputGTDB}'


rule brackenGenus:
    # compute abundance 
    input:
        k2ReportGTDB = 'results/kraken2GTDB/{sample}.GTDB.k2report'
    output:
        bOutput = 'results/brackenGenus/{sample}.bracken',
        bReport = 'results/brackenGenus/{sample}.breport'
    log:
        'logs/brackenGenus/{sample}.bracken.log'
    conda:
        'envs/bracken.yaml'
    threads: 2
    shell: 
        'kraken2 '
        '-d /dataset/2022-BJP-GTDB/scratch/2022-BJP-GTDB/kraken/GTDB '
        '-i {input.k2ReportGTDB} '
        '-o {output.bOutput} '
        '-w {output.bReport} '
        '-r 80 '
        '-l G '
        '-t 10 ' 
        '&> {log} '


rule brackenMergeGenus: 
    # merge all bracken outputs 
    input: 
        expand('results/brackenGenus/{sample}.bracken', sample = FID),
    output:
        'results/kraken2.bracken.genus.report.txt'
    conda: 
        'kraken2'
    shell:
        'combine_bracken_outputs.py '
        '--files {input} '
        '-o {output}'

