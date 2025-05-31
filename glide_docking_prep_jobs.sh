#!/bin/bash

# Glide Docking Job Preparation Script
# Specialized for automated ligand-grid combinations from JSON input
# Command-line version with comprehensive job setup and management
#
# This script:
# 1. Reads ligand-grid combinations from JSON input file
# 2. Creates individual job directories with docking input files
# 3. Automatically fixes known licensing issues (removes -elements flag)
# 4. Makes all execution scripts executable
# 5. Generates a sequential job runner script
# 6. Creates corresponding log files for tracking

# =============================================================================
# CONFIGURATION LOADING
# =============================================================================

CONFIG_FILE="$HOME/config.json"

# Load configuration if available
if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
    JOBS_DIRECTORY=$(jq -r '.jobs.directory // "jobs"' "$CONFIG_FILE")
    JOB_TIMEOUT=$(jq -r '.jobs.timeout // 3600' "$CONFIG_FILE")
    CHECK_INTERVAL=$(jq -r '.jobs.check_interval // 30' "$CONFIG_FILE")
    PROGRESS_INTERVAL=$(jq -r '.jobs.progress_interval // 300' "$CONFIG_FILE")
    
    LIGANDS_DIRECTORY=$(jq -r '.ligands.directory // "ligands"' "$CONFIG_FILE")
    GRIDS_DIRECTORY=$(jq -r '.grids.directory // "grids"' "$CONFIG_FILE")
    
    DOCKING_PRECISION=$(jq -r '.docking.precision // "SP"' "$CONFIG_FILE")
    POSES_PER_LIGAND=$(jq -r '.docking.poses_per_ligand // 1' "$CONFIG_FILE")
    POSTDOCK_POSES=$(jq -r '.docking.postdock_poses // 1' "$CONFIG_FILE")
    POSE_OUTPUT_TYPE=$(jq -r '.docking.pose_output_type // "ligandlib_sd"' "$CONFIG_FILE")
    REMOVE_ELEMENTS=$(jq -r '.docking.remove_elements_flag // true' "$CONFIG_FILE")
    DEFAULT_HOST=$(jq -r '.docking.default_host // "batch-small"' "$CONFIG_FILE")
    
    SCHRODINGER_PATH=$(jq -r '.schrodinger.installation_path // "/opt/schrodinger2025-1"' "$CONFIG_FILE")
else
    echo "⚠ Warning: Configuration file not found or jq not available: $CONFIG_FILE"
    echo "Using default settings. For customization, create a config file:"
    echo "  cp config.json.example ~/config.json"
    echo "Install jq if needed: sudo yum install jq"
    
    # Set defaults
    JOBS_DIRECTORY="jobs"
    JOB_TIMEOUT=3600
    CHECK_INTERVAL=30
    PROGRESS_INTERVAL=300
    LIGANDS_DIRECTORY="ligands"
    GRIDS_DIRECTORY="grids"
    DOCKING_PRECISION="SP"
    POSES_PER_LIGAND=1
    POSTDOCK_POSES=1
    POSE_OUTPUT_TYPE="ligandlib_sd"
    REMOVE_ELEMENTS=true
    DEFAULT_HOST="batch-small"
    SCHRODINGER_PATH="/opt/schrodinger2025-1"
fi

# =============================================================================
# SCRIPT CONFIGURATION
# =============================================================================

JOBS_DIR="$HOME/$JOBS_DIRECTORY"
LIGANDS_DIR="$HOME/$LIGANDS_DIRECTORY"
GRIDS_DIR="$HOME/$GRIDS_DIRECTORY"
TIMESTAMP=$(date +%y%m%d-%H%M)
RUNNER_SCRIPT="run-glide-docking-jobs_${TIMESTAMP}.sh"

# =============================================================================
# FUNCTIONS
# =============================================================================

# Function to validate ligand file exists
validate_ligand_file() {
    local ligand_file="$1"
    local full_path="$LIGANDS_DIR/$ligand_file"
    
    if [ ! -f "$full_path" ]; then
        echo "  ❌ ERROR: Ligand file not found: $full_path" >&2
        return 1
    fi
    
    # Check file format
    case "$ligand_file" in
        *.sdf|*.mol|*.mol2|*.mae|*.sdf.gz|*.mae.gz)
            echo "  ✅ Valid ligand file: $ligand_file" >&2
            return 0
            ;;
        *)
            echo "  ❌ ERROR: Unsupported ligand format: $ligand_file" >&2
            return 1
            ;;
    esac
}

# Function to validate grid file exists
validate_grid_file() {
    local grid_file="$1"
    local full_path="$GRIDS_DIR/$grid_file"
    
    if [ ! -f "$full_path" ]; then
        echo "  ❌ ERROR: Grid file not found: $full_path" >&2
        return 1
    fi
    
    # Check file format
    case "$grid_file" in
        *.zip|*.grd)
            echo "  ✅ Valid grid file: $grid_file" >&2
            return 0
            ;;
        *)
            echo "  ❌ ERROR: Unsupported grid format: $grid_file" >&2
            return 1
            ;;
    esac
}

# Function to create Glide docking input file
create_glide_docking_input() {
    local ligand_file="$1"
    local grid_file="$2"
    local output_base="$3"
    local job_name="$4"
    
    echo "  ✅ Creating Glide docking input file..." >&2
    
    cat > "${output_base}.in" << EOF
# Glide Docking Input File
# Generated automatically by glide_docking_prep_jobs.sh
# Job: $job_name
# Generated: $(date)

JOBNAME              $job_name
DOCKING_METHOD       confgen
GRIDFILE             $GRIDS_DIR/$grid_file
LIGANDFILE           $LIGANDS_DIR/$ligand_file
POSES_PER_LIG        $POSES_PER_LIGAND
POSTDOCK_NPOSE       $POSTDOCK_POSES
PRECISION            $DOCKING_PRECISION
POSE_OUTTYPE         $POSE_OUTPUT_TYPE
WRITE_RES_INTERACTION  true
WRITE_CSV            true
EOF

    echo "  ✅ Created input file: $(basename "${output_base}.in")" >&2
}

# Function to fix known Glide docking licensing issues
fix_docking_licensing_issues() {
    local input_file="$1"
    local job_name="$2"
    local issues_fixed=0
    
    if [ "$REMOVE_ELEMENTS" = "true" ]; then
        # Check and fix -elements flag issue (causes license problems)
        if grep -q "elements\|ELEMENTS" "$input_file"; then
            echo "  🔧 Found elements flag (causes license issues) - removing..." >&2
            sed -i '/[Ee]lements/d' "$input_file"
            if ! grep -q "elements\|ELEMENTS" "$input_file"; then
                echo "  ✅ Successfully removed elements flag" >&2
                ((issues_fixed++))
            else
                echo "  ❌ ERROR: Failed to remove elements flag" >&2
                return 1
            fi
        fi
    fi
    
    if [ $issues_fixed -gt 0 ]; then
        echo "  ✅ Fixed $issues_fixed known licensing issue(s) in Glide docking job" >&2
    fi
    
    return 0
}

# Function to create execution script for each job
create_execution_script() {
    local job_dir="$1"
    local job_name="$2"
    
    echo "  ✅ Creating execution script..." >&2
    
    cat > "$job_dir/run_docking.sh" << EOF
#!/bin/bash

# Glide Docking Execution Script
# Job: $job_name
# Generated: $(date)

echo "Starting Glide docking job: $job_name"
echo "======================================="
echo "Started: \$(date)"
echo ""

# Setup Schrodinger environment if needed
if [ -z "\$SCHRODINGER" ]; then
    echo "Setting up Schrodinger environment..."
    if [ -f "\$HOME/setup_schrodinger.sh" ]; then
        source "\$HOME/setup_schrodinger.sh"
    else
        export SCHRODINGER="$SCHRODINGER_PATH"
        export PATH="\$SCHRODINGER:\$PATH"
    fi
fi

echo "✅ SCHRODINGER=\$SCHRODINGER"
echo "✅ Running job in: \$(pwd)"
echo ""

# Change to job directory
cd "$job_dir" || {
    echo "❌ ERROR: Failed to change to directory $job_dir"
    exit 1
}

# Record start time
start_time=\$(date +%s)
echo "Starting Glide docking at: \$(date)"

# Run Glide docking
"\$SCHRODINGER/glide" \\
    "${job_name}.in" \\
    -DRIVERHOST localhost \\
    -SUBHOST $DEFAULT_HOST \\
    -OVERWRITE \\
    -WAIT

docking_exit_code=\$?
end_time=\$(date +%s)
duration=\$((end_time - start_time))

if [ \$docking_exit_code -eq 0 ]; then
    echo ""
    echo "✅ Glide docking completed successfully: $job_name"
    echo "  → Duration: \${duration}s"
    echo "  → Completed at: \$(date)"
    
    # Check for output files (Glide automatically generates output files based on POSE_OUTTYPE)
    if [ -f "${job_name}_lib.sdf" ]; then
        num_poses=\$(grep -c '$$$$' "${job_name}_lib.sdf" 2>/dev/null || echo "0")
        echo "  → Generated poses: \$num_poses"
        echo "  → Output file: ${job_name}_lib.sdf"
    elif [ -f "${job_name}_pv.sdf" ]; then
        num_poses=\$(grep -c '$$$$' "${job_name}_pv.sdf" 2>/dev/null || echo "0")
        echo "  → Generated poses: \$num_poses"
        echo "  → Output file: ${job_name}_pv.sdf"
    elif [ -f "${job_name}_pv.mae" ]; then
        echo "  → Generated output file: ${job_name}_pv.mae"
        echo "  → Output file: ${job_name}_pv.mae"
    elif [ -f "${job_name}_lib.mae" ]; then
        echo "  → Generated output file: ${job_name}_lib.mae"
        echo "  → Output file: ${job_name}_lib.mae"
    elif [ -f "${job_name}_raw.maegz" ]; then
        echo "  → Generated raw poses: ${job_name}_raw.maegz"
        echo "  → Output file: ${job_name}_raw.maegz"
    elif [ -f "${job_name}.csv" ]; then
        echo "  → Generated CSV results: ${job_name}.csv"
        echo "  → Check CSV file for docking results"
    else
        echo "  → No standard output poses file found"
        echo "  → Check job directory for output files"
    fi
else
    echo ""
    echo "❌ Glide docking failed with exit code: \$docking_exit_code"
    echo "  → Check ${job_name}.log for details"
fi

echo "Docking job completed: $job_name"
exit \$docking_exit_code
EOF

    chmod +x "$job_dir/run_docking.sh"
    echo "  ✅ Created executable script: run_docking.sh" >&2
}

# Function to process a single docking job from JSON
process_docking_job() {
    local combination="$1"
    
    # Extract combination details
    local ligand_file=$(echo "$combination" | jq -r '.ligand')
    local grid_file=$(echo "$combination" | jq -r '.grid') 
    local job_name=$(echo "$combination" | jq -r '.job_name')
    
    echo "Processing docking job: $job_name" >&2
    echo "  → Ligand: $ligand_file" >&2
    echo "  → Grid: $grid_file" >&2
    
    # Validate input files
    if ! validate_ligand_file "$ligand_file"; then
        return 1
    fi
    
    if ! validate_grid_file "$grid_file"; then
        return 1
    fi
    
    # Create job directory
    local job_dir="$JOBS_DIR/$job_name"
    if ! mkdir -p "$job_dir"; then
        echo "  ❌ ERROR: Failed to create job directory: $job_dir" >&2
        return 1
    fi
    
    # Generate Glide docking input file
    local output_base="$job_dir/$job_name"
    create_glide_docking_input "$ligand_file" "$grid_file" "$output_base" "$job_name"
    
    # Apply license-safe modifications
    if ! fix_docking_licensing_issues "$output_base.in" "$job_name"; then
        echo "  ❌ ERROR: Failed to fix licensing issues in $job_name" >&2
        return 1
    fi
    
    # Create execution script
    create_execution_script "$job_dir" "$job_name"
    
    # Save job configuration as JSON
    echo "$combination" | jq '.' > "$job_dir/${job_name}_config.json"
    
    echo "$job_dir"  # Return job directory path for runner script
    return 0
}

# Function to create the sequential job runner script
create_docking_runner_script() {
    local valid_jobs=("$@")
    local total_jobs=${#valid_jobs[@]}
    
    echo "Creating Glide docking job runner: $RUNNER_SCRIPT"
    
    cat > "$RUNNER_SCRIPT" << EOF
#!/bin/bash

# Sequential Glide Docking Job Runner Script
# Generated automatically by glide_docking_prep_jobs.sh
# Simple version with command line output only

echo "Sequential Glide Docking Job Runner"
echo "===================================="
echo "Generated: \$(date)"
echo ""

# Check and setup Schrodinger environment if needed
echo "Checking Schrodinger environment..."
if [ -z "\$SCHRODINGER" ]; then
    echo "Setting up Schrodinger environment..."
    if [ -f "\$HOME/setup_schrodinger.sh" ]; then
        source "\$HOME/setup_schrodinger.sh"
        if [ -z "\$SCHRODINGER" ]; then
            echo "❌ ERROR: Failed to configure Schrodinger environment"
            exit 1
        fi
    else
        export SCHRODINGER="$SCHRODINGER_PATH"
        export PATH="\$SCHRODINGER:\$PATH"
        echo "⚠️  Warning: Using default Schrodinger path: \$SCHRODINGER"
    fi
fi

echo "✅ Schrodinger environment ready"
echo "✅ SCHRODINGER=\$SCHRODINGER"
echo ""

# Job counter
total_jobs=$total_jobs
completed_jobs=0
failed_jobs=0

EOF

    # Add each docking job to the runner script
    local job_number=1
    for job_dir in "${valid_jobs[@]}"; do
        local job_name=$(basename "$job_dir")
        
        cat >> "$RUNNER_SCRIPT" << EOF

# Glide Docking Job $job_number: $job_name
echo "Starting docking job $job_number of \$total_jobs: $job_name"
echo "  → Directory: $job_dir"

# Change to job directory and run docking
cd "$job_dir" || {
    echo "❌ ERROR: Failed to change to directory $job_dir"
    ((failed_jobs++))
    continue
}

# Run the docking job
./run_docking.sh
job_exit_code=\$?

if [ \$job_exit_code -eq 0 ]; then
    echo "✅ Docking job completed successfully: $job_name"
    ((completed_jobs++))
else
    echo "❌ Docking job failed: $job_name"
    ((failed_jobs++))
fi

echo ""

EOF
        job_number=$((job_number + 1))
    done
    
    # Add summary section
    cat >> "$RUNNER_SCRIPT" << 'EOF'

# Final summary
echo "=== GLIDE DOCKING JOB RUNNER SUMMARY ==="
echo "Total jobs: $total_jobs"
echo "Completed successfully: $completed_jobs"
echo "Failed: $failed_jobs"

if [ $failed_jobs -eq 0 ]; then
    echo "🎉 All Glide docking jobs completed successfully!"
else
    echo "⚠️  Some Glide docking jobs failed."
fi

EOF

    # Make the runner script executable
    chmod +x "$RUNNER_SCRIPT"
    echo "  ✅ Created executable Glide docking runner script: $RUNNER_SCRIPT"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

echo "Glide Docking Job Preparation Script"
echo "====================================="
echo "Specialized for ligand-grid combinations from JSON input"
echo "Processing jobs in: $JOBS_DIR"
echo "Ligands directory: $LIGANDS_DIR"
echo "Grids directory: $GRIDS_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Check for input arguments
if [ $# -eq 0 ]; then
    echo "❌ ERROR: No JSON input file specified"
    echo ""
    echo "Usage: $0 <docking_combinations.json>"
    echo ""
    echo "Expected JSON format:"
    cat << 'EOF'
{
  "docking_combinations": [
    {
      "ligand": "ligand1.sdf",
      "grid": "grid1.zip",
      "job_name": "lig1_grid1"
    },
    {
      "ligand": "ligand2.sdf", 
      "grid": "grid1.zip",
      "job_name": "lig2_grid1"
    }
  ]
}
EOF
    exit 1
fi

JSON_INPUT="$1"

# Check if JSON input file exists
if [ ! -f "$JSON_INPUT" ]; then
    echo "❌ ERROR: JSON input file not found: $JSON_INPUT"
    exit 1
fi

# Check if directories exist
if [ ! -d "$LIGANDS_DIR" ]; then
    echo "❌ ERROR: Ligands directory not found: $LIGANDS_DIR"
    exit 1
fi

if [ ! -d "$GRIDS_DIR" ]; then
    echo "❌ ERROR: Grids directory not found: $GRIDS_DIR"
    exit 1
fi

# Create jobs directory if it doesn't exist
mkdir -p "$JOBS_DIR"

# Initialize arrays
valid_jobs=()
invalid_jobs=()
docking_jobs=0

# Process each docking combination from JSON
echo "Processing docking combinations from: $JSON_INPUT"
echo ""

while IFS= read -r combination; do
    if job_dir=$(process_docking_job "$combination"); then
        valid_jobs+=("$job_dir")
        ((docking_jobs++))
    else
        job_name=$(echo "$combination" | jq -r '.job_name')
        invalid_jobs+=("$job_name")
    fi
    echo ""
done < <(jq -c '.docking_combinations[]' "$JSON_INPUT")

# Summary
echo "=== PREPARATION SUMMARY ==="
echo "Valid docking jobs created: ${#valid_jobs[@]}"
echo "Glide docking jobs processed: $docking_jobs"
echo "Invalid jobs found: ${#invalid_jobs[@]}"

if [ ${#invalid_jobs[@]} -gt 0 ]; then
    echo ""
    echo "❌ Invalid job configurations:"
    printf "   %s\n" "${invalid_jobs[@]}"
fi

echo ""

# Create runner script if we have valid jobs
if [ ${#valid_jobs[@]} -gt 0 ]; then
    create_docking_runner_script "${valid_jobs[@]}"
    
    echo ""
    echo "=== GENERATED FILES ==="
    echo "Runner script: $RUNNER_SCRIPT"
    echo ""
    echo "=== USAGE ==="
    echo "Run all Glide docking jobs sequentially:"
    echo "  source $RUNNER_SCRIPT"
    echo ""
    echo "Note: Use 'source' to ensure proper environment inheritance."
else
    echo "❌ No valid docking jobs found. Cannot create runner script."
    exit 1
fi

echo "🎉 Glide docking job preparation complete!" 