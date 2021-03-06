#!/bin/bash

ref=$1
bin=$2
cis_loop=$3
trans_loop=$4
name=$5
genome=$6


#----------------------------------------Distance & Length Correction-----------------------------------------------------------------------#
cat $cis_loop | awk '{if($4<=2000000)print $0}' | $bin/merge_sorted_frag_loop.pl - $ref/$genome.within_2Mb.frag_pair >frag_loop.$name.within_2Mb.without.blacklist.full
if [ $6 = "--no-GC-map" ];then
        $bin/get_group_statistics_no.pl frag_loop.$name.within_2Mb.without.blacklist.full $ref/$genome.HindIII.frag.bed $ref/$genome.group.frag_length.range $ref/group.frag_dist.range >loop_statistics.by_group.without.blacklist
        $bin/get_loop_lambda.pl frag_loop.$name.within_2Mb.without.blacklist.full $ref/$genome.HindIII.frag.bed $ref/$genome.group.frag_length.range $ref/group.frag_dist.range loop_statistics.by_group >$name.loop.after_length_dist
        rm frag_loop.$name.within_2Mb.without.blacklist.full loop_statistics.by_group.without.blacklist
else
        $bin/get_group_statistics.pl frag_loop.$name.within_2Mb.without.blacklist.full $ref/$genome.HindIII.frag.bed $ref/$genome.group.frag_length.range $ref/group.frag_dist.range $ref/$genome.frag.gc.map >loop_statistics.by_group.without.blacklist
        $bin/get_loop_lambda.pl frag_loop.$name.within_2Mb.without.blacklist.full $ref/$genome.HindIII.frag.bed $ref/$genome.frag.gc.map $ref/$genome.group.frag_length.range $ref/group.frag_dist.range loop_statistics.by_group.without.blacklist >$name.loop.after_length_dist
        rm frag_loop.$name.within_2Mb.without.blacklist.full loop_statistics.by_group.without.blacklist

        #----------------------------------------Trans GC Correction--------------------------------------------------------------------------------#
        cat $trans_loop | $ref/remove_outlier.py $ref/$genome.blacklist.frag >$name.trans_loop.without.blacklist
        $bin/get_trans_avg_by_GC.pl $name.trans_loop.without.blacklist $ref/$genome.group.frag_GC.range $ref/$genome.frag.gc.map $ref/trans.group.count.by.GC 0.2 >avg_trans_count.by.GC_group
        $bin/get_corr_factor_by_GC.pl avg_trans_count.by.GC_group > lambda_correction.by.GC_group
        $bin/get_loop_lambda_GC_correct.pl $name.loop.after_length_dist $ref/$genome.group.frag_GC.range $ref/$genome.frag.gc.map lambda_correction.by.GC_group >$name.loop.after_GC
        rm $name.loop.after_length_dist avg_trans_count.by.GC_group
fi


#---------------------------------------Visibility Correction--------------------------------------------------------------------------------#
if [ $6 = "--no-GC-map" ];then
        $bin/get_trans_avg_by_GC.pl $name.trans_loop.without.blacklist $ref/$genome.group.frag_length.range $ref/$genome.frag.length.map $ref/trans.group.count.by.length 0.2 >avg_trans_count.by.length_group
        $bin/get_corr_factor_by_GC.pl avg_trans_count.by.length_group > lambda_correction.by.length_group 
        $bin/sum_frag_reads_no.py $ref/$genome.frag.length.map lambda_correction.by.length_group $ref/$genomegroup.frag_length $name.trans_loop.without.blacklist >frag.trans.reads.sum
        $bin/test_frag_corr_no.py frag.trans.reads.sum $ref/$genome.frag.gc.map $name.loop.after_length_dist >$name.loop.after_vis
else
        $bin/get_trans_avg_by_GC.pl $name.trans_loop.without.blacklist $ref/$genome.group.frag_length.range $ref/$genome.frag.length.map $ref/trans.group.count.by.length 0.2 >avg_trans_count.by.length_group
        $bin/get_corr_factor_by_GC.pl avg_trans_count.by.length_group > lambda_correction.by.length_group
        $bin/sum_frag_reads.py $ref/$genome.frag.gc.map $ref/$genome.frag.length.map lambda_correction.by.GC_group lambda_correction.by.length_group $ref/$genome.group.frag_GC.range $ref/$genome.group.frag_length $name.trans_loop.without.blacklist >frag.trans.reads.sum
        $bin/test_frag_corr.py frag.trans.reads.sum $ref/$genome.frag.gc.map $name.loop.after_GC >$name.loop.after_vis
fi
rm $name.loop.after_GC frag.trans.reads.sum avg_trans_count.by.length_group lambda_correction.by.GC_group lambda_correction.by.length_group

#---------------------------------------Model Evaluation------------------------------------------------------------------------------------#
#$bin/split_list_by_group.pl $ref/lambda_group.tab $name.loop.after_vis
#R --vanilla < model_fit.r
#rm data_list.group.* hist.group.*

#--------------------------------------Cal P_val and merge to anchor----------------------------------------------------------------------------#
ln -s $ref/$genome.HindIII.frag.bed
ln -s $ref/frag.2.all.5kb.anchor
cp $bin/fragdata_to_anchordata.pl $bin/batch_anchor_by_chrom.pl $bin/get_anchor_pval.r ./
./batch_anchor_by_chrom.pl $genome.HindIII.frag.bed $name.loop.after_vis frag.2.all.5kb.anchor
for i in {1..22} X Y;do
        cat temp.by.chrom/anchor_2_anchor.loop.chr$i.p_val >> anchor_2_anchor.loop.p_val.$name
done
rm -rf temp.by.chrom
rm $genome.HindIII.frag.bed frag.2.all.5kb.anchor fragdata_to_anchordata.pl batch_anchor_by_chrom.pl get_anchor_pval.r

