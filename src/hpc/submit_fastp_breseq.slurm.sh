#!/bin/bash

RAW_DIR="/scratch/jmf7ak/aerobic_anaerobic/BRESEQ/evolved_sequencing_data"
HOME_CODE_DIR="/home/jmf7ak/CODE/aerobic_anaerobic/BRESEQ"
SCRATCH_DIR="/scratch/jmf7ak/aerobic_anaerobic/BRESEQ"

# Ensure log directory exists in scratch
mkdir -p "${SCRATCH_DIR}/logs"

# Extract sample prefixes
SAMPLES=($(ls "${RAW_DIR}"/*_R1_001.fastq.gz 2>/dev/null | sed 's/_R1_001\.fastq\.gz//' | xargs -n1 basename | sort -u))

if [ ${#SAMPLES[@]} -eq 0 ]; then
  echo "No FASTQ read pairs found matching pattern *_R1_001.fastq.gz in ${RAW_DIR}"
  exit 1
fi

echo "Found ${#SAMPLES[@]} samples. Submitting individual SLURM jobs..."

for SAMPLE in "${SAMPLES[@]}"; do
  echo "Submitting job for: ${SAMPLE}"
  # Submit the job script stored in /home
  sbatch --job-name="breseq_${SAMPLE}" "${HOME_CODE_DIR}/fastp_breseq.slurm" "${SAMPLE}"
done

echo "All jobs submitted! Monitor with: squeue -u jmf7ak"
