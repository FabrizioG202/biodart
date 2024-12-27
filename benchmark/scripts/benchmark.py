# Copyright (c) 2024 Fabrizio Guidotti
#
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

# This file contains a python implementation of the benchmark code
# used in dart to test the biodart project's modules.
# It is not very idiomatic to python as I am trying to keep the structure
# similar to the dart's one. However, I tried to not impede performance
# in doing so.
# ! This must be ran after the dart's code since this does not contain utility
# functions to download the file (s).

from Bio import SeqIO
from pathlib import Path
import gzip
import time
from typing import List, Callable
from dataclasses import dataclass


@dataclass
class Duration:
    """Mirror Dart's Duration class for timing"""

    microseconds: int

    @property
    def inMicroseconds(self) -> int:
        return self.microseconds


def _format_duration(d: Duration) -> str:
    micros = d.inMicroseconds
    if micros < 1000:
        return f"{micros} µs"
    if micros < 1000000:
        return f"{(micros / 1000):.2f} ms"
    return f"{(micros / 1000000):.2f} s"


def benchmark(
    operation: Callable,
    n: int,
    *,
    setup_all: Callable[[], None] = None,
    setup: Callable[[], None] = None,
    cleanup: Callable[[], None] = None,
    cleanup_all: Callable[[], None] = None,
) -> List[Duration]:
    times = []
    if setup_all:
        setup_all()

    for _ in range(n):
        if setup:
            setup()
        start = time.perf_counter_ns()
        operation()
        elapsed = time.perf_counter_ns() - start
        times.append(Duration(microseconds=elapsed // 1000))
        if cleanup:
            cleanup()

    if cleanup_all:
        cleanup_all()
    return times


def print_duration_stats(durations: List[Duration], *, logger=None):
    if not durations:
        return

    avg = Duration(
        microseconds=sum(d.inMicroseconds for d in durations) // len(durations)
    )
    min_d = Duration(microseconds=min(d.inMicroseconds for d in durations))
    max_d = Duration(microseconds=max(d.inMicroseconds for d in durations))

    print("Duration Statistics:")  # Using print since logger would need more setup
    print(f"  Average: {_format_duration(avg)}")
    print(f"  Min: {_format_duration(min_d)}")
    print(f"  Max: {_format_duration(max_d)}")


def main():
    genome_file = Path("./.data/GCA_025448055.1_ASM2544805v1_genomic.fna.gz")
    handle = None
    reads = []

    def setup_all():
        nonlocal handle
        handle = gzip.open(genome_file, "rt")

    def cleanup_all():
        nonlocal handle
        if handle:
            handle.close()

    def operation():
        nonlocal reads, handle
        reads = []
        handle.seek(0)
        for i, record in enumerate(SeqIO.parse(handle, "fasta")):
            if i >= 20000:
                break
            reads.append(record)

    durations = benchmark(operation, 10, setup_all=setup_all, cleanup_all=cleanup_all)

    print_duration_stats(durations)
    print(f"Parsed {len(reads)} sequences")


if __name__ == "__main__":
    main()
