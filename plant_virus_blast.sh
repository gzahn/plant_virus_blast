#!/bin/bash
set -ueo pipefail

# To run: plant_virus_blast "host sci_name" /path/to/Nanopore/fastqs

# Depends: blastn, minimap2, samtools, flye 2.9+, R 4+, seqtk,
# external files at:
# Zahn, Geoffrey. (2022). NCBI Virus BLAST Database [Data set]. Zenodo. https://doi.org/10.5281/zenodo.7250521


# Create directory structure
HOST_DIR=./Host_Reference
MAIN_DIR=$(pwd)
HOST_REF=$HOST_DIR/complete_genome.fasta.gz
SEQS_DIR=$2
SEQS_FILE=$MAIN_DIR/complete_nanopore_reads.fq.gz
outputsam=$MAIN_DIR/host_alignment.sam
unmappedsam=$MAIN_DIR/non_host_reads.sam
unmappedfq=$MAIN_DIR/non_host_reads.fastq.gz
ASSEMBLY_DIR=./Assembly
ASSEMBLY_FILE=$ASSEMBLY_DIR/assembly.fasta
BLAST_DIR=./BLAST
BLAST_OUT=$BLAST_DIR/top_BLAST_hits_NCBI_VIRUS.txt

if [ ! -d "$HOST_DIR" ]; then
mkdir $HOST_DIR
else
echo "Host directory exists"
fi

if [ ! -d "$ASSEMBLY_DIR" ]; then
mkdir $ASSEMBLY_DIR
else
echo "Assembly directory exists"
fi

if [ ! -d "$BLAST_DIR" ]; then
mkdir $BLAST_DIR
else
echo "BLAST output directory exists"
fi





# BLAST DATABASE #######################################################################

# Download custom BLAST Database if not present in current working directory

FILE=NCBI_VIRUS.nsq
if [ -f "$FILE" ]; then
    echo "Virus database already exists. Skipping download."
else 
wget -O NCBI_VIRUS.ndb https://zenodo.org/record/7250323/files/NCBI_VIRUS.ndb?download=1
wget -O NCBI_VIRUS.nhr https://zenodo.org/record/7250323/files/NCBI_VIRUS.nhr?download=1
wget -O NCBI_VIRUS.nin https://zenodo.org/record/7250323/files/NCBI_VIRUS.nin?download=1
wget -O NCBI_VIRUS.not https://zenodo.org/record/7250323/files/NCBI_VIRUS.not?download=1
wget -O NCBI_VIRUS.nsq https://zenodo.org/record/7250323/files/NCBI_VIRUS.nsq?download=1
wget -O NCBI_VIRUS.ntf https://zenodo.org/record/7250323/files/NCBI_VIRUS.ntf?download=1
wget -O NCBI_VIRUS.nto https://zenodo.org/record/7250323/files/NCBI_VIRUS.nto?download=1
fi

FILE=virus_ids.txt
if [ -f "$FILE" ]; then
    echo "Virus IDs dictionary already exists. Skipping download."
else
wget -O virus_ids.txt https://zenodo.org/record/7250500/files/virus_ids.txt?download=1
fi

FILE=augment_fasta_headers.R
if [ -f "$FILE" ]; then
    echo "R script already present. Skipping download."
else
wget -O augment_fasta_headers.R https://zenodo.org/record/7250521/files/augment_fasta_headers.R?download=1
fi


# NCBI datasets program #################################################################

# Download datasets program from NCBI, if not present
FILE=datasets
if [ -f "$FILE" ]; then
    echo "datasets program already exists. Skipping download."
else
curl -o datasets 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/LATEST/linux-amd64/datasets'
curl -o dataformat 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/LATEST/linux-amd64/dataformat'
chmod +x datasets dataformat
echo $(./datasets version) >> dataset_version.txt
fi


# HOST GENOME ############################################################################

# Download host reference genome. You must find the closest host relative on NCBI with a published genome assembly


if [ ! -f $HOST_REF ]; then

./datasets download genome taxon "$1" --reference --filename "Host.zip"
mv Host.zip $HOST_DIR
cd $HOST_DIR
unzip Host.zip ncbi_dataset/data/*
rm Host.zip
find . -name "*.fna" | grep -v "rna.fna" | grep -v "cds_" | xargs cat | seqtk seq > complete_genome.fasta
gzip complete_genome.fasta
rm -rf ncbi_dataset
cd $MAIN_DIR
else
echo "Host reference genome already exists. Skipping download. Delete it and re-run script if you need to."
fi

echo "Combining nanopore read files into one query file..."

# Combine all Nanopore files into one fastq file
cd $SEQS_DIR
cat *.gz > $SEQS_FILE
cd $MAIN_DIR

echo "Aligning sequences to host reference genome..."

# run minimap alignment to host genome
minimap2 -ax splice -uf -k14 -t 16 $HOST_REF $SEQS_FILE > $outputsam


echo "Removing known plant host reads..."

# extract unmapped (non-host) reads with samtools
samtools sort | samtools view -f 4 $outputsam > $unmappedsam

# extract fastq
samtools fastq $unmappedsam | gzip > $unmappedfq


################## FLYE Assembly ######################

echo "Assembling contigs from remaining reads with Flye..."

# document versions
echo $(flye -v) > flye_version.txt


# run Flye

flye --meta -t 12 --nano-raw $unmappedfq -o $ASSEMBLY_DIR

cat $ASSEMBLY_FILE | seqtk seq > $ASSEMBLY_FILE.formatted

ASSEMBLY_FILE=$ASSEMBLY_FILE.formatted

# BLAST Against custom virus database #####################################

echo "Running BLASTn on assembled contigs against custom NCBI Virus database..."

blastn -query $ASSEMBLY_FILE -db NCBI_VIRUS -outfmt '6 qseqid sseqid sskingdom ssciname sblastname pident evalue length bitscore gaps' -out $BLAST_OUT -num_threads 16 -max_target_seqs 1

# use those BLAST matches to pull matching seqs from non-host fasta
grep -A 1 -Fwf <(cat $BLAST_OUT | cut -f1 | sort -u) $ASSEMBLY_FILE | grep -v "^--$" > ${BLAST_OUT/.txt/.fasta}


# Augment fasta headers with R script #####################################

echo "Running R script to augment fasta headers..."

Rscript augment_fasta_headers.R

seqtk seq final_renamed.fasta > Virus_Contigs_with_Taxonomy.fasta

echo "Final output file is named Virus_Contigs_with_Taxonomy.fasta"
