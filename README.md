# plant_virus_blast
Wrapper script for detecting and labelling plant viruses from Nanopore reads 

USAGE: `bash plant_virus_blast.sh "host sci_name" /path/to/Nanopore/fastqs`

This can process one Nanopore barcode directory of files at a time. You need to give it the scientific name (in quotes) of the closest relative to the plant host that has a reference genome in NCBI, along with a relative path to the barcode directory containing the raw Nanopore fastq files you want to process.

The script will handle all file naming and downloads, including downloading a custon BLAST database based on NCBI virus sequences.

This is "use at your own peril" code. It wraps several external programs, including:
 
 - blastn
 - minimap2
 - samtools
 - flye 2.9
 - R 4+ (including tidyverse and ShortRead packages)
 - seqtk

Get those installed and into your local PATH, ensure that the R packages are installed, and you should be good to go. Place the plant_virus_blast.sh file in the main directory you're working in and run it. You'll get a fasta file of contigs, named after their closest virus BLAST match.

If you encounter dependency issues, I will not be checking for them, so good luck!
