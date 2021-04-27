#!/bin/bash

#SBATCH --time=00:20:00
#SBATCH --array=0-1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name SENDEP_cifti_merge
#SBATCH --output=data/outputs/logs/wb_cifti_merge_%j.txt

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
avg_out_dir=data/outputs/dscalar_avg

export wb_container
export avg_out_dir 

cd ${basedir}

### make a tmpdir for this call
tmpdir=$(mktemp --tmpdir=$SLURM_TMPDIR -d tmp.XXXXXX)
mkdir $tmpdir/home

## do the call to singularity to run the cleaning

# Create a list of arguments for the merge command
merge_list=""
while read subject; do
	merge_list="${merge_list} -cifti ${avg_out_dir}/${subject}_avg_clean_smooth.dscalar.nii"
done < ${basedir}/code/subjects_by_group.txt

## run the cleaning command
singularity exec \
-H ${tmpdir}/home \
${wb_container} wb_command -cifti-merge\
			data/outputs/SEN_all_subs_merged_by_group.dscalar.nii \
			${merge_list}
## delete the tmpdir when we are done
rm -rf $tmpdir

