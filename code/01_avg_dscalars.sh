#!/bin/bash

#SBATCH --time=00:20:00
#SBATCH --array=0-52
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name SENDEP_cifti_avg
#SBATCH --output=data/outputs/logs/wb_cifti_avg_%j.txt

## core settings for scc
SUB_SIZE=1 ## number of subjects to run
CORES=8
export THREADS_PER_COMMAND=8

## set paths for the scc
ciftify_container=/KIMEL/tigrlab/archive/code/containers/FMRIPREP_CIFTIFY/tigrlab_fmriprep_ciftify_v1.3.2-2.3.3-2019-08-16-c0fcb37f1b56.simg
wb_container=/KIMEL/tigrlab/archive/code/containers/CONNECTOME_WORKBENCH/connectome_workbench_v1.0-2019-06-05-bbdb3be76afe.simg

export SLURM_TMPDIR=$TMPDIR

# load the important modules for this (parallel and singularity) for scc
module load GNU_PARALLEL/20180622
module load singularity/3.5.3

## set up a trap that will clear the ramdisk if it is not cleared - this should work on both scc and scinet
function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory $SLURM_TMPDIR/ on "
    date
    rm -rf $SLURM_TMPDIR
    echo -n "done at "
    date
}

#trap the termination signal, and call the function 'trap_term' when
# that happens, so results may be saved.
trap "cleanup_ramdisk" TERM

## double check that parallel is in the env..
command -v parallel > /dev/null 2>&1 || { echo "GNU parallel not found in job environment. Exiting."; exit 1; }

############ use this section to set the paths ##########
basedir=${PWD}
mr_inputs=data/inputs
avg_out_dir=data/outputs/dscalar_avg
dscalar_in_dir=data/outputs/smoothed
#full_sublist=`cd $mr_inputs/ciftify; ls -1d sub-* | sort`

export ciftify_container
export wb_container
# export SINGULARITYENV_TMPDIR=
export avg_out_dir 
export dscalar_in_dir
export clean_config

## get the subject list from the command
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`
subjects=`cd /KIMEL/tigrlab/projects/ncalarco/Yuliya/NM-MRI/data; ls -1d SEN* | sort | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
#mapfile -t subjects < ${basedir}/code/nm_subject_list.txt
#subjects=nm_subject_list.txt
cd ${basedir}

## write a function that runs the singularity command - to simplify the look the way it is called
run_wb_cifti_avg(){
### make a tmpdir for this call
tmpdir=$(mktemp --tmpdir=$SLURM_TMPDIR -d tmp.XXXXXX)
mkdir $tmpdir/home

## do the call to singularity to run the cleaning
subject=$1

# Average the two runs
singularity exec \
-H ${tmpdir}/home \
${wb_container} wb_command -cifti-average\
	${avg_out_dir}/${subject}_avg_clean_smooth.dscalar.nii \
	-cifti ${dscalar_in_dir}/${subject}_ses-01_task-rest_run-1_desc-clean_Atlas_s0.OC_MNI_mask.smooth_COLUMN.dscalar.nii \
	-cifti ${dscalar_in_dir}/${subject}_ses-01_task-rest_run-2_desc-clean_Atlas_s0.OC_MNI_mask.smooth_COLUMN.dscalar.nii
## delete the tmpdir when we are done
rm -rf $tmpdir
}

export -f run_wb_cifti_avg

parallel -j${CORES} --tag --line-buffer --compress \
 "run_wb_cifti_avg {1}" \
    ::: ${subjects}
