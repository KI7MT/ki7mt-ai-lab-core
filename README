# ki7mt-ai-lab-core

**Core Foundation for the KI7MT AI Lab WSPR/Solar Analysis Platform**

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform: Rocky Linux 9](https://img.shields.io/badge/Platform-Rocky%20Linux%209-green.svg)](https://rockylinux.org/)

---

## What Is This?

This package provides the **database foundation** for analyzing 18 years of amateur radio propagation data—over **11 billion WSPR spot records**—correlated with solar flux indices to understand how space weather affects HF radio propagation.

If you're a ham radio operator curious about propagation patterns, band openings, or the relationship between solar activity and signal propagation, this is your starting point.

---

## The Scale

| Metric | Value |
|--------|-------|
| **Time Span** | 2008–2026 (18 years) |
| **Total Records** | ~11 billion WSPR spots |
| **Daily Ingestion** | ~2-3 million new spots |
| **Storage Required** | ~800GB compressed |
| **Query Performance** | Sub-second on indexed queries |

This isn't a toy dataset—it's the complete historical record of weak signal propagation reports from the global WSPRnet network.

---

## Target Hardware

This package is optimized for high-performance workstations:

| Component | Specification |
|-----------|---------------|
| **CPU** | AMD Ryzen 9 9950X3D (16 cores, 128GB RAM) |
| **Storage** | Samsung 990 Pro NVMe in RAID-0 (8TB @ /mnt/ai-stack) |
| **GPU** | NVIDIA RTX 5090 (32GB VRAM) for CUDA-accelerated ingestion |
| **Database** | ClickHouse v2 (columnar OLAP) |
| **OS** | Rocky Linux 9.7 (RHEL-compatible) |

**Note:** The package works on standard hardware too—just adjust the storage paths during configuration.

---

## Quick Start for New Ham Operators

### Prerequisites

1. **Rocky Linux 9.x** (or RHEL 9.x / AlmaLinux 9.x)
2. **ClickHouse** installed and running:
   ```bash
   sudo dnf install -y clickhouse-server clickhouse-client
   sudo systemctl enable --now clickhouse-server
   ```

### Installation from RPM (Recommended)

```bash
# Install the RPM (creates schemas automatically)
sudo dnf install ki7mt-ai-lab-core-1.0.0-1.el9.noarch.rpm
```

### Installation from Source

```bash
# 1. Clone the repository
git clone https://github.com/KI7MT/ki7mt-ai-lab.git
cd ki7mt-ai-lab/ki7mt-ai-lab-core

# 2. Generate build system
./autogen.sh

# 3. Configure (adjust paths for your system)
./configure --with-wspr-data=/mnt/ai-stack/wspr-data \
            --with-solar-data=/mnt/ai-stack/solar-data \
            --with-clickhouse-data=/mnt/ai-stack/clickhouse

# 4. Build and install
make && sudo make install

# 5. Initialize database
sudo ki7mt-lab-db-init
```

### Verify Installation

```bash
# Check database exists
clickhouse-client --query="SHOW DATABASES" | grep wspr

# Check table schema (should show 15 columns)
clickhouse-client --query="DESCRIBE TABLE wspr.spots_raw"

# Check environment is loaded
source /usr/local/bin/ki7mt-lab-env
echo "WSPR Data: $WSPR_DATA_DIR"
```

---

## What's Included

### Database Schemas

| Table | Purpose | Columns |
|-------|---------|---------|
| `wspr.spots_raw` | Raw WSPR spot data | 15 (optimized types) |
| `wspr.solar_indices` | Solar flux indices | 12 |
| `wspr.solar_silver` | Curated solar data | 9 |

### Scripts

| Script | Purpose |
|--------|---------|
| `ki7mt-lab-db-init` | Initialize/verify database schemas (idempotent) |
| `ki7mt-lab-env` | Set environment variables for data paths |

### Schema Optimizations

The WSPR schema uses ClickHouse-specific optimizations for 11B+ rows:

- **LowCardinality(String)** for callsigns and grids (~500K unique values)
- **UInt64** for frequency (Hz precision, no floating-point errors)
- **MergeTree** engine with monthly partitioning
- **ORDER BY (timestamp, band, callsign)** for propagation queries

---

## Storage Layout

Default paths assume RAID-0 NVMe at `/mnt/ai-stack`:

```
/mnt/ai-stack/
├── wspr-data/          # WSPR archives and processed data
│   ├── raw/            # Downloaded CSV.gz files
│   └── downloads/      # Staging area
├── solar-data/         # Solar flux indices
│   └── raw/            # NOAA data files
└── clickhouse/         # ClickHouse data directory
```

**Standard installation paths** (override with `--with-*` flags):
```
/var/lib/wspr/          # WSPR data
/var/lib/solar/         # Solar data
/var/lib/clickhouse/    # ClickHouse data (default)
```

---

## Configuration

### Environment Variables

After installation, source the environment:

```bash
source /usr/local/bin/ki7mt-lab-env
```

This exports:
- `WSPR_DATA_DIR` - WSPR data root
- `SOLAR_DATA_DIR` - Solar data root
- `CLICKHOUSE_DATA_DIR` - ClickHouse storage
- `CLICKHOUSE_HOST`, `CLICKHOUSE_PORT` - Connection details
- `INGEST_RAM_GB`, `INGEST_WORKERS` - Performance tuning

### Override Priority

1. **Environment variables** (highest priority)
2. **Configure-time values** (`./configure --with-*`)
3. **Built-in defaults** (lowest priority)

Example override:
```bash
export CLICKHOUSE_DATA_DIR=/var/lib/clickhouse
source /usr/local/bin/ki7mt-lab-env
```

---

## Next Steps

After installing ki7mt-ai-lab-core:

1. **Install the ingestion pipeline** (ki7mt-ai-lab-wspr-mcp):
   ```bash
   # GPU-accelerated WSPR data ingestion
   sudo dnf install ki7mt-ai-lab-wspr-mcp
   ```

2. **Download WSPR archives**:
   ```bash
   wspr-download --year 2024 --month 01
   ```

3. **Ingest data**:
   ```bash
   wspr-ingest /mnt/ai-stack/wspr-data/raw/wsprspots-2024-01.csv.gz
   ```

4. **Run your first query**:
   ```sql
   SELECT
       band,
       count() AS spots,
       uniqExact(callsign) AS unique_tx,
       uniqExact(reporter) AS unique_rx
   FROM wspr.spots_raw
   WHERE toDate(timestamp) = '2024-01-15'
   GROUP BY band
   ORDER BY spots DESC
   ```

---

## Related Projects

| Package | Purpose |
|---------|---------|
| **ki7mt-ai-lab-core** | Database schemas and environment (this package) |
| **ki7mt-ai-lab-wspr-mcp** | WSPR data ingestion pipeline |
| **ki7mt-ai-lab-solar-mcp** | Solar flux data pipeline |
| **ki7mt-ai-lab-notebooks** | Jupyter notebooks for analysis |
| **ki7mt-ai-lab-ansible** | Infrastructure automation |

---

## License

This project is licensed under the **GNU General Public License v3.0** - see the [COPYING](COPYING) file for details.

## Author

**Greg Beam, KI7MT**
Amateur Radio Operator & Software Engineer

---

## Contributing

Contributions welcome! Please read the project guidelines and submit pull requests to the main repository.

## Support

- **Issues:** https://github.com/KI7MT/ki7mt-ai-lab-core/issues
- **Documentation:** https://ki7mt.github.io/ki7mt-ai-lab/
