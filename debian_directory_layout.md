./ki7mt-ai-lab-core/
├── autogen.sh              # Standard script to run autoreconf
├── configure.ac            # The "Check" script: looks for clickhouse-client, jq, etc.
├── Makefile.am             # Tells 'make' where to install your SQL and Scripts
├── debian/                 # --- DEBIAN PACKAGING DIRECTORY ---
│   ├── changelog           # Required: versioning (1.0.0-1)
│   ├── control             # Required: metadata & 'Depends: clickhouse-server'
│   ├── rules               # Required: the build instructions (dh $@ --with autoreconf)
│   ├── ki7mt-ai-lab-core.install  # Directs files to /usr/bin and /usr/share
│   ├── postinst            # Trigger: runs 'init-db.sh' after install
│   └── source/format       # Should be "3.0 (native)" for your lab
├── ddl/                    # Your SQL Source of Truth
│   ├── wspr_raw.sql
│   └── solar_indices.sql
├── scripts/                # The Grunt Work
│   ├── init-db.sh
│   └── set-env.sh
└── spa/                    # The UI Control Plane (Pre-built dist)
    └── index.html