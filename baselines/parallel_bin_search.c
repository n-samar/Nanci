#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

typedef unsigned long size_t;

#define EXPERIMENTS 20

static size_t ARR_SIZE;

size_t *arr1, *arr2;

int cmpfunc (const void * a, const void * b) {
   return ( *(double*)a - *(double*)b ) >= 0;
}

void setup(size_t seed) {
    srand(seed);
    for (size_t i = 0; i < ARR_SIZE; i++) {
	    arr1[i] = rand();
	    arr2[i] = rand();
    }
    qsort(arr1, ARR_SIZE, sizeof(size_t), cmpfunc);
}

size_t binarySearch(size_t *arr, size_t l, size_t r, size_t x) 
{ 
    if (r >= l) { 
        int mid = l + (r - l) / 2; 
  
        // If the element is present at the middle 
        // itself 
        if (arr[mid] == x) 
            return mid; 
  
        // If element is smaller than mid, then 
        // it can only be present in left subarray 
        if (arr[mid] > x) 
            return binarySearch(arr, l, mid - 1, x); 
  
        // Else the element can only be present 
        // in right subarray 
        return binarySearch(arr, mid + 1, r, x); 
    } 
  
    // We reach here when element is not 
    // present in array 
    return -1; 
} 

size_t bin_search(size_t val) {
    return binarySearch(arr1, 0, ARR_SIZE, val);
}

void parallel_binary_search() {
    // TODO: search if elements in arr2 are present in arr1 via binary search
    // assume arr1 sorted
    for (size_t i = 0; i < ARR_SIZE; i++) {
	bin_search(arr1[i]);
    }
}

int main() {
    printf("size, elem_size, latency\n");
    for (ARR_SIZE = 64; ARR_SIZE < 1024*1024*1024/sizeof(size_t); ARR_SIZE*=2) {    
	for (size_t exprmnt = 0; exprmnt < EXPERIMENTS; exprmnt++) {
	    arr1 = (size_t*) malloc(ARR_SIZE*sizeof(size_t));
	    arr2 = (size_t*) malloc(ARR_SIZE*sizeof(size_t));
	    // load cache
	    for (size_t i = 0; i < ARR_SIZE; i++) {
		arr1[i];
		arr2[i];
	    }
	    setup(0);
	    clock_t begin = clock();
	    parallel_binary_search();
	    clock_t end = clock();
	    free(arr1);
	    free(arr2);
	    double res = (end - begin)*1000000./CLOCKS_PER_SEC/ARR_SIZE;
	    printf("%lu, %lu, %f\n", 3*ARR_SIZE*sizeof(size_t)/1024, sizeof(size_t), res);
	}
    }
    return 0;
}
