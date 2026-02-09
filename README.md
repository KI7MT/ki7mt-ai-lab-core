# ki7mt-ai-lab-core

**Core ClickHouse schemas and environment setup for the KI7MT AI Lab**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![COPR](https://img.shields.io/badge/COPR-ki7mt%2Fai--lab-blue)](https://copr.fedorainfracloud.org/coprs/ki7mt/ai-lab/)
[![Platform: EL9](https://img.shields.io/badge/Platform-EL9-green.svg)](https://rockylinux.org/)

## Package Contents

This package installs:

```text
File                Path                               Description
ki7mt-lab-db-init   /usr/bin/                          Database initialization script
ki7mt-lab-env       /usr/bin/                          Environment variables setup
*.sql (22 files)    /usr/share/ki7mt-ai-lab-core/ddl/  ClickHouse DDL schemas
*.sh (7 files)      /usr/share/ki7mt-ai-lab-core/scripts/  Population scripts
```

### Database Schemas

```text
DDL                                Database     Creates
01-wspr_schema_v2.sql              wspr         bronze, v_schema_contract, v_data_integrity
02-solar_indices.sql               solar        bronze
03-solar_silver.sql                solar        v_daily_indices
04-data_mgmt.sql                   data_mgmt    config
05-geo_functions.sql               geo          v_grid_validation_example
06-lab_versions.sql                data_mgmt    lab_versions, v_lab_versions_latest
07-callsign_grid.sql               wspr         callsign_grid
08-model_features.sql              wspr         silver
09-quality_distribution_mv.sql     wspr         v_quality_distribution (MV)
10-rbn_schema_v1.sql               rbn          bronze
11-contest_schema_v1.sql           contest      bronze
12-signatures_v1.sql               wspr         signatures_v1
13-training_stratified.sql         wspr         gold_stratified
14-training_continuous.sql         wspr         gold_continuous
15-training_v6_clean.sql           wspr         gold_v6
16-validation_step_i.sql           validation   step_i_paths, step_i_voacap
17-balloon_callsigns.sql           wspr         balloon_callsigns (V1 DEPRECATED)
18-validation_quality_test.sql     validation   quality_test_paths, quality_test_voacap
19-dxpedition_synthesis.sql        dxpedition   catalog; rbn: dxpedition_paths
20-signatures_v2_terrestrial.sql   wspr         signatures_v2_terrestrial
21-balloon_callsigns_v2.sql        wspr         balloon_callsigns_v2 (date-level)
22-pskr_schema_v1.sql              pskr         bronze
```

## Installation

### From COPR (Recommended)

```bash
# Enable the repository
sudo dnf copr enable ki7mt/ai-lab

# Install
sudo dnf install ki7mt-ai-lab-core
```

### From Source (rpkg)

```bash
git clone https://github.com/KI7MT/ki7mt-ai-lab.git
cd ki7mt-ai-lab/ki7mt-ai-lab-core
rpkg local
sudo dnf install ./noarch/*.rpm
```

## Usage

### 1. Start ClickHouse

```bash
# Install ClickHouse if not already installed
sudo dnf install -y clickhouse-server clickhouse-client

# Start the service
sudo systemctl enable --now clickhouse-server

# Verify it's running
clickhouse-client --query="SELECT version()"
```

### 2. Initialize the Database

```bash
# Run the initialization script
ki7mt-lab-db-init
```

**Options:**
```
--dry-run        Show what would be done without executing
--force          Drop and recreate tables (DESTROYS DATA)
--auto-confirm   Skip confirmation prompts (for automation)
```

**Example output:**
```
[INIT] Starting ki7mt-ai-lab-core v1.0.4 Database Setup...
[INFO] DDL Directory: /usr/share/ki7mt-ai-lab-core/ddl
[CHECK] Verifying ClickHouse connectivity... [OK]

[STATUS] Current database state:
  Database 'wspr': MISSING (will be created)

[APPLY] Processing DDL files...
  01-wspr_schema.sql ... [OK]
  02-solar_indices.sql ... [OK]
  03-solar_silver.sql ... [OK]
  04-data_mgmt.sql ... [OK]
  05-geo_functions.sql ... [OK]

[VALIDATE] Verifying schema installation...
  wspr.bronze: VALID (15 columns)

[DONE] Database setup completed successfully.
```

### 3. Load Environment Variables

```bash
# Source the environment (add to ~/.bashrc for persistence)
source /usr/bin/ki7mt-lab-env
```

**Variables exported:**
```
CLICKHOUSE_HOST=localhost
CLICKHOUSE_PORT=9000
CLICKHOUSE_DB=wspr
WSPR_DATA_DIR=/mnt/ai-stack/wspr-data
SOLAR_DATA_DIR=/mnt/ai-stack/solar-data
CLICKHOUSE_DATA_DIR=/mnt/ai-stack/clickhouse
DDL_PATH=/usr/share/ki7mt-ai-lab-core/ddl
```

**Override defaults before sourcing:**
```bash
export WSPR_DATA_DIR=/var/lib/wspr
export CLICKHOUSE_DATA_DIR=/var/lib/clickhouse
source /usr/bin/ki7mt-lab-env
```

## Testing Locally

### Verify Installation

```bash
# Check package is installed
rpm -q ki7mt-ai-lab-core

# Check files are in place
ls -la /usr/bin/ki7mt-lab-*
ls -la /usr/share/ki7mt-ai-lab-core/ddl/
```

### Verify Database

```bash
# Check database exists
clickhouse-client --query="SHOW DATABASES" | grep wspr

# Check tables were created
clickhouse-client --query="SHOW TABLES FROM wspr"

# Verify bronze schema (should show 15 columns)
clickhouse-client --query="DESCRIBE TABLE wspr.bronze"

# Check table is empty but ready
clickhouse-client --query="SELECT count() FROM wspr.bronze"
```

### Test Idempotency

The init script is idempotent - running it multiple times is safe:

```bash
# Run again - should report tables exist
ki7mt-lab-db-init

# Expected output:
# [STATUS] Current database state:
#   Database 'wspr': EXISTS
#     Table 'bronze': EXISTS (engine=MergeTree, cols=15, rows=0)
```

### Test Environment Script

```bash
# Source and check variables
source /usr/bin/ki7mt-lab-env
echo "DDL Path: $DDL_PATH"
echo "WSPR Data: $WSPR_DATA_DIR"

# Verify DDL files are accessible
ls $DDL_PATH
```

### Test with Sample Data

```bash
# Insert a test record
clickhouse-client --query="
INSERT INTO wspr.bronze VALUES (
    1,                          -- id
    '2024-01-15 12:30:00',      -- timestamp
    'KI7MT',                    -- reporter
    'DN26',                     -- reporter_grid
    -15,                        -- snr
    14097100,                   -- frequency (Hz)
    'W1AW',                     -- callsign
    'FN31',                     -- grid
    37,                         -- power (dBm)
    0,                          -- drift
    3842,                       -- distance (km)
    75,                         -- azimuth
    20,                         -- band
    '2.6.1',                    -- version
    0                           -- code
)"

# Query it back
clickhouse-client --query="
SELECT callsign, reporter, distance, snr
FROM wspr.bronze
WHERE id = 1"

# Clean up test data
clickhouse-client --query="ALTER TABLE wspr.bronze DELETE WHERE id = 1"
```

---

## Uninstall

```bash
# Remove package (keeps database)
sudo dnf remove ki7mt-ai-lab-core

# To also remove the database:
clickhouse-client --query="DROP DATABASE IF EXISTS wspr"
```

---

## Development

### Version Management

```bash
# Bump version and create git tag
./bump-version 1.1.0

# Push to trigger COPR rebuild
git push && git push --tags
```

### Build Locally

```bash
rpkg local                    # Build RPM
rpkg lint                     # Check spec file
rpkg srpm                     # Create source RPM
```

---

## License

GPL-3.0-or-later - See [COPYING](COPYING)

## Author

Greg Beam, KI7MT

## Links

- **COPR:** https://copr.fedorainfracloud.org/coprs/ki7mt/ai-lab/
- **Issues:** https://github.com/KI7MT/ki7mt-ai-lab/issues
