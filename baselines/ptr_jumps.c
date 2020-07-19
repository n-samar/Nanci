#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

typedef unsigned long size_t;

#define EXPERIMENTS 20

static size_t ARR_SIZE;


struct node {
    struct node* next;
    struct node* prev;
    uint64_t data[DATA_WIDTH];
};

struct node *arr;
struct node *tail;
struct node *head;

void add (size_t i) {
    (*tail).next = &arr[i];
    arr[i].prev = tail;
    arr[i].next = NULL;
    arr[i].data[0] = 1;
    tail = &arr[i];
}

int cmpfunc (const void * a, const void * b) {
   return ( *(double*)a - *(double*)b ) >= 0;
}

void rm (size_t i) {
    // Don't remove if last elem in linked list
    if (arr[i].prev == NULL && arr[i].next == NULL)
	return;
    if (arr[i].prev != NULL)
	(*(arr[i].prev)).next = arr[i].next;
    else
	head = arr[i].next;
    if (arr[i].next != NULL)
	(*(arr[i].next)).prev = arr[i].prev;
    else
	tail = arr[i].prev;
    arr[i].data[0] = 0;
    arr[i].next = NULL;
    arr[i].prev = NULL;
}

void add_rm (size_t i) {
    if (arr[i].data[0] == 0)
	add(i);
}

void setup(size_t seed) {
    srand(seed);
    arr[0].data[0] = 1;
    arr[0].next = NULL;
    arr[0].prev = NULL;
    for (size_t i = 1; i < ARR_SIZE; i++)
	arr[i].data[0] = 0;
    for (size_t i = 0; i < 5*ARR_SIZE; i++)
	add_rm(rand()%ARR_SIZE);

    // Add remaining elements
    for (size_t i = 0; i < ARR_SIZE; i++)
	    add_rm(i);
}

void run() {
    struct node *curr = head;
    while (curr != tail)
	curr = (*curr).next;
}

void run_sequential() {
    size_t sum = 0;
    for (size_t i = 0; i < ARR_SIZE; i++)
	sum+=arr[i].data[0];
}

int main() {
    printf("size, elem_size, latency\n");
    for (ARR_SIZE = 64; ARR_SIZE < 1024*1024*1024/sizeof(struct node); ARR_SIZE*=2) {
	for (size_t exprmnt = 0; exprmnt < EXPERIMENTS; exprmnt++) {
	    arr = (struct node*) malloc(ARR_SIZE*sizeof(struct node));
	    tail = arr;
	    head = arr;

	    // load cache
	    for (size_t i = 0; i < ARR_SIZE; i++)
		arr[i];
	    #ifdef SEQ
	    clock_t begin = clock();
	    run_sequential();
	    clock_t end = clock();	    
	    #endif
	    #ifndef SEQ
	    setup(0);
	    clock_t begin = clock();
	    run();
	    clock_t end = clock();
	    #endif
	    free(arr);
	    double res = (end - begin)*1000000./CLOCKS_PER_SEC/ARR_SIZE;
	    printf("%lu, %lu, %f\n", ARR_SIZE*sizeof(struct node)/1024, sizeof(struct node), res);
	}
    }
    return 0;
}
