#!/bin/bash

# Job Preparation Script
# Simple command-line version with no log file complexity
#
# This script:
# 1. Validates each job directory has exactly one .sh file
# 2. Makes all .sh files executable
# 3. Generates a sequential job runner script

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
fi

# =============================================================================
# SCRIPT CONFIGURATION
# =============================================================================

JOBS_DIR="$HOME/$JOBS_DIRECTORY"
TIMESTAMP=$(date +%y%m%d-%H%M)
RUNNER_SCRIPT="run-jobs_${TIMESTAMP}.sh"

# =============================================================================
# FUNCTIONS
# =============================================================================

# Function to validate and process a job directory
process_job_dir() {
    local job_dir="$1"
    local job_name=$(basename "$job_dir")
    
    echo "Processing job directory: $job_name" >&2
    
    # Find all .sh files in the directory
    local sh_files=($(find "$job_dir" -maxdepth 1 -name "*.sh" -type f))
    local sh_count=${#sh_files[@]}
    
    # Check if exactly one .sh file exists
    if [ $sh_count -eq 0 ]; then
        echo "  ❌ ERROR: No .sh files found in $job_name" >&2
        return 1
    elif [ $sh_count -gt 1 ]; then
        echo "  ❌ ERROR: Multiple .sh files found in $job_name:" >&2
        printf "     %s\n" "${sh_files[@]}" >&2
        return 1
    else
        local sh_file="${sh_files[0]}"
        echo "  ✅ Found script: $(basename "$sh_file")" >&2
        
        # Make the script executable
        if chmod +x "$sh_file"; then
            echo "  ✅ Made executable: $(basename "$sh_file")" >&2
            echo "$sh_file"  # Return ONLY the full path to stdout for capture
            return 0
        else
            echo "  ❌ ERROR: Failed to make executable: $(basename "$sh_file")" >&2
            return 1
        fi
    fi
}

# Function to create the sequential job runner script
create_runner_script() {
    local valid_jobs=("$@")
    
    echo "Creating sequential job runner: $RUNNER_SCRIPT"
    
    cat > "$RUNNER_SCRIPT" << 'EOF'
#!/bin/bash

# Sequential Job Runner Script
# Generated automatically by prep_jobs.sh
# Simple version with command line output only

echo "Sequential Schrodinger Job Runner"
echo "================================="
echo "Generated: $(date)"
echo ""

# Check and setup Schrodinger environment if needed
echo "Checking Schrodinger environment..."
if [ -z "$SCHRODINGER" ] || [ ! -x "$SCHRODINGER/glide" ]; then
    echo "Setting up Schrodinger environment..."
    if [ -f "$HOME/setup_schrodinger.sh" ]; then
        source "$HOME/setup_schrodinger.sh"
        if [ -z "$SCHRODINGER" ]; then
            echo "❌ ERROR: Failed to configure Schrodinger environment"
            exit 1
        fi
    else
        echo "❌ ERROR: setup_schrodinger.sh not found in $HOME"
        exit 1
    fi
fi

echo "✅ Schrodinger environment ready"
echo "✅ SCHRODINGER=$SCHRODINGER"
echo "✅ SCHRODINGER_LICENSE_FILE=$SCHRODINGER_LICENSE_FILE"
echo ""

# Job counter
total_jobs=${#valid_jobs[@]}
completed_jobs=0
failed_jobs=0

EOF

    # Add each job to the runner script
    local job_number=1
    for job_script in "${valid_jobs[@]}"; do
        local job_dir=$(dirname "$job_script")
        local job_name=$(basename "$job_dir")
        local script_name=$(basename "$job_script")
        
        cat >> "$RUNNER_SCRIPT" << EOF

# Job $job_number: $job_name
echo "Starting job $job_number of $total_jobs: $job_name"
echo "  → Directory: $job_dir"

# Change to job directory
cd "$job_dir" || {
    echo "❌ ERROR: Failed to change to directory $job_dir"
    exit 1
}

# Record start time
start_time=\$(date +%s)
echo "  → Running $script_name..."

# Run the job
./$script_name
submit_exit_code=\$?

if [ \$submit_exit_code -ne 0 ]; then
    echo "❌ Job submission failed with exit code: \$submit_exit_code"
    ((failed_jobs++))
else
    echo "  → Job submitted, waiting for completion..."
    
    # Wait for completion by checking for "Exiting Glide" in log file
    max_wait=\$JOB_TIMEOUT
    elapsed=0
    check_interval=\$CHECK_INTERVAL
    
    while [ \$elapsed -lt \$max_wait ]; do
        if [ -f "$job_name.log" ]; then
            # Check for Glide completion
            if grep -q "Exiting Glide" "$job_name.log" && grep -q "Total elapsed time" "$job_name.log"; then
                end_time=\$(date +%s)
                duration=\$((end_time - start_time))
                job_elapsed_time=\$(grep "Total elapsed time" "$job_name.log" | tail -1)
                echo "✅ Job completed successfully: $job_name"
                echo "  → \$job_elapsed_time"
                echo "  → Script duration: \${duration}s"
                ((completed_jobs++))
                break
            fi
            
            # Check for other completion indicators
            if grep -q "completed successfully\|normal termination\|finished" "$job_name.log"; then
                end_time=\$(date +%s)
                duration=\$((end_time - start_time))
                echo "✅ Job completed successfully: $job_name"
                echo "  → Script duration: \${duration}s"
                ((completed_jobs++))
                break
            fi
            
            # Check for errors
            if grep -q "FATAL ERROR\|Failed to check out a license" "$job_name.log"; then
                echo "❌ Job failed - check $job_name.log for details"
                ((failed_jobs++))
                break
            fi
        fi
        
        sleep \$check_interval
        elapsed=\$((elapsed + check_interval))
        
        # Progress update based on config
        if [ \$((elapsed % \$PROGRESS_INTERVAL)) -eq 0 ]; then
            echo "  → Still waiting... (\${elapsed}s elapsed)"
        fi
    done
    
    # Check if we timed out
    if [ \$elapsed -ge \$max_wait ]; then
        echo "❌ Job timed out after \${max_wait}s"
        ((failed_jobs++))
    fi
fi

echo ""

EOF
        job_number=$((job_number + 1))
    done
    
    # Add summary section
    cat >> "$RUNNER_SCRIPT" << 'EOF'

# Final summary
echo "=== JOB RUNNER SUMMARY ==="
echo "Total jobs: $total_jobs"
echo "Completed successfully: $completed_jobs"
echo "Failed: $failed_jobs"

if [ $failed_jobs -eq 0 ]; then
    echo "🎉 All jobs completed successfully!"
else
    echo "⚠️  Some jobs failed."
fi

EOF

    # Make the runner script executable
    chmod +x "$RUNNER_SCRIPT"
    echo "  ✅ Created executable runner script: $RUNNER_SCRIPT"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

echo "Schrodinger Job Preparation Script"
echo "=================================="
echo "Processing jobs in: $JOBS_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Check if jobs directory exists
if [ ! -d "$JOBS_DIR" ]; then
    echo "❌ ERROR: Jobs directory not found: $JOBS_DIR"
    exit 1
fi

# Initialize arrays
valid_jobs=()
invalid_jobs=()

# Process each subdirectory in the jobs directory
for job_dir in "$JOBS_DIR"/*/; do
    if [ -d "$job_dir" ]; then
        if job_script=$(process_job_dir "$job_dir"); then
            valid_jobs+=("$job_script")
        else
            invalid_jobs+=("$(basename "$job_dir")")
        fi
        echo ""
    fi
done

# Summary
echo "=== PREPARATION SUMMARY ==="
echo "Valid jobs found: ${#valid_jobs[@]}"
echo "Invalid jobs found: ${#invalid_jobs[@]}"

if [ ${#invalid_jobs[@]} -gt 0 ]; then
    echo ""
    echo "❌ Invalid job directories:"
    printf "   %s\n" "${invalid_jobs[@]}"
fi

echo ""

# Create runner script if we have valid jobs
if [ ${#valid_jobs[@]} -gt 0 ]; then
    create_runner_script "${valid_jobs[@]}"
    
    echo ""
    echo "=== GENERATED FILES ==="
    echo "Runner script: $RUNNER_SCRIPT"
    echo ""
    echo "=== USAGE ==="
    echo "Run all jobs sequentially:"
    echo "  source $RUNNER_SCRIPT"
    echo ""
    echo "Note: Use 'source' to ensure proper environment inheritance."
else
    echo "❌ No valid jobs found. Cannot create runner script."
    exit 1
fi

echo "🎉 Job preparation complete!" 