# AUDIT_LOG.md - ki7mt-ai-lab-core

## Audit Date: 2026-01-14
## Auditor: Claude Code (Opus 4.5)
## Version: 1.0.0

---

## Day 1 Setup: New Ham Operator Quick Start

From a clean repository clone to a fully initialized database in **5 commands**:

```bash
# 1. Clone and enter the repository
git clone https://github.com/KI7MT/ki7mt-ai-lab.git
cd ki7mt-ai-lab/ki7mt-ai-lab-core

# 2. Generate the configure script
./autogen.sh

# 3. Configure with your RAID-0 paths (adjust paths to match your system)
./configure --with-wspr-data=/mnt/ai-stack/wspr-data \
            --with-solar-data=/mnt/ai-stack/solar-data \
            --with-clickhouse-data=/mnt/ai-stack/clickhouse

# 4. Build and install (creates DDL files and scripts)
make && sudo make install

# 5. Initialize the database (idempotent - safe to run multiple times)
sudo ki7mt-lab-db-init
```

### Prerequisites

Before running the setup:

1. **ClickHouse Server** must be installed and running:
   ```bash
   sudo dnf install clickhouse-server clickhouse-client   # Rocky Linux
   sudo systemctl enable --now clickhouse-server
   ```

2. **RAID-0 NVMe mount** (if using high-performance storage):
   ```bash
   sudo mkdir -p /mnt/ai-stack/{wspr-data,solar-data,clickhouse}
   # Mount your RAID-0 array to /mnt/ai-stack
   ```

3. **Standard path alternative** (for development/testing):
   ```bash
   ./configure --with-wspr-data=/var/lib/wspr \
               --with-solar-data=/var/lib/solar \
               --with-clickhouse-data=/var/lib/clickhouse
   ```

---

## Audit Summary

### 1. Schema Audit: `src/01-wspr_schema.sql.in`

**Status:** UPDATED

**Changes Made:**
- Added comprehensive documentation header explaining the 15-column WSPR standard
- Applied `LowCardinality(String)` to high-repetition columns:
  - `reporter` (~500K unique callsigns)
  - `reporter_grid` (Maidenhead grids)
  - `callsign` (transmitter callsigns)
  - `grid` (transmitter grids)
  - `version` (software versions)
- Changed `frequency` from `Float64` to `UInt64` (Hz precision, avoids floating-point errors at 10B+ rows)
- Changed `band` from `Int8` to `Int16` (ADIF compatibility)
- Retained `DateTime` for `timestamp` (full precision needed for time-series analysis)
- Added optional materialized view template for daily summaries

**Type Optimization Rationale:**
| Column | Old Type | New Type | Reason |
|--------|----------|----------|--------|
| reporter | String | LowCardinality(String) | ~500K unique values, high repetition |
| reporter_grid | String | LowCardinality(String) | ~32K unique grids |
| callsign | String | LowCardinality(String) | Same as reporter |
| grid | String | LowCardinality(String) | Same as reporter_grid |
| frequency | Float64 | UInt64 | Hz precision, no FP errors at scale |
| band | Int8 | Int16 | ADIF band ID compatibility |

**Expected Storage Improvement:** ~30-40% reduction in string column storage via dictionary encoding.

---

### 2. Idempotency Audit: `src/ki7mt-lab-db-init.in`

**Status:** REFACTORED

**Changes Made:**
- Added helper functions: `database_exists()`, `table_exists()`, `get_table_engine()`, `get_column_count()`, `get_row_count()`
- Added pre-flight check showing current database state
- Added schema validation (verifies 15-column count)
- Added `--dry-run` flag for safe preview
- Added `--force` flag for explicit table recreation (with confirmation)
- Added clear exit codes:
  - `0`: Success
  - `1`: Fatal error (ClickHouse unavailable)
  - `2`: Schema mismatch (needs manual migration)

**Idempotency Guarantee:**
- Running `ki7mt-lab-db-init` twice is now safe
- Existing tables with data are NEVER dropped
- `CREATE TABLE IF NOT EXISTS` handles new installations
- Schema mismatches are reported, not auto-fixed (prevents data loss)

---

### 3. Environment Audit: `src/ki7mt-lab-env.in`

**Status:** UPDATED

**Changes Made:**
- Default storage paths now use `/mnt/ai-stack/` prefix for RAID-0 NVMe
- Added `CLICKHOUSE_DATA_DIR` with override support
- Added `CLICKHOUSE_PASSWORD` for secure deployments
- Added derived sub-directories: `WSPR_RAW_DIR`, `WSPR_DOWNLOAD_DIR`, `SOLAR_RAW_DIR`
- Added performance tuning variables: `INGEST_RAM_GB`, `INGEST_WORKERS`, `INGEST_BATCH_SIZE`
- Improved interactive shell message showing all configured paths

**Override Priority (highest to lowest):**
1. Pre-existing environment variables
2. Configure-time values (`./configure --with-*`)
3. Built-in defaults

**Example Override:**
```bash
export CLICKHOUSE_DATA_DIR=/var/lib/clickhouse  # Override default
source /usr/local/bin/ki7mt-lab-env
```

---

### 4. Configure Audit: `configure.ac`

**Status:** UPDATED

**Changes Made:**
- Updated default paths from `/opt/` to `/mnt/ai-stack/` (RAID-0 convention)
- Added `--with-clickhouse-data` option
- Improved configuration output showing all storage paths

---

## Verification Commands

After Day 1 setup, verify the installation:

```bash
# 1. Check ClickHouse is running
clickhouse-client --query="SELECT 1"

# 2. Verify database exists
clickhouse-client --query="SHOW DATABASES" | grep wspr

# 3. Verify table schema (should show 15 columns)
clickhouse-client --query="DESCRIBE TABLE wspr.spots_raw"

# 4. Check column types
clickhouse-client --query="SELECT name, type FROM system.columns WHERE database='wspr' AND table='spots_raw'"

# 5. Verify idempotency (run init again - should show "EXISTS" for tables)
sudo ki7mt-lab-db-init --dry-run
```

---

## Troubleshooting

### ClickHouse Not Running
```bash
sudo systemctl status clickhouse-server
sudo systemctl start clickhouse-server
journalctl -u clickhouse-server -f  # View logs
```

### Schema Mismatch After Upgrade
```bash
# Option 1: Drop and recreate (LOSES DATA)
clickhouse-client --query="DROP TABLE wspr.spots_raw"
sudo ki7mt-lab-db-init

# Option 2: Manual migration (PRESERVES DATA)
clickhouse-client --query="ALTER TABLE wspr.spots_raw MODIFY COLUMN reporter LowCardinality(String)"
```

### Permission Denied on Data Directories
```bash
sudo chown -R clickhouse:clickhouse /mnt/ai-stack/clickhouse
sudo chmod 750 /mnt/ai-stack/clickhouse
```

---

## Next Steps

1. **Load WSPR Data:**
   ```bash
   # Download WSPR archive
   wget https://wsprnet.org/archive/wsprspots-2024-01.csv.gz -P /mnt/ai-stack/wspr-data/raw/

   # Ingest (requires wspr-ingest from ki7mt-ai-lab-wspr-mcp-legacy)
   wspr-ingest /mnt/ai-stack/wspr-data/raw/wsprspots-2024-01.csv.gz
   ```

2. **Verify Data:**
   ```bash
   clickhouse-client --query="SELECT count() FROM wspr.spots_raw"
   ```

3. **Run Queries:**
   ```bash
   clickhouse-client --query="
     SELECT band, count() as spots, uniqExact(callsign) as unique_tx
     FROM wspr.spots_raw
     WHERE toDate(timestamp) = '2024-01-15'
     GROUP BY band
     ORDER BY spots DESC
   "
   ```

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-01-14 | Initial audit and refactoring | Claude Code (Opus 4.5) |
