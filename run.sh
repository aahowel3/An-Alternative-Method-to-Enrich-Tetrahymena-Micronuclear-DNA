#!/bin/bash
#overall usage: bash run.sh (within main folder)

#Data 01
#download and combine reference genomes 
#2020 MAC reference (includes rDNA chromosome chr_181)
curl -o ./data_01/1-upd-Genome-assembly.fasta http://www.ciliate.org/system/downloads/1-upd-Genome-assembly.fasta 
#MIC reference 
wget https://de.cyverse.org/anon-files//iplant/home/rcoyne/public/tetrahymena/MIC/mic.genome.fasta.gz -P ./data_01
gunzip ./data_01/mic.genome.fasta.gz 
#mitchondrial reference 
esearch -db nucleotide -query "NC_003029.1" | efetch -format fasta > ./data_01/NC_003029.1.fasta
#combine and index 
cat ./data_01/1-upd-Genome-assembly.fasta ./data_01/mic.genome.fasta ./data_01/NC_003029.1.fasta > ./data_01/mic_mac_combinedreference_rDNA.fasta
#remove whitespaces introduced by concatenating 
bwa index ./data_01/mic_mac_combinedreference_rDNA.fasta

#pull data from SRA 
fastq-dump --split-files SRR14745909 --outdir ./data_01 
fastq-dump --split-files SRR14745910 --outdir ./data_01

#run trimmomatic and fastqc on raw FACS reads 
bash ./data_01/flowsort_curation_01a.sh ./data_01/*_1.fastq

#Whole cell data 02
subset whole cell reads SRR15681625 
fastq-dump --split-files SRR15681625 --outdir ./wholecell_data_02
bash ./wholecell_data_02/subset_02a.sh 

#Fisher's exact test 03
#align MIC and MAC trimmed FACS reads to combined reference 
bash ./fishers_exact_03/fishers_rerun_2_03a.sh ./data_01/*_1.trim.fastq
#align whole cell subsets to combined reference 
bash ./fishers_exact_03/wholecell_subset/flowsort_curation_wc_2_03b.sh ./wholecell_data_02/*R1.fq

#Simulations 04 
#generate simulated mic, mac, and whole cell data at a 4:64 mic to mac ratio
bash ./simulations_04/wc_simulations_04a.sh
#align simulated whole cell reads to the combined reference genome 
bash ./simulations_04/flowsort_curation_2_wc_04b.sh
#align simulated MIC and MAC reads to the combined reference genome 
bash ./simulations_04/flowsort_curation_2_mic_mac_04c.sh
#generate simulated mic, mac, and whole cell data at a 1:1 mic to mac ratio
bash ./simulations_04/simulations_1x/wc_simulations_1x_04d.sh
#align simulated whole cell reads to the combined reference genome 
bash ./simulations_04/simulations_1x/flowsort_curation_2_wc_04e.sh


#count reads aligned to the MIC or MAC reference for each resulting bam file
#run a fisher's exact test on the resulting counts
bash ./fishers_exact_03/fishers_rerun_count_03c.1.sh
R ./fishers_exact_03/fishers_rerun_ftests_03c.R

#Coverage MDS and IES 05 
#converts IES coordinates in supercontigs to IES coordinates in mic chromosomes
R ./coverage_05/merge_contigs_05a.R
#creates a coverage file of mic samples, mac samples, and wc samples using Samtools depth
bash ./coverage_05/coverage_05b.sh
#for each sample - mic, mac, wholecell loops the coverage files generated by coverage_05b.sh back to analyze_coverage_allchromo_05d.R
#updated format
bash ./coverage_05/mac_coverage/analyze_coverage_allchromo_05c.sh ./coverage_05/mac_coverage/*Mac*
bash ./coverage_05/mic_coverage/analyze_coverage_allchromo_05c.sh ./coverage_05/mac_coverage/*Mic*
bash ./coverage_05/wc_coverage/analyze_coverage_allchromo_05c.sh ./coverage_05/mac_coverage/*SB210*

#IES Retention Scores 06
#creates bedfile of chr, IES_in_chr_start, IES_in_chr_end, and IES name using tsv files in ./coverage folder
bash ./retention_scores_06/make_bedfile_06a.sh ./coverage_05/chr*inmic.tsv
#takes bedfile positions and using bedtools getfasta and the micronucealr reference genome and pulls out all the basepairs in that bedfile range to create MAC+IES reference
bash ./retention_scores_06/make_IESfasta_06b.sh ./retention_scores_06/chr*.bed
#aligns the Mac and Mic flowsorted samples to the mac+IES_reference.fasta reference and creates a bam folder
bash ./retention_scores_06/IRSscore_alignment_2_06c.sh ./data_01/*_1.trim.fastq
#creates a chain file for each chromosome 
R ./retention_scores_06/IRS/mic.mac.chain_perchromosome_06d.R 
#takes chain files 1-5 and mic_inIES files 1-5 and loops them through create_mac_excisionsites_06f.R to create chrX_mac_excisionsites.tsvs for each chromosome
bash ./retention_scores_06/IRS/create_mac_excisionsites_06e.sh ./retention_scores_06/IRS/*chain.tsv*
#calcualtes the IRS+ and IRS-
#length of each chr#IRSscores_mac/micsample.txt is the number of viable IESs 
for file in ./retention_scores_06/IRS/chr*_mac_excisionsites.tsv;
do
base=$(basename $file _mac_excisionsites.tsv)
bash ./retention_scores_06/IRS/calculate_IRS_mac_06g.sh $file > ./retention_scores_06/IRS/${base}IRSscores_macsample.txt
done
for file in ./retention_scores_06/IRS/chr*_mac_excisionsites.tsv;
do
base=$(basename $file _mac_excisionsites.tsv)
bash ./retention_scores_06/IRS/calculate_IRS_mic_06g.sh $file > ./retention_scores_06/IRS/${base}IRSscores_micsample.txt
done
#consolidates scores over all 5 chromosomes and graphs them in a histogram
Rscript ./retention_scores_06/IRS/calculateIRSscores_all_06h.R

#Contamination 
#converts unmapped reads in the bam to fastqs, assembles them with spades, and blasts them
bash ./check_contamination_07/blast_check/mic_contamination/blast_unmapped_07a.sh
bash ./check_contamination_07/blast_check/mac_contamination/blast_unmapped_07a.sh
