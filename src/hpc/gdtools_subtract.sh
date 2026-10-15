#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -t 1:00:00
#SBATCH --mem=8000
#SBATCH --account=CSBLRivanna
#SBATCH --partition=standard
#SBATCH --job-name=gdtools_subtract
#SBATCH --output=/scratch/jmf7ak/joe_aerobic_anaerobic/logs/%x_%j.out
#SBATCH --error=/scratch/jmf7ak/joe_aerobic_anaerobic/logs/%x_%j.err

# ------------------------------------------------------------------------------
# 1. Environment & Path Setup
# ------------------------------------------------------------------------------
SCRATCH_DIR="/scratch/jmf7ak/aerobic_anaerobic/BRESEQ"
UNTRIMMED_DIR="${SCRATCH_DIR}/breseq_results_untrimmed"
TRIMMED_DIR="${SCRATCH_DIR}/breseq_results_trimmed"

SUBTRACT_UNTRIMMED="${SCRATCH_DIR}/subtracted_gd_untrimmed"
SUBTRACT_TRIMMED="${SCRATCH_DIR}/subtracted_gd_trimmed"
REFERENCE_GENOME="/home/jmf7ak/CODE/aerobic_anaerobic/PA14_GBK.gbk"

# Exact folder name for your ancestor sample
ANCESTOR_NAME="ANCESTOR_S45"

mkdir -p "${SUBTRACT_UNTRIMMED}" "${SUBTRACT_TRIMMED}" "${SCRATCH_DIR}/logs"

module load miniforge
source activate breseq_env

# ------------------------------------------------------------------------------
# Subtraction Function using gdtools
# ------------------------------------------------------------------------------
run_subtraction() {
    local INPUT_BASE_DIR="$1"
    local OUTPUT_SUB_DIR="$2"
    local LABEL="$3"

    echo "=================================================="
    echo "Processing Subtractions for: ${LABEL}"
    echo "=================================================="

    ANCESTOR_GD="${INPUT_BASE_DIR}/${ANCESTOR_NAME}/output/output.gd"

    if [ ! -f "${ANCESTOR_GD}" ]; then
        echo "Error: Ancestor GenomeDiff file not found at ${ANCESTOR_GD}"
        return 1
    fi

    for SAMPLE_DIR in "${INPUT_BASE_DIR}"/*; do
        if [ -d "${SAMPLE_DIR}" ]; then
            SAMPLE=$(basename "${SAMPLE_DIR}")

            # Skip the ancestor directory itself
            if [ "${SAMPLE}" == "${ANCESTOR_NAME}" ]; then
                continue
            fi

            SAMPLE_GD="${SAMPLE_DIR}/output/output.gd"
            OUT_GD="${OUTPUT_SUB_DIR}/${SAMPLE}_subtracted.gd"
            OUT_HTML="${OUTPUT_SUB_DIR}/${SAMPLE}_subtracted.html"

            if [ -f "${SAMPLE_GD}" ]; then
                echo "Subtracting ${ANCESTOR_NAME} mutations from ${SAMPLE}..."
                
                # Command: gdtools SUBTRACT -o output.gd ancestor.gd sample.gd
                gdtools SUBTRACT -o "${OUT_GD}" "${SAMPLE_GD}" "${ANCESTOR_GD}"
                 
                # Annotate the subtracted GD file into a standalone HTML report
                gdtools ANNOTATE -r "${REFERENCE_GENOME}" -o "${OUT_HTML}" "${OUT_GD}"
            else
                echo "Warning: No output.gd found for sample ${SAMPLE}, skipping."
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# 2. Execute Subtractions
# ------------------------------------------------------------------------------
run_subtraction "${UNTRIMMED_DIR}" "${SUBTRACT_UNTRIMMED}" "UNTRIMMED"
run_subtraction "${TRIMMED_DIR}" "${SUBTRACT_TRIMMED}" "TRIMMED"

echo "=================================================="
echo "SUCCESS: GenomeDiff subtraction complete."
echo "Results stored in:"
echo "  - ${SUBTRACT_UNTRIMMED}"
echo "  - ${SUBTRACT_TRIMMED}"
echo "=================================================="
