# Schrodinger Job Automation Tools

Automated job preparation and execution tools for Schrodinger software on university Linux servers.

## 🚀 Quick Start

### Prerequisites
- Linux server with Schrodinger installed
- SSH access and basic command line knowledge

### Setup (First Time Only)

1. **Upload scripts** to your home directory:
   ```bash
   scp *.sh config.json.example username@server:~/
   ```

2. **Create configuration**:
   ```bash
   cp config.json.example ~/config.json
   nano ~/config.json  # Edit with your server's paths
   ```

3. **Install jq** (if needed):
   ```bash
   sudo yum install jq    # RHEL/CentOS
   sudo apt install jq    # Ubuntu/Debian
   ```

4. **Make executable and test**:
   ```bash
   chmod +x *.sh
   source setup_schrodinger.sh
   ```

## 📁 Directory Structure

```
~/
├── jobs/              # Job directories (auto-created)
├── ligands/           # Ligand files for docking (.sdf, .mol, .mol2, .mae)
├── grids/             # Grid files for docking (.zip, .grd)
├── config.json        # Your configuration
└── *.sh               # Automation scripts
```

**Job structure:**
```
~/jobs/job_name/
├── job_name.sh        # Execution script
├── job_name.in        # Input file
└── other_files...
```

## ⚙️ Configuration Setup

Find your server's settings and update `~/config.json`:

```json
{
  "schrodinger": {
    "installation_path": "/opt/schrodinger2025-1",
    "license_path": "/opt/schrodinger/licenses", 
    "license_file": "YOUR_LICENSE.serverid.lic"
  },
  "jobs": {
    "directory": "jobs",
    "timeout": 3600
  },
  "ligands": {
    "directory": "ligands",
    "supported_formats": [".sdf", ".mol", ".mol2", ".mae"]
  },
  "grids": {
    "directory": "grids", 
    "supported_formats": [".zip", ".grd"]
  },
  "docking": {
    "precision": "SP",
    "poses_per_ligand": 1,
    "pose_output_type": "poseviewer",
    "default_host": "batch-small"
  }
}
```

**Find paths:**
```bash
# Schrodinger installation
find /opt /usr/local -name "glide" 2>/dev/null | head -1 | xargs dirname

# License files
find /opt -name "*.lic" 2>/dev/null
```

## 🛠️ Tools Overview

### 1. `setup_schrodinger.sh`
Environment setup with configuration validation.
```bash
source setup_schrodinger.sh
```

### 2. `prep_jobs.sh` 
General Schrodinger job preparation.
```bash
./prep_jobs.sh
```

### 3. `glide_grid_prep_jobs.sh`
Glide grid generation with automatic license fix (removes `-elements` flags).
```bash
./glide_grid_prep_jobs.sh
```

### 4. `glide_docking_prep_jobs.sh` ⭐ **NEW**
Automated ligand-receptor docking from JSON input.
```bash
./glide_docking_prep_jobs.sh docking_combinations.json
```

## 🎯 Workflows

### Grid Generation
```bash
./glide_grid_prep_jobs.sh
source run-glide-grid-jobs_YYMMDD-HHMM.sh
```

### Docking Workflow ⭐ **NEW**

1. **Prepare ligands and grids:**
   ```bash
   mkdir -p ~/ligands ~/grids
   # Upload your ligand and grid files
   ```

2. **Create docking combinations JSON:**
   ```json
   {
     "docking_combinations": [
       {
         "ligand": "compound_001.sdf",
         "grid": "receptor_grid.zip", 
         "job_name": "comp001_docking"
       },
       {
         "ligand": "compound_002.sdf",
         "grid": "receptor_grid.zip",
         "job_name": "comp002_docking"
       }
     ]
   }
   ```

3. **Generate and run docking jobs:**
   ```bash
   ./glide_docking_prep_jobs.sh my_docking.json
   source run-glide-docking-jobs_YYMMDD-HHMM.sh
   ```

## 📤📥 File Transfer

**Upload:**
```bash
# Single files
scp file.sdf username@server:~/ligands/
scp grid.zip username@server:~/grids/

# Job directories
scp -r job_dir/ username@server:~/jobs/
```

**Download results:**
```bash
# Specific outputs
scp username@server:~/jobs/job_name/*.{zip,log,csv} ~/Downloads/

# All jobs
scp -r username@server:~/jobs/ ~/Downloads/
```

## 🔧 Common Issues

| Issue | Solution |
|-------|----------|
| License errors | Use `glide_grid_prep_jobs.sh` (auto-removes `-elements`) |
| Permission denied | `chmod +x *.sh` |
| Command not found | `source setup_schrodinger.sh` |
| Config not found | `cp config.json.example ~/config.json` |
| jq not available | `sudo yum install jq` |

## 📋 Example: Complete Docking Workflow

1. **Setup on server:**
   ```bash
   ssh username@server
   mkdir -p ~/ligands ~/grids
   ```

2. **Upload files:**
   ```bash
   scp compounds/*.sdf username@server:~/ligands/
   scp receptor_grid.zip username@server:~/grids/
   ```

3. **Create docking JSON locally:**
   ```json
   {
     "docking_combinations": [
       {
         "ligand": "aspirin.sdf",
         "grid": "cox2_grid.zip",
         "job_name": "aspirin_cox2"
       }
     ]
   }
   ```

4. **Upload and run:**
   ```bash
   scp docking.json username@server:~/
   ssh username@server
   ./glide_docking_prep_jobs.sh docking.json
   source run-glide-docking-jobs_*.sh
   ```

5. **Download results:**
   ```bash
   scp -r username@server:~/jobs/aspirin_cox2/ ~/Downloads/
   ```

## 🏗️ Job Script Templates

**Grid generation:**
```bash
#!/bin/bash
"${SCHRODINGER}/glide" job_name.in -OVERWRITE -HOST localhost -TMPLAUNCHDIR
```

**Note:** Docking jobs are generated automatically from JSON input.

## 📦 Generated Files

### Docking Outputs
- `job_name_raw.maegz` - Raw docked poses
- `job_name.csv` - Docking scores and results  
- `job_name.log` - Execution log
- `job_name_config.json` - Job configuration

### Scripts
- `run-*-jobs_YYMMDD-HHMM.sh` - Timestamped job runners
- Individual job execution scripts in each job directory

## 🎯 Features

✅ **JSON-driven docking setup**  
✅ **Automatic license issue fixing**  
✅ **Configurable via JSON**  
✅ **Multiple output format support**  
✅ **Comprehensive error handling**  
✅ **Parallel job execution**  
✅ **Real-time progress tracking**  

## 📄 Repository Contents

### Scripts
- `setup_schrodinger.sh` - Environment setup
- `prep_jobs.sh` - General job preparation  
- `glide_grid_prep_jobs.sh` - Grid generation
- `glide_docking_prep_jobs.sh` - **NEW:** Automated docking

### Configuration
- `config.json.example` - Template (copy and edit)
- `.gitignore` - Excludes sensitive files

**Note:** `config.json` and `jobs/` directories are excluded from git for security.

---
**Created for university research computing environments** 