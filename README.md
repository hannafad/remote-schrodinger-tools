# Schrodinger Job Automation Tools

Automated job preparation and execution tools for Schrodinger software on university Linux servers.

## 🚀 Quick Start

### Prerequisites
- Access to a Linux server with Schrodinger installed
- SSH access to the server
- Basic command line knowledge

### Setup (First Time Only)

1. **Upload the scripts** to your home directory on the server:
   ```bash
   scp setup_schrodinger.sh prep_jobs.sh glide_grid_prep_jobs.sh config.json.example username@server:~/
   ```

2. **Create your configuration file**:
   ```bash
   cp config.json.example ~/config.json
   ```

3. **Install jq** (if not already available):
   ```bash
   sudo yum install jq    # For RHEL/CentOS
   # OR
   sudo apt install jq    # For Ubuntu/Debian
   ```

4. **Edit the configuration** with your server's settings:
   ```bash
   nano ~/config.json
   ```
   **IMPORTANT:** You must update the paths and license file name for your specific server! See [Configuration Setup](#-configuration-setup) below.

5. **Make scripts executable**:
   ```bash
   chmod +x setup_schrodinger.sh prep_jobs.sh glide_grid_prep_jobs.sh
   ```

6. **Test Schrodinger environment**:
   ```bash
   source setup_schrodinger.sh
   ```

## 📁 Directory Structure

Create your jobs in the following structure:
```
~/jobs/
├── job1_name/
│   ├── job1_name.sh          # Your job script
│   ├── job1_name.in          # Input file
│   └── other_files...
├── job2_name/
│   ├── job2_name.sh
│   ├── job2_name.in
│   └── other_files...
└── ...
```

**Important:** Each job directory must contain exactly one `.sh` script file.

## ⚙️ Configuration Setup

### Finding Your Server's Settings

Before using the tools, you need to configure them for your specific server. The configuration file `config.json` contains all server-specific paths and settings in a clean JSON format.

#### 1. Find Schrodinger Installation Path
```bash
# Method 1: Search for glide executable
find /opt /usr/local -name "glide" 2>/dev/null | head -1 | xargs dirname

# Method 2: Check common locations
ls -d /opt/schrodinger* /usr/local/schrodinger* 2>/dev/null

# Method 3: Ask your system administrator
```

#### 2. Find License Directory and File
```bash
# Find license files on the system
find /opt -name "*.lic" 2>/dev/null

# Common license locations
ls /opt/schrodinger/licenses/*.lic 2>/dev/null
ls /opt/schrodinger*/licenses/*.lic 2>/dev/null
```

#### 3. Example Configuration

Your `~/config.json` should look like:
```json
{
  "schrodinger": {
    "installation_path": "/opt/schrodinger2025-1",
    "license_path": "/opt/schrodinger/licenses",
    "license_file": "UNIVERSITY_LICENSE_12345.serverid.lic"
  },
  "jobs": {
    "directory": "jobs",
    "timeout": 3600,
    "check_interval": 30,
    "progress_interval": 300
  }
}
```

#### 4. What Each Setting Means

| Setting | Description | How to Find |
|---------|-------------|-------------|
| `installation_path` | Directory containing Schrodinger executables | Search for `glide` executable |
| `license_path` | Directory containing license files | Search for `*.lic` files |
| `license_file` | Your specific license file name | List `.lic` files in license directory |
| `timeout` | Max time to wait for job completion (seconds) | Usually 3600 (1 hour) is good |
| `directory` | Name of jobs folder in your home directory | Default "jobs" works for most users |

#### 5. Validation

After configuration, test with:
```bash
source setup_schrodinger.sh
```

This will validate all your settings and show helpful error messages if anything is wrong.

### Security Note

⚠️ **NEVER commit your actual `config.json` to git!** It contains server-specific information that shouldn't be shared. The `.gitignore` file already excludes it.

## 🛠️ Tools Overview

### 1. `setup_schrodinger.sh`
Sets up the Schrodinger environment with proper paths and license configuration using your `schrodinger_config.conf` file.

**Features:**
- ✅ Loads configuration from `~/config.json`
- ✅ Validates all paths and license files
- ✅ Sets up environment variables properly
- ✅ Tests license connectivity
- ✅ Shows helpful error messages with troubleshooting tips
- ✅ Requires `jq` for JSON parsing (auto-detected)

**Usage:**
```bash
source setup_schrodinger.sh
```

### 2. `prep_jobs.sh` 
General job preparation for any Schrodinger jobs with configurable settings.

**Features:**
- ✅ Uses job timeout and directories from config file
- ✅ Works with any Schrodinger job type
- ✅ Configurable completion checking intervals

**Usage:**
```bash
./prep_jobs.sh
```

### 3. `glide_grid_prep_jobs.sh`
Specialized tool for Glide grid generation jobs with automatic issue fixing and configuration support.

**Features:**
- ✅ Automatically removes `-elements` flags (fixes license issues)
- ✅ Detects Glide grid jobs vs docking jobs
- ✅ Enhanced validation for grid generation
- ✅ Uses configurable timeouts and settings
- ✅ Fallback to defaults if no config file

**Usage:**
```bash
./glide_grid_prep_jobs.sh
```

## 🎯 How to Use

### Step 1: Prepare Your Jobs
```bash
# For general Schrodinger jobs:
./prep_jobs.sh

# For Glide grid generation specifically:
./glide_grid_prep_jobs.sh
```

This will:
- Validate all job directories
- Fix known issues automatically
- Generate a timestamped runner script (e.g., `run-jobs_250527-1430.sh`)

### Step 2: Run Your Jobs
```bash
# Execute the generated runner script
source run-jobs_YYMMDD-HHMM.sh
```

**Example output:**
```
Starting Glide grid job 1 of 2: MyProtein_grid_generation
  → Directory: /home/user/jobs/MyProtein_grid_generation
  → Running MyProtein_grid_generation.sh...
  → Job submitted, waiting for completion...
✅ Glide grid job completed successfully: MyProtein_grid_generation
  → Total elapsed time = 120 seconds
  → Script duration: 125s
```

## 📤📥 File Transfer with SCP

### Upload Files to Server

**Upload a single file:**
```bash
scp local_file.txt username@server:~/jobs/job_name/
```

**Upload an entire directory:**
```bash
scp -r local_job_directory/ username@server:~/jobs/
```

**Upload multiple files:**
```bash
scp file1.in file2.sh file3.mae username@server:~/jobs/job_name/
```

### Download Results from Server

**Download specific output files:**
```bash
scp username@server:~/jobs/job_name/*.zip ~/Downloads/
scp username@server:~/jobs/job_name/*.log ~/Downloads/
```

**Download entire job directory:**
```bash
scp -r username@server:~/jobs/job_name/ ~/Downloads/
```

**Download all job results:**
```bash
scp -r username@server:~/jobs/ ~/Downloads/all_jobs/
```

### Useful SCP Tips

**Check what files exist before downloading:**
```bash
ssh username@server "ls -la ~/jobs/job_name/"
```

**Download only completed jobs (with .zip files):**
```bash
ssh username@server "find ~/jobs -name '*.zip'" | while read file; do
    scp username@server:"$file" ~/Downloads/
done
```

**Compress before download (for large results):**
```bash
ssh username@server "cd ~/jobs && tar -czf results.tar.gz */"
scp username@server:~/jobs/results.tar.gz ~/Downloads/
```

## 🔧 Common Issues & Solutions

### Issue: License Errors
**Problem:** `FATAL ERROR. Failed to check out a license`
**Solution:** Use `glide_grid_prep_jobs.sh` - it automatically removes problematic `-elements` flags

### Issue: Jobs Not Completing
**Problem:** Script thinks job failed but it's still running
**Solution:** Tools now wait for "Exiting Glide" message - be patient, jobs can take 5-30 minutes

### Issue: Permission Denied
**Problem:** `Permission denied` when running scripts
**Solution:** 
```bash
chmod +x *.sh
chmod +x ~/jobs/*/*.sh
```

### Issue: Environment Not Set
**Problem:** `command not found: glide`
**Solution:** Always source the environment setup:
```bash
source setup_schrodinger.sh
```

### Issue: Configuration File Not Found
**Problem:** `Configuration file not found: ~/config.json`
**Solution:** Create your config file from the example:
```bash
cp config.json.example ~/config.json
nano ~/config.json  # Edit with your server's paths
```

### Issue: jq Not Available
**Problem:** `jq is required to parse the JSON config file`
**Solution:** Install jq:
```bash
sudo yum install jq    # For RHEL/CentOS
sudo apt install jq    # For Ubuntu/Debian
```

### Issue: Wrong Paths in Config
**Problem:** `Schrodinger installation not found` or `License file not found`
**Solution:** Use the detection commands to find correct paths:
```bash
# Find Schrodinger installation
find /opt /usr/local -name "glide" 2>/dev/null

# Find license files  
find /opt -name "*.lic" 2>/dev/null
```

## 📋 Example Workflow

1. **Create job directory locally:**
   ```bash
   mkdir MyProtein_grid
   # Add your .in file and create .sh script
   ```

2. **Upload to server:**
   ```bash
   scp -r MyProtein_grid/ username@server:~/jobs/
   ```

3. **SSH to server and setup configuration:**
   ```bash
   ssh username@server
   cd ~
   # Edit your config file with server-specific paths
   nano config.json
   # Test the configuration
   source setup_schrodinger.sh
   ```

4. **Prepare jobs:**
   ```bash
   ./glide_grid_prep_jobs.sh
   ```

5. **Run jobs:**
   ```bash
   source run-glide-grid-jobs_YYMMDD-HHMM.sh
   ```

6. **Download results:**
   ```bash
   scp -r username@server:~/jobs/MyProtein_grid/ ~/Downloads/
   ```

## 🏗️ Job Script Template

For Glide grid generation, your `.sh` file should look like:
```bash
#!/bin/bash
"${SCHRODINGER}/glide" job_name.in -OVERWRITE -HOST localhost -TMPLAUNCHDIR
```

**Note:** The tools automatically remove `-elements` flags if present.

## 📦 Repository Contents

### Scripts
- `setup_schrodinger.sh` - Environment setup with config file support
- `prep_jobs.sh` - General job preparation tool
- `glide_grid_prep_jobs.sh` - Specialized Glide grid job tool

### Configuration
- `config.json.example` - Example JSON configuration file (COPY AND EDIT THIS)
- `config.json` - Your actual configuration (excluded from git)
- `.gitignore` - Excludes sensitive files from git

### Documentation
- `README.md` - This documentation

### Important Files NOT in Repository (You Create These)
- `config.json` - Your actual configuration (contains sensitive paths)
- `jobs/` - Your job directories  
- `run-*_*.sh` - Generated job runner scripts

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

**Security Reminder:** Never commit actual configuration files or job data that contains server-specific or sensitive information.

## 📄 License

Open source - use and modify as needed for your research.

---
**Created for university research computing environments** 