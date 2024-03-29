#!/bin/bash 

input_file="resources/data/$1" 
output_file="resources/data/files_tobe_analysed.tsv" 

echo -e "sample\tfq1\tfq2" > $output_file 

while IFS= read -r file_name; do  
    # get the sample name  
    sample_name=${file_name%_S*} 
 
    # get the filepaths 
    fq1=$(find -name $sample_name*R1*)
    fq2=$(find -name $sample_name*R2*)

    # remove ./ at beginning
    fq1_name=${fq1##./}
    fq2_name=${fq2##./}

    # print values to tsv file 
    echo -e "$sample_name\t$fq1_name\t$fq2_name" >> $output_file
    echo "$sample_name added" 

done < "$input_file"