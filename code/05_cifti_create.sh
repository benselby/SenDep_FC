#!/bin/bash

#SBATCH --time=02:00:00
#SBATCH --array=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name SENDEP_cifti_create
#SBATCH --output=data/outputs/logs/cifti_create_%j.txt

## core settings for scc
SUB_SIZE=1 ## number of subjects to run
CORES=8
export THREADS_PER_COMMAND=8

## set paths for the scc
wb_container=/KIMEL/tigrlab/archive/code/containers/CONNECTOME_WORKBENCH/connectome_workbench_v1.0-2019-06-05-bbdb3be76afe.simg
export SLURM_TMPDIR=$TMPDIR

# load the important modules for this (parallel and singularity) for scc
module load singularity/3.5.3

## set up a trap that will clear the ramdisk if it is not cleared - this should work on both scc and scinet
function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory $SLURM_TMPDIR/ on "
    date
    rm -rf $SLURM_TMPDIR
    echo -n "done at "
    date
}

############ use this section to set the paths ##########
basedir=${PWD}

export wb_container

cd ${basedir}

### make a tmpdir for this call
tmpdir=$(mktemp --tmpdir=$SLURM_TMPDIR -d tmp.XXXXXX)
mkdir $tmpdir/home

## Merge the PALM-generated contrast result, creating a new CIFTI file for each set of p-value maps
template=data/outputs/SEN_all_subs_merged_by_group.dscalar.nii
results_dir=data/results
echo "Running connectome workbench from ${wb_container}"
singularity exec -H ${tmpdir}/home  ${wb_container} wb_command \
	-cifti-create-dense-from-template $template \
		${results_dir}/results_merged_tfce_tstat_fwep_c1.dscalar.nii \
		-volume-all ${results_dir}/results_sub_tfce_tstat_fwep_c1.nii \
		-metric CORTEX_LEFT ${results_dir}/results_L_cort_tfce_tstat_fwep_c1.gii \
		-metric CORTEX_RIGHT ${results_dir}/results_R_cort_tfce_tstat_fwep_c1.gii

singularity exec -H ${tmpdir}/home  ${wb_container} wb_command \
	-cifti-create-dense-from-template $template \
		${results_dir}/results_merged_tfce_tstat_fwep_c2.dscalar.nii \
		-volume-all ${results_dir}/results_sub_tfce_tstat_fwep_c2.nii \
		-metric CORTEX_LEFT ${results_dir}/results_L_cort_tfce_tstat_fwep_c2.gii \
		-metric CORTEX_RIGHT ${results_dir}/results_R_cort_tfce_tstat_fwep_c2.gii

singularity exec -H ${tmpdir}/home  ${wb_container} wb_command \
	-cifti-create-dense-from-template $template \
		${results_dir}/results_merged_tfce_tstat_fwep_c3.dscalar.nii \
		-volume-all ${results_dir}/results_sub_tfce_tstat_fwep_c3.nii \
		-metric CORTEX_LEFT ${results_dir}/results_L_cort_tfce_tstat_fwep_c3.gii \
		-metric CORTEX_RIGHT ${results_dir}/results_R_cort_tfce_tstat_fwep_c3.gii

singularity exec -H ${tmpdir}/home  ${wb_container} wb_command \
	-cifti-create-dense-from-template $template \
		${results_dir}/results_merged_tfce_tstat_fwep_c4.dscalar.nii \
		-volume-all ${results_dir}/results_sub_tfce_tstat_fwep_c4.nii \
		-metric CORTEX_LEFT ${results_dir}/results_L_cort_tfce_tstat_fwep_c4.gii \
		-metric CORTEX_RIGHT ${results_dir}/results_R_cort_tfce_tstat_fwep_c4.gii
## delete the tmpdir when we are done
rm -rf $tmpdir
