#!/bin/bash
# Run INSIDE an application instance via Session Manager, not on your laptop.
set -euo pipefail
set -a
source /etc/webapp.env
set +a
cd /opt/webapp
/opt/webapp/.venv/bin/python init_db.py
