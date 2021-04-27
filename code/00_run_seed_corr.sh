#!/bin/bash

#SBATCH --time=00:20:00
#SBATCH --array=0-52
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name SENDEP_seed_corr 
#SBATCH --output=data/outputs/logs/seed_corr_%j.txt

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
mr_outputs=data/outputs
clean_config=data/inputs/24MP_8Phys_4GSR_sm0.json
#full_sublist=`cd $mr_inputs/ciftify; ls -1d sub-* | sort`

export ciftify_container
export wb_container
# export SINGULARITYENV_TMPDIR=
export mr_inputs
export mr_outputs
export clean_config

## get the subject list from the command
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`
subjects=`cd /KIMEL/tigrlab/projects/ncalarco/Yuliya/NM-MRI/data; ls -1d SEN* | sort | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
#mapfile -t subjects < ${basedir}/code/nm_subject_list.txt
#subjects=nm_subject_list.txt
cd ${basedir}

## write a function that runs the singularity command - to simplify the look the way it is called
run_seed_corr() {
### make a tmpdir for this call
tmpdir=$(mktemp --tmpdir=$SLURM_TMPDIR -d tmp.XXXXXX)
mkdir $tmpdir/home

## do the call to singularity to run the cleaning
subject=$1
session=$2
task=$3

## run the cleaning command
singularity exec \
-H ${tmpdir}/home \
${ciftify_container} ciftify_clean_img \
    --output-file=${mr_outputs}/ciftify_clean/${subject}_${session}_${task}_desc-clean_bold.dtseries.nii \
    --clean-config=${clean_config} \
    --confounds-tsv=${mr_inputs}/fmriprep/sub-CMH${subject}/${session}/func/sub-CMH${subject}_${session}_${task}_desc-confounds_regressors.tsv \
    ${mr_inputs}/ciftify/sub-CMH${subject}/MNINonLinear/Results/${session}_${task}_desc-preproc/${session}_${task}_desc-preproc_Atlas_s0.dtseries.nii

echo "Running seed_corr on cleaned inputs:"
singularity exec \
-H ${tmpdir}/home \
${ciftify_container} ciftify_seed_corr --outputname=${mr_outputs}/seed_corr_out/${subject}_${session}_${task}_desc-clean_Atlas_s0.OC_MNI_mask.dscalar.nii ${mr_outputs}/ciftify_clean/${subject}_${session}_${task}_desc-clean_bold.dtseries.nii ${mr_inputs}/masks/MNI/OC_MNI_mask.nii

# Spatially smooth the two runs
echo "Spatially smoothing the seed_corr data:"
singularity exec -H ${tmpdir}/home ${wb_container} wb_command -cifti-smoothing \
        ${mr_outputs}/seed_corr_out/${subject}_${session}_${task}_desc-clean_Atlas_s0.OC_MNI_mask.dscalar.nii \
        2.547965 2.547965 COLUMN \
        data/outputs/smoothed/${subject}_${session}_${task}_desc-clean_Atlas_s0.OC_MNI_mask.smooth_COLUMN.dscalar.nii \
	-left-surface ${mr_inputs}/ciftify/sub-CMH${subject}/MNINonLinear/fsaverage_LR32k/sub-CMH${subject}.L.midthickness.32k_fs_LR.surf.gii \
	-right-surface ${mr_inputs}/ciftify/sub-CMH${subject}/MNINonLinear/fsaverage_LR32k/sub-CMH${subject}.R.midthickness.32k_fs_LR.surf.gii

## delete the tmpdir when we are done
rm -rf $tmpdir
}

export -f run_seed_corr

parallel -j${CORES} --tag --line-buffer --compress \
 "run_seed_corr {1} ses-01 task-rest_run-{2}" \
    ::: ${subjects} ::: 1 2
