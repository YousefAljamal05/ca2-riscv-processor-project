# Phase 1 - RISC-V Assembler

This folder contains the Phase 1 implementation of the project: a custom RISC-V assembler written in C++.

## Features
- Reads assembly code from a text file
- Supports labels
- Encodes supported instructions into machine code
- Writes one machine-code instruction per line to an output text file

## Files
- `assembler.cpp`
- `input.txt`
- `output.txt`

## Supported Instructions

### R-type
- addw
- and
- xor
- or
- sltu
- srl
- sra

### I-type
- addiw
- andi
- ori
- jalr
- lw

### S-type
- sw

### SB-type
- bge
- bne

### UJ-type
- jal

## Note
This phase only implements the assembler.
It does not implement execution, pipeline stages, hazards, forwarding, branch prediction, or cache.
