#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

typedef unsigned long size_t;

#define EXPERIMENTS 20

static size_t ARR_SIZE;

size_t *arr;

int cmpfunc (const void * a, const void * b) {
   return ( *(double*)a - *(double*)b ) >= 0;
}

void setup(size_t seed) {
    srand(seed);
    for (size_t i = 1; i < ARR_SIZE; i++)
	arr[i] = rand();
}


int main() {
    printf("size, elem_size, latency\n");
    for (ARR_SIZE = 64; ARR_SIZE < 1024*1024*1024/sizeof(size_t); ARR_SIZE*=2) {
	for (size_t exprmnt = 0; exprmnt < EXPERIMENTS; exprmnt++) {
	    arr = (size_t*) malloc(ARR_SIZE*sizeof(size_t));
	    // load cache
	    for (size_t i = 0; i < ARR_SIZE; i++)
		arr[i];
	    setup(0);
	    clock_t begin = clock();
	    qsort(arr, ARR_SIZE, sizeof(size_t), cmpfunc);
	    clock_t end = clock();
	    free(arr);
	    double res = (end - begin)*1000000./CLOCKS_PER_SEC/ARR_SIZE;
	    printf("%lu, %lu, %f\n", ARR_SIZE*sizeof(size_t)/1024, sizeof(size_t), res);
	}
    }
    return 0;
}
