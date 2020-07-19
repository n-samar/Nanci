all: SHELL := bash
all:
	rm -f ../data/ptr_jumps.csv; \
	for d in {1..10}; do \
		gcc -DDATA_WIDTH=$d -o ptr_jumps_${d} ptr_jumps.c; \
		./ptr_jumps_${d} >> ../data/ptr_jumps.csv; \
	done
	for d in {1..10}; do \
		gcc -DSEQ -DDATA_WIDTH=$d -o ptr_jumps_seq_${d} ptr_jumps.c; \
		./ptr_jumps_seq_${d} >> ../data/ptr_jumps_seq.csv; \
	done
