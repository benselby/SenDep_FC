#!/bin/bash

#SBATCH --time=23:59:00
#SBATCH --array=1
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --job-name SENDEP_palm
#SBATCH --output=data/outputs/logs/palm_%j.txt

## core settings for scc
SUB_SIZE=1 ## number of subjects to run
CORES=8
export THREADS_PER_COMMAND=8

## set paths for the scc
wb_container=/KIMEL/tigrlab/archive/code/containers/CONNECTOME_WORKBENCH/connectome_workbench_v1.0-2019-06-05-bbdb3be76afe.simg
palm_container=/KIMEL/tigrlab/archive/code/containers/PALM/andersonwinkler_palm_alpha115-2019-07-02-8e876f2f6db5.simg
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
export palm_container 

cd ${basedir}

### make a tmpdir for this call
tmpdir=$(mktemp --tmpdir=$SLURM_TMPDIR -d tmp.XXXXXX)
mkdir $tmpdir/home

## Separate the CIFTI files into volumetric and surface files:
fname=data/outputs/separated/merge_split

# Merge surface meshes - left:
merge_out_dir=data/outputs/merged

# Stage 4: RUN PALM
desmat=code/design.mat
conmat=code/design.con
results_dir=data/results
surfL=data/inputs/ciftify/sub-CMHSEN084/MNINonLinear/fsaverage_LR32k/sub-CMHSEN084.L.midthickness.32k_fs_LR.surf.gii
surfR=data/inputs/ciftify/sub-CMHSEN084/MNINonLinear/fsaverage_LR32k/sub-CMHSEN084.R.midthickness.32k_fs_LR.surf.gii
singularity exec -H ${tmpdir}/home  ${palm_container} \
	palm -i ${fname}_L.func.gii -d $desmat -t $conmat -o ${results_dir}/results_L_cort -T -tfce2D \
	-s $surfL ${merge_out_dir}/L_area.func.gii -logp -n 1000 -precision "double" -ise

singularity exec -H ${tmpdir}/home  ${palm_container} \
	palm -i ${fname}_R.func.gii -d $desmat -t $conmat -o ${results_dir}/results_R_cort -T -tfce2D \
	-s $surfR ${merge_out_dir}/R_area.func.gii -logp -n 1000 -precision "double" -ise

singularity exec -H ${tmpdir}/home  ${palm_container} \
	palm -i ${fname}_sub.nii    -d $desmat -t $conmat -o ${results_dir}/results_sub -T -logp -n 1000 -precision "double" -ise


## delete the tmpdir when we are done
rm -rf $tmpdir
