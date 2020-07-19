#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

#define EXPERIMENTS 20

static size_t ARR_SIZE;
size_t *arr;
typedef unsigned long size_t;

void fft() {
    for (size_t i = ARR_SIZE/2; i > 0; i/=2) {
	for (size_t k = 0; k < ARR_SIZE; k+=2*i) {
	    for (size_t j = 0; j < i; j++) {
		size_t temp = arr[k+j];	    
		arr[k+j] = arr[k+i+j];
		arr[k+i+j] = temp;
	    }
	}
    }
}

int main() {
    printf("size, elem_size, latency\n");
    for (ARR_SIZE = 64; ARR_SIZE < 1024*1024*1024/sizeof(size_t); ARR_SIZE*=2) {
	for (size_t exprmnt = 0; exprmnt < EXPERIMENTS; exprmnt++) {
	    arr = (size_t*) malloc(ARR_SIZE*sizeof(size_t));
	    // load cache
	    for (size_t i = 0; i < ARR_SIZE; i++)
		arr[i];
	    clock_t begin = clock();
	    fft();
	    clock_t end = clock();	    
	    free(arr);
	    double res = (end - begin)*1000000./CLOCKS_PER_SEC/ARR_SIZE;
	    printf("%lu, %lu, %f\n", ARR_SIZE*sizeof(size_t)/1024, sizeof(size_t), res);
	}
    }
    return 0;
}
