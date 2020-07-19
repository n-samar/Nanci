#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

typedef unsigned long size_t;

#define EXPERIMENTS 20

static size_t ARR_SIZE;
static size_t SIDE_LEN;

size_t *arr1, *arr2, *arr3;

int cmpfunc (const void * a, const void * b) {
   return ( *(double*)a - *(double*)b ) >= 0;
}

void setup(size_t seed) {
    srand(seed);
    for (size_t i = 0; i < SIDE_LEN; i++) {
	for (size_t j = 0; j < SIDE_LEN; j++) {
	    arr1[i*SIDE_LEN + j] = rand();
	    arr2[i*SIDE_LEN + j] = rand();
	    arr3[i*SIDE_LEN + j] = 0;
	}
    }
}

void mm() {
    for (size_t i = 0; i < SIDE_LEN; i++) {
	for (size_t j = 0; j < SIDE_LEN; j++) {
	    for (size_t k = 0; k < SIDE_LEN; k++) {
		arr3[i*SIDE_LEN + j]+=(arr1[i*SIDE_LEN + k]*arr2[k*SIDE_LEN + j]);
	    }
	}
    }
}

int main() {
    printf("size, elem_size, latency\n");
    for (ARR_SIZE = 64; ARR_SIZE*sizeof(size_t)/1024 < 8192; ARR_SIZE*=4) {
	SIDE_LEN = (size_t) floor(sqrt((double)ARR_SIZE));
	for (size_t exprmnt = 0; exprmnt < EXPERIMENTS; exprmnt++) {
	    arr1 = (size_t*) malloc(ARR_SIZE*sizeof(size_t));
	    arr2 = (size_t*) malloc(ARR_SIZE*sizeof(size_t));
	    arr3 = (size_t*) malloc(ARR_SIZE*sizeof(size_t));	    
	    // load cache
	    for (size_t i = 0; i < ARR_SIZE; i++) {
		arr1[i];
		arr2[i];
		arr3[i];
	    }
	    setup(0);
	    clock_t begin = clock();
	    mm();
	    clock_t end = clock();
	    free(arr1);
	    free(arr2);
	    free(arr3);
	    double res = (end - begin)*1000000./CLOCKS_PER_SEC/ARR_SIZE;
	    printf("%lu, %lu, %f\n", 3*ARR_SIZE*sizeof(size_t)/1024, sizeof(size_t), res);
	}
    }
    return 0;
}
