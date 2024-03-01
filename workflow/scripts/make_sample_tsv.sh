#!/bin/bash 

dir="resources/data"
output_file="resources/data/files.tsv" 

echo -e "samplename\tfq1\tfq2" > $output_file 

for fq in $dir/*; do 
    # get the sample name 
    file_name=$(basename $fq)
    echo $file_name 
    sample_name=${file_name%_S*} 
    echo $sample_name
 
    # get the filepaths 
    fq1=$(find $dir -name $sample_name*R1*) 
    echo $fq1 
    fq2=$(find $dir -name $sample_name*R2*)

    # print values to tsv file 
    echo -e "$sample_name\t$fq1\t$fq2" >> $output_file

done 