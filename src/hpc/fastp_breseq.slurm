#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=16
#SBATCH -t 6:00:00
#SBATCH --mem=32000
#SBATCH --account=CSBLRivanna
#SBATCH --partition=standard
#SBATCH --job-name=breseq_job
#SBATCH --output=/scratch/jmf7ak/joe_aerobic_anaerobic/logs/%x_%j.out
#SBATCH --error=/scratch/jmf7ak/joe_aerobic_anaerobic/logs/%x_%j.err

SAMPLE_PREFIX="$1"

if [ -z "${SAMPLE_PREFIX}" ]; then
  echo "Error: No sample prefix provided to script."
  exit 1
fi

RAW_DIR="/project/PapinLab/joe_aerobic_anaerobic/Illumina DNA Reads"
SCRATCH_DIR="/scratch/jmf7ak/joe_aerobic_anaerobic"
TRIM_DIR="${SCRATCH_DIR}/trimmed_reads"
RESULTS_UNTRIMMED="${SCRATCH_DIR}/breseq_results_untrimmed"
RESULTS_TRIMMED="${SCRATCH_DIR}/breseq_results_trimmed"
FASTQC_RAW_DIR="${SCRATCH_DIR}/fastqc_raw"
FASTQC_TRIM_DIR="${SCRATCH_DIR}/fastqc_trimmed"

mkdir -p "${TRIM_DIR}" "${RESULTS_UNTRIMMED}" "${RESULTS_TRIMMED}" "${FASTQC_RAW_DIR}" "${FASTQC_TRIM_DIR}" "${SCRATCH_DIR}/logs"

module load miniforge
source activate breseq_env
module load fastqc

READ1="${RAW_DIR}/${SAMPLE_PREFIX}_R1_001.fastq.gz"
READ2="${RAW_DIR}/${SAMPLE_PREFIX}_R2_001.fastq.gz"
TRIM1="${TRIM_DIR}/${SAMPLE_PREFIX}_R1_trimmed.fastq.gz"
TRIM2="${TRIM_DIR}/${SAMPLE_PREFIX}_R2_trimmed.fastq.gz"
REFERENCE_GENOME="/home/jmf7ak/CODE/aerobic_anaerobic/PA14_GBK.gbk"

echo "=================================================="
echo "Running full processing pipeline for: ${SAMPLE_PREFIX}"
echo "=================================================="

# ------------------------------------------------------------------------------
# 1. Pre-trimming FastQC
# ------------------------------------------------------------------------------
echo "--- Step 1: Pre-trimming FastQC ---"
fastqc -t ${SLURM_NTASKS_PER_NODE} -o "${FASTQC_RAW_DIR}" "${READ1}" "${READ2}"

if [ $? -ne 0 ]; then
    echo "Error: Pre-trimming FastQC failed for ${SAMPLE_PREFIX}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Trimming (fastp)
# ------------------------------------------------------------------------------
echo "--- Step 2: Running fastp trimming ---"
fastp \
  --in1 "${READ1}" \
  --in2 "${READ2}" \
  --out1 "${TRIM1}" \
  --out2 "${TRIM2}" \
  --thread ${SLURM_NTASKS_PER_NODE} \
  --html "${TRIM_DIR}/${SAMPLE_PREFIX}_fastp.html" \
  --json "${TRIM_DIR}/${SAMPLE_PREFIX}_fastp.json"

if [ $? -ne 0 ]; then
    echo "Error: Trimming failed for ${SAMPLE_PREFIX}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Post-trimming FastQC
# ------------------------------------------------------------------------------
echo "--- Step 3: Post-trimming FastQC ---"
fastqc -t ${SLURM_NTASKS_PER_NODE} -o "${FASTQC_TRIM_DIR}" "${TRIM1}" "${TRIM2}"

if [ $? -ne 0 ]; then
    echo "Error: Post-trimming FastQC failed for ${SAMPLE_PREFIX}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 4. breseq on Untrimmed (Raw) Reads
# ------------------------------------------------------------------------------
echo "--- Step 4: Running breseq on UNTRIMMED reads ---"
breseq \
  -j ${SLURM_NTASKS_PER_NODE} \
  -r "${REFERENCE_GENOME}" \
  -o "${RESULTS_UNTRIMMED}/${SAMPLE_PREFIX}" \
  "${READ1}" "${READ2}"

if [ ! -f "${RESULTS_UNTRIMMED}/${SAMPLE_PREFIX}/output/index.html" ]; then
    echo "ERROR: breseq (untrimmed) failed for ${SAMPLE_PREFIX}"
    exit 1
fi

# ------------------------------------------------------------------------------
# 5. breseq on Trimmed Reads
# ------------------------------------------------------------------------------
echo "--- Step 5: Running breseq on TRIMMED reads ---"
breseq \
  -j ${SLURM_NTASKS_PER_NODE} \
  -r "${REFERENCE_GENOME}" \
  -o "${RESULTS_TRIMMED}/${SAMPLE_PREFIX}" \
  "${TRIM1}" "${TRIM2}"

if [ ! -f "${RESULTS_TRIMMED}/${SAMPLE_PREFIX}/output/index.html" ]; then
    echo "ERROR: breseq (trimmed) failed for ${SAMPLE_PREFIX}"
    exit 1
fi

echo "=================================================="
echo "SUCCESS: Completed FastQC, fastp, and dual breseq runs for ${SAMPLE_PREFIX}"
echo "=================================================="
