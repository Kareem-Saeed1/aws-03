#!/bin/bash
# Controlled CPU load INSIDE YOUR OWN LAB INSTANCE. Automatically ends after 420 seconds.
# Run via Session Manager on both existing ASG instances to drive ASG average CPU.
set -euo pipefail
python3 - <<'PYCPU'
import multiprocessing as mp
import os
import time

def burn():
    end = time.monotonic() + 420
    n = 1
    while time.monotonic() < end:
        n = (n * 48271) % 2147483647

if __name__ == '__main__':
    jobs = [mp.Process(target=burn) for _ in range(os.cpu_count() or 2)]
    for j in jobs: j.start()
    for j in jobs: j.join()
PYCPU
