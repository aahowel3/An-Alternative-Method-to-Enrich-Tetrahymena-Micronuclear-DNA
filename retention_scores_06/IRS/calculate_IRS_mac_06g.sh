while IFS="	" read -r IES_fullID mac_scaffoldstart excision_start_c excision_end_c

do 
	IESplus=$(samtools view ./retention_scores_06/bam_IRS2/SRR14745909_tomac_all+IES_sorted_rmdup.bam $IES_fullID | wc -l)
	IESminus=$(samtools view ./retention_scores_06/bam_IRS2/SRR14745909_tomac_all+IES_sorted_rmdup.bam $mac_scaffoldstart:$excision_start_c-$excision_end_c | wc -l )
	printf "$IES_fullID\t$IESplus\t$IESminus\n" 
done < $1


