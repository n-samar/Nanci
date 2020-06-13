#include <iomanip>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <iostream>
#include <assert.h>
#include <map>
#include <vector>
#include <iterator>
#include <algorithm>
#include <unistd.h>
#include <stack>
#include <fstream>
#include <sstream>
#include <bitset>
#include <sys/types.h> 
#include <sys/stat.h>

using namespace std;

static bool RECORD = false;     // output execution diagram for each process (use `-r')
static bool N_DEBUG = false;    // No asserts run when true (use `-a' or `--assert')
static bool HUMAN = false;      // Generate human-readable output (use `-h')
static bool PRINT_S = false;
static bool DATA = false;       // Get data for readmemb
struct inst {
    bool is_CAS;
    unsigned long cycle;
    size_t src;
    size_t dst;
};

std::vector<std::map<size_t, vector<struct inst> > *> inst_map_stack;

void print_matrix(int *a, size_t N, size_t M) {
    for (size_t i = 0; i < N; i++) {
        for (size_t j = 0; j < M; j++) {
            if (j!=0)
                cout << ", ";
            cout << setw(2) << setfill('0') << a[i*M+j];
        }
        cout << endl;
    }
}

size_t snake_to_index(size_t i, size_t N, size_t M) {
    size_t i_j = i/M;
    size_t i_k = i%M;
    if (i_j % 2 == 1)
        i_k = M-1-i_k;
    return M*i_j+i_k;
}

size_t index_to_snake(size_t i, size_t N, size_t M) {
    size_t snake = i/M + ((i/M)%2)?(M-1-(i%M)):(i%M);
    return snake;
}

// j == N specifies row
// k == M specifies column
void make_submatrix(int *a, int *b, size_t a_j, size_t a_k, size_t a_height, 
                    size_t a_width, size_t height, size_t width) {
    assert(a_j+height <= a_height);
    assert(a_k+width <= a_width);
    for (size_t j = a_j; j < a_j+height; j++) {
        for (size_t k = a_k; k < a_k+width; k++) {
            b[(j-a_j)*width + (k-a_k)] = a[j*a_width + k];
            assert((j-a_j)*width+(k-a_k) < height*width);
            assert((j*a_width) + k < a_height*a_width);
        }
    }

    if (RECORD || DATA) {
        inst_map_stack.push_back(new std::map<size_t, vector<struct inst> >());
    }
}

// j == N specifies row
// k == M specifies column
void copy_back_matrix(int *a, int *b, size_t a_j, size_t a_k, size_t a_height, size_t a_width, size_t height, size_t width, size_t cycle_low, size_t cycle_high) {
    assert(a_j+height <= a_height);
    assert(a_k+width <= a_width);
    for (size_t j = a_j; j < a_j+height; j++) {
        for (size_t k = a_k; k < a_k+width; k++) {
            a[j*a_width + k] = b[(j-a_j)*width + (k-a_k)];
            assert((j-a_j)*width+(k-a_k) < height*width);
            assert((j*a_width) + k < a_height*a_width);          
        }
    }

    if (RECORD || DATA) {
        std::map<size_t, vector<struct inst> > *top = inst_map_stack.back();

        for (size_t cyc = cycle_low; cyc < cycle_high; cyc++) {
            for (auto & elem : (*top)[cyc]) {
                size_t src_j = elem.src/width;
                size_t src_k = elem.src%width;
                size_t dst_j = elem.dst/width;
                size_t dst_k = elem.dst%width;
                (*(inst_map_stack.end()[-2]))[cyc].push_back((struct inst) {elem.is_CAS, elem.cycle, 
                                                                            (a_j+src_j)*a_width+src_k+a_k, 
                                                                            (a_j+dst_j)*a_width+dst_k+a_k});
            }
        }
        inst_map_stack.pop_back();
    }
}

void assert_sorted_snake(int *a, size_t N, size_t M) {
    for (size_t i = 0; i < N; i++) {
        for (size_t j = 0; j < M; j++) {
            if (i%2 == 0 && j+1 < M)
                assert(a[i*M+j]<=a[i*M+j+1]);
            else if (i%2 == 1 && j+1 < M)
                assert(a[i*M+j]>=a[i*M+j+1]);
            else if (i%2 == 0 && j+1 == M && i < N-1)
                assert(a[i*M+M-1]<=a[(i+1)*M+M-1]);
            else if (i%2 == 1 && j+1 == M && i < N-1)
                assert(a[i*M+0]<=a[(i+1)*M+0]);
        }
    }
}


void S(int *a, size_t i, size_t j, size_t cycle) {
    int temp = a[i];
    a[i] = a[j];
    a[j] = temp;
    if (PRINT_S)
        cout << "  S: " << cycle << ", " << i << ", " << j << endl;
    if (RECORD) {
        (*inst_map_stack.back())[cycle].push_back((struct inst) {false, cycle, i, j});
        (*inst_map_stack.back())[cycle].push_back((struct inst) {false, cycle, j, i});
    }
}

void CAS(int *a, size_t i, size_t j, size_t cycle) {
    assert(i<=j);
    if (a[i] > a[j]) {
        int temp = a[i];
        a[i] = a[j];
        a[j] = temp;
    }
    if (PRINT_S)
        cout << "CAS: " << cycle << ", " << i << ", " << j << endl;
    if (RECORD || DATA) {
        (*inst_map_stack.back())[cycle].push_back((struct inst) {true, cycle, i, j});
        (*inst_map_stack.back())[cycle].push_back((struct inst) {true, cycle, j, i});
    }
}

void CAS_snake(int *a, size_t N, size_t M, size_t i, size_t j, size_t cycle) {
    assert(i<=j);
    size_t i_j = i/M;
    size_t i_k = i%M;
    if (i_j % 2 == 1)
        i_k = M-1-i_k;
    size_t j_j = j/M;
    size_t j_k = j%M;
    if (j_j % 2 == 1)
        j_k = M-1-j_k;
    
    assert(M*i_j+i_k < M*N);
    assert(M*j_j+j_k < M*N);
    size_t x = M*i_j+i_k;
    size_t y = M*j_j+j_k;
    if(a[M*i_j+i_k] > a[M*j_j+j_k]) {
        int temp = a[x];
        a[x] = a[y];
        a[y] = temp;
    }
    if (PRINT_S)
        cout << "CAS: " << cycle << ", " << x << ", " << y << endl;
    if (RECORD || DATA) {
        (*inst_map_stack.back())[cycle].push_back((struct inst) {true, cycle, x, y});
        (*inst_map_stack.back())[cycle].push_back((struct inst) {true, cycle, y, x});
    }
}


size_t perfect_shuffle(int *a, size_t n, size_t cycle) {
    if (PRINT_S)
        cout << "perfect_shuffle: " << cycle << endl;
    if (n == 1)
        return cycle;
    assert(n%2 == 0);
    for (size_t depth = 1; depth < n/2; depth++) {
        for (size_t step = n/2-depth; step < n/2+depth-1; step+=2) {
            S(a, step, step+1, cycle);
        }
        cycle++;
    }
    return cycle;
}


size_t odd_even_transposition_sort(int *a, size_t n, size_t width, size_t cycle) {
    if (PRINT_S)
        cout << "odd_even_transposition_sort: " << cycle << endl;
    if (n*width == 1) {
        return cycle;
    }
    if (n == 1 && width == 2) {
        CAS_snake(a, 1, 2, 0, 1, cycle);
        return cycle+1;
    }

    for (size_t count = 0; count < n*width; count++) {
        for(size_t i = (count+1)%2; i < n*width-1; i+=2) {
            CAS_snake(a, n, width, i, i+1, cycle);
        }
        cycle++;
    }
    return cycle;
}

size_t perfect_shuffle_reverse(int *a, size_t n, size_t cycle) {
    if (PRINT_S)
        cout << "perfect_shuffle_reverse: " << cycle << ", " << n << endl;
    if (n == 1)
        return cycle;
    assert(n%2 == 0);
    for (size_t depth = n/2-1; depth > 0; depth--) {
        for (size_t step = n/2-depth; step < n/2+depth-1; step+=2) {
            S(a, step, step+1, cycle);
        }
        cycle++;
    }
    return cycle;
}

size_t compare_swap(int *a, size_t n, size_t cycle) {
    if (PRINT_S)
        cout << "compare_swap: " << cycle << endl;
    if (n == 2) {
        CAS_snake(a, 1, n, 0, 1, cycle);
    } else {
        for (size_t i = 1; i<n-1; i+=2)
            CAS_snake(a, 1, n, i, i+1, cycle);
    }
    cycle++;
    return cycle;
}

size_t two_way_odd_even_merge(int *a, size_t n, size_t cycle) {
    if (PRINT_S)
        cout << "two_way_odd_even_merge: " << cycle << endl;
    if (n == 1)
        return cycle;
    cycle = perfect_shuffle_reverse(a, n, cycle);
    two_way_odd_even_merge(a, n/2, cycle);
    size_t temp;
    int *b = new int[n/2];
    make_submatrix(a, b, 0, n/2, 1, n, 1, n/2);
    temp = two_way_odd_even_merge(b, n/2, cycle);
    copy_back_matrix(a, b, 0, n/2, 1, n, 1, n/2, cycle, temp);
    delete[] b;
    cycle = perfect_shuffle(a, n, cycle);
    cycle = compare_swap(a, n, cycle);
    return cycle;
}

void print_arr(int *a, size_t n) {
    for (size_t i = 0; i < n; i++) {
        if (i != 0)
            cout << ", ";
        cout << a[i];
    }
    cout << endl;
}

void print_arr(int *a, size_t n, size_t step_size) {
    for (size_t i = 0; i/step_size < n; i+=step_size) {
        if (i != 0)
            cout << ", ";
        cout << a[i];
    }
    cout << endl;
}

void assert_sorted(int *a, size_t n) {
    for (size_t i = 0; i < n-1; i++) {
        assert(a[i]<=a[i+1]);
    }
}

void assert_sorted(int *a, size_t n, size_t step_size) {
    for (size_t i = 0; i/step_size < n-1; i+=step_size) {
        assert(a[i]<=a[i+step_size]);
    }
}

void init_rand(int *a, size_t n) {
    srand(time(NULL));
    for (size_t i = 0; i < n; i++)
        a[i] = rand() % 100;
}

void init_rand_sorted(int *a, size_t n) {
    srand(time(NULL)*((long int)a));
    a[0] = 0;
    for (size_t i = 1; i < n; i++)
        a[i] = a[i-1] + (rand() % 100);
}

void init_rand_sorted_step(int *a, size_t n, size_t step) {
    srand(time(NULL)*((long int)a));
    a[0] = 0;
    for (size_t i = step; i/step < n; i+= step)
        a[i] = a[i-step] + (rand() % 100);
}


void print_inst(struct inst elem) {
    cout << elem.is_CAS << ", "
         << elem.cycle << ", "
         << elem.src << ", "
         << elem.dst << endl;
}

void get_actions(size_t i) {
    cout << "is_CAS, cycle, src, dst" << endl;
    for (auto & elem : (*(inst_map_stack.back()))[i])
        print_inst(elem);
}

void print_all(size_t cycles, size_t N_PE) {
    map<size_t, vector<struct inst> > chrono_insts = *(inst_map_stack.back());
    size_t *data = NULL;
    if (DATA)
        data = new size_t[cycles*N_PE];
    if (RECORD) {
        cout << "cycle num, ";
        
        for (size_t i = 0; i < N_PE; ++i) {
            cout << std::setfill(' ') << std::setw(HUMAN?9:5)  << i;
            if (i+1 < N_PE)
                cout << ", ";
        }
    cout << endl;
    }    


    size_t N = size_t(sqrt(N_PE));
    for (size_t i = 0; i < cycles; ++i) {
        sort(chrono_insts[i].begin(), chrono_insts[i].end(), [](struct inst a, struct inst b) { return a.src > b.src; });
        if (RECORD)
            cout << std::setfill(' ') << std::setw(9) << i << ", ";
        for (size_t j = 0; j < N_PE; j++) {
            if (!chrono_insts[i].empty() && chrono_insts[i].back().src == j) {
                size_t dst = chrono_insts[i].back().dst;
                string inst;
                if (HUMAN) inst = "s  ";
                else inst = "11_";
                if (DATA) data[i*N_PE + j] = 0b1100;
                if (chrono_insts[i].back().is_CAS) {
                    size_t snake_dst = index_to_snake(dst, N, N);
                    size_t snake_src = index_to_snake(j, N, N);
                    if (snake_src > snake_dst) {
                        if (HUMAN) inst = "slt";
                        else inst = "01_";
                        if (DATA) data[i*N_PE + j] = 0b1100;
                    } else { 
                        if (HUMAN) inst = "sgt";
                        else inst = "10_";
                        if (DATA) data[i*N_PE + j] = 0b1100;
                    }
                }
                string dir;
                if (HUMAN) dir = "_____";
                else dir = "00";
                if (dst+1 == j) {
                    if (HUMAN) dir = "  left";
                    else dir = "00";
                    if (DATA) data[i*N_PE + j] += 0b00;
                } else if (dst-1 == j) {
                    if (HUMAN) dir = " right";
                    else dir = "01";
                    if (DATA) data[i*N_PE + j] += 0b01;
                } else if (dst+N == j) {
                    if (HUMAN) dir = "    up";
                    else dir = "10";
                    if (DATA) data[i*N_PE + j] += 0b10;
                } else if (dst-N == j) {
                    if (HUMAN) dir = "  down";
                    else dir = "11";
                    if (DATA) data[i*N_PE + j] += 0b11;
                }
                if (RECORD)
                    cout << inst << dir;
                while (!chrono_insts[i].empty() && chrono_insts[i].back().src == j) chrono_insts[i].pop_back();
            } else {
                if (RECORD) {
                    if (HUMAN) cout << "      nop";
                    else cout << "00_00";
                }
                if (DATA) data[i*N_PE + j] = 0b0000;
            }
            if (j+1 < N_PE && RECORD)
                cout << ", ";
        }
        if (RECORD)
            cout << "\n";
    }

    if (DATA) {
        stringstream ss;
        ss << "../data/" << std::setfill('0') << setw(4) << N_PE << "/";
        if (mkdir(ss.str().c_str(), 0777)) {
            cout << "ERROR: couldn't create file!" << endl;
            exit(EXIT_FAILURE);
        }
        for (size_t j = 0; j < N_PE; j++) {
            stringstream ss2;
            ss2 << "../data/" << std::setfill('0') << setw(4) << N_PE << "/"
                << std::setfill('0') << setw(4) << j << ".data";
            string filename = ss2.str();
            ofstream outputFile;
            outputFile.open(filename);
            for (size_t i = 0; i < cycles; i++) {
                outputFile << std::bitset<4>(data[i*N_PE + j]) << endl;
            }
            outputFile.close();
        }
    }
}

// j == N specifies row
// k == M specifies column
size_t M_j_two_s(int *a, size_t j, size_t s, size_t cycle) {
    if (PRINT_S)
        cout << "M_j_two_s: " << cycle << endl;

    // J1
    for (size_t i = 0; i < 2*j; i+=4) {
        S(a, i+1, i+3, cycle);
        S(a, i+2, i+3, cycle+1);
    }
    cycle+=2;


    // J2
    int *b = new int[j];

    make_submatrix(a, b, 0, 0, j, 2, j, 1);
    size_t temp = odd_even_transposition_sort(b, j, 1, cycle);
    copy_back_matrix(a, b, 0, 0, j, 2, j, 1, cycle, temp);

    make_submatrix(a, b, 0, 1, j, 2, j, 1);
    temp = odd_even_transposition_sort(b, j, 1, cycle);
    copy_back_matrix(a, b, 0, 1, j, 2, j, 1, cycle, temp);
    cycle = temp;

    delete[] b;
    
    // J3
    for (size_t i = 2; i < 2*j; i+=4) {
        S(a, i, i+1, cycle);
    }
    cycle++;

    // M6 prime
    size_t N = j;
    size_t M = 2;
    for (size_t ind = 1; ind < 2*s; ind+=1) {
        for (size_t i = ind%2; i < N*M-1; i+=2) {
            CAS_snake(a, N, M, i, i+1, cycle);
        }
        cycle++;
    }

    return cycle;
}

size_t M_j_two(int *a, size_t j, size_t cycle) {
    if (PRINT_S)
        cout << "M_j_two: " << cycle << endl;

    // J1
    for (size_t i = 0; i < 2*j; i+=4) {
        S(a, i+1, i+3, cycle);
        S(a, i+2, i+3, cycle+1);
    }
    cycle+=2;

    // J2
    int *b = new int[j];
    make_submatrix(a, b, 0, 0, j, 2, j, 1);
    size_t temp = odd_even_transposition_sort(b, j, 1, cycle);
    copy_back_matrix(a, b, 0, 0, j, 2, j, 1, cycle, temp);

    make_submatrix(a, b, 0, 1, j, 2, j, 1);
    temp = odd_even_transposition_sort(b, j, 1, cycle);
    copy_back_matrix(a, b, 0, 1, j, 2, j, 1, cycle, temp);
    cycle = temp;

    delete[] b;

    // J3
    for (size_t i = 2; i < 2*j; i+=4) {
        S(a, i, i+1, cycle);
    }

    // J4
    for (size_t i = 1; i+1 < 2*j; i+=2) {
        CAS_snake(a, j, 2, i, i+1, cycle);
    }
    cycle++;
    return cycle;
}

// j == N specifies row
// k == M specifies column
size_t Mf(int *a, size_t N, size_t M, size_t cycle) {
    if (PRINT_S)
        cout << "Mf: " << cycle << endl;
    // M1
    if (M == 2) {
        cycle = M_j_two(a, N, cycle);
        return cycle;
    }

    for (size_t j = 1; j < N; j+=2) {
        for (size_t k = 0; k < M-1; k+=2) {
            S(a, j*M+k, j*M+k+1, cycle);
        }
    }
    cycle++;


    // M2
    size_t temp = cycle;
    int *b = new int[M];
    for (size_t j = 0; j < N; j++) {
        make_submatrix(a, b, j, 0, N, M, 1, M);
        temp = perfect_shuffle_reverse(b, M, cycle);
        copy_back_matrix(a, b, j, 0, N, M, 1, M, cycle, temp);
    }
    cycle = temp;
    delete[] b;

    // M3

    b = new int[N*M/2];

    make_submatrix(a, b, 0, 0, N, M, N, M/2);
    temp = Mf(b, N, M/2, cycle);
    copy_back_matrix(a, b, 0, 0, N, M, N, M/2, cycle, temp);

    make_submatrix(a, b, 0, M/2, N, M, N, M/2);
    temp = Mf(b, N, M/2, cycle);
    copy_back_matrix(a, b, 0, M/2, N, M, N, M/2, cycle, temp);
    cycle = temp;

    delete[] b;

    // M4
    b = new int[M];
    for (size_t j = 0; j < N; j++) {
        make_submatrix(a, b, j, 0, N, M, 1, M);
        temp = perfect_shuffle(b, M, cycle);
        copy_back_matrix(a, b, j, 0, N, M, 1, M, cycle, temp);
    }
    cycle = temp;
    delete[] b;

    // M5
    for (size_t j = 1; j < N; j+=2)
        for (size_t k = 0; k < M-1; k+=2)
            S(a, j*M+k, j*M+k+1, cycle);
    cycle++;

    // M6
    for (size_t i = 1; i < N*M-1; i+=2)
        CAS_snake(a, N, M, i, i+1, cycle);
    cycle++;

    return cycle;
}


// j == N specifies row
// k == M specifies column
size_t two_s_way_M(int *a, size_t N, size_t M, size_t s, size_t cycle) {
    if (PRINT_S)
        cout << "two_s_way_M: " << cycle << endl;
    if (M == 2 && N > s) {
        cycle = M_j_two_s(a, N, s, cycle);
        assert_sorted_snake(a, N, M);
        return cycle;
    } else if (M == 2 && N == s) {
        cycle = odd_even_transposition_sort(a, N, 2, cycle);
        assert_sorted_snake(a, N, M);
        return cycle;
    }

    // M1 prime
    if (N > s) {
        for (size_t j = 1; j < N; j+=2)
            for (size_t k = 0; k < M-1; k+=2)
                S(a, j*M+k, j*M+k+1, cycle);
        cycle++;
    }

    // M2
    size_t temp = cycle;
    int *b = new int[M];
    for (size_t j = 0; j < N; j++) {
        make_submatrix(a, b, j, 0, N, M, 1, M);
        temp = perfect_shuffle_reverse(b, M, cycle);
        copy_back_matrix(a, b, j, 0, N, M, 1, M, cycle, temp);
    }
    cycle = temp;
    delete[] b;

    // M3
    b = new int[N*M/2];

    make_submatrix(a, b, 0, 0, N, M, N, M/2);
    temp = two_s_way_M(b, N, M/2, s, cycle);
    copy_back_matrix(a, b, 0, 0, N, M, N, M/2, cycle, temp);


    make_submatrix(a, b, 0, M/2, N, M, N, M/2);
    temp = two_s_way_M(b, N, M/2, s, cycle);
    copy_back_matrix(a, b, 0, M/2, N, M, N, M/2, cycle, temp);
    cycle = temp;
    delete[] b;

    // M4
    b = new int[M];
    for (size_t j = 0; j < N; j++) {
        make_submatrix(a, b, j, 0, N, M, 1, M);
        temp = perfect_shuffle(b, M, cycle);
        copy_back_matrix(a, b, j, 0, N, M, 1, M, cycle, temp);
    }
    cycle = temp;
    delete[] b;
        
    // M5
    for (size_t j = 1; j < N; j+=2)
        for (size_t k = 0; k < M-1; k+=2)
            S(a, j*M+k, j*M+k+1, cycle);
    cycle++;

    // M6 prime
    for (size_t j = 1; j < 2*s; j+=1) {
        for (size_t i = j%2; i < N*M-1; i+=2)
            CAS_snake(a, N, M, i, i+1, cycle);
        cycle++;
    }
    
    assert_sorted_snake(a, N, M);
    return cycle;
}


// j == N specifies row
// k == M specifies column
size_t M_prime_prime(int *a, size_t N, size_t M, size_t s, size_t cycle) {
    if (PRINT_S)
        cout << "M_prime_prime: " << cycle << endl;
    if (s == 1)
        return cycle;
    if (s == 2) {
        cycle = two_s_way_M(a, N, M, s, cycle);
        return cycle;
    }
    if (M == s) {
        // N1
        size_t temp = cycle;
        for (size_t count = 2; count < s; count*=2) {
            int *b = new int[count*N/s];
            for (size_t j_sub = 0; j_sub < N; j_sub+=N/s) {
                for (size_t k_sub = 0; k_sub < M; k_sub+=count) {
                    make_submatrix(a, b, j_sub, k_sub, N, M, N/s, count);
                    temp = Mf(b, N/s, count, cycle);
                    copy_back_matrix(a, b, j_sub, k_sub, N, M, N/s, count, cycle, temp);
                }
            }
            delete[] b;
            cycle = temp;
        }

        // N2
        cycle = two_s_way_M(a, N, M, s, cycle);
        assert_sorted_snake(a, N, M);
        return cycle;
    }

    // M1 prime prime
    for (size_t j = 1; j < N; j+=2)
        for (size_t k = 0; k < M-1; k+=2)
            S(a, j*M+k, j*M+k+1, cycle);
    cycle++;

    // M2
    size_t temp = cycle;
    int *b = new int[M];
    for (size_t j = 0; j < N; j++) {
        make_submatrix(a, b, j, 0, N, M, 1, M);
        temp = perfect_shuffle_reverse(b, M, cycle);
        copy_back_matrix(a, b, j, 0, N, M, 1, M, cycle, temp);
    }
    cycle = temp;
    delete[] b;

    // M3
    b = new int[N*M/2];

    make_submatrix(a, b, 0, 0, N, M, N, M/2);
    temp = M_prime_prime(b, N, M/2, s, cycle);
    copy_back_matrix(a, b, 0, 0, N, M, N, M/2, cycle, temp);

    make_submatrix(a, b, 0, M/2, N, M, N, M/2);
    temp = M_prime_prime(b, N, M/2, s, cycle);
    copy_back_matrix(a, b, 0, M/2, N, M, N, M/2, cycle, temp);
    cycle = temp;

    delete[] b;

    // M4
    b = new int[M];
    for (size_t j = 0; j < N; j++) {
        make_submatrix(a, b, j, 0, N, M, 1, M);
        temp = perfect_shuffle(b, M, cycle);
        copy_back_matrix(a, b, j, 0, N, M, 1, M, cycle, temp);
    }
    cycle = temp;
    delete[] b;
    
    // M5
    for (size_t j = 1; j < N; j+=2)
        for (size_t k = 0; k < M-1; k+=2)
            S(a, j*M+k, j*M+k+1, cycle);
    cycle++;

    // M6 prime prime
    for (size_t j = 1; j < s*s; j+=1) {
        for (size_t i = j%2; i < N*M-1; i+=2) {
            CAS_snake(a, N, M, i, i+1, cycle);
        }
        cycle++;
    }
    
    assert_sorted_snake(a, N, M);
    return cycle;
}


void init_rand_sorted_snake(int *a, size_t N, size_t M) {
    a[snake_to_index(0, N, M)] = 0;
    for (size_t i = 1; i < N*M; i++)
        a[snake_to_index(i, N, M)] = a[snake_to_index(i-1, N, M)] + rand()%100;
}


size_t find_nearest_pow_2(double cbrt) {
    size_t res = (size_t)floor(log2(cbrt));
    if (fabs(pow(pow(2.0, res), 3) - cbrt) > fabs(pow(pow(2, res+1), 3) - cbrt))
        res++;
    if (res == 0)
        res++;
    return pow(2.0, res);
}

// j == N specifies row
// k == M specifies column
size_t sort_6n(int *a, size_t N, size_t M, size_t cycle) {
    if (PRINT_S)
        cout << "sort_6n: " << cycle << endl;
    if (N == 1 && M == 1)
        return cycle;

    size_t s = find_nearest_pow_2(cbrt(N));

    size_t temp = cycle;
    for (size_t j = 0; j < N; j+=(N/s)) {
        for (size_t k = 0; k < M; k+=(M/s)) {
            int *b = new int[N/s*M/s];        
            make_submatrix(a, b, j, k, N, M, N/s, M/s);
            temp = sort_6n(b, N/s, M/s, cycle);
            copy_back_matrix(a, b, j, k, N, M, N/s, M/s, cycle, temp);
            delete[] b;      
        }
    }
    cycle = temp;

    cycle = M_prime_prime(a, N, M, s, cycle);
    assert_sorted_snake(a, N, M);
    return cycle;
}

size_t sort_12n(int *a, size_t N, size_t M, size_t cycle) {
    if (PRINT_S)
        cout << "sort_12n: " << cycle << endl;
    if (N == 1 && M == 1)
        return cycle;
    int *b = new int[N/2*M/2];

    size_t temp;

    make_submatrix(a, b, 0, 0, N, M, N/2, M/2);
    temp = sort_12n(b, N/2, M/2, cycle);
    copy_back_matrix(a, b, 0, 0, N, M, N/2, M/2, cycle, temp);

    make_submatrix(a, b, 0, M/2, N, M, N/2, M/2);
    temp = sort_12n(b, N/2, M/2, cycle);
    copy_back_matrix(a, b, 0, M/2, N, M, N/2, M/2, cycle, temp);

    make_submatrix(a, b, N/2, 0, N, M, N/2, M/2);
    temp = sort_12n(b, N/2, M/2, cycle);
    copy_back_matrix(a, b, N/2, 0, N, M, N/2, M/2, cycle, temp);

    make_submatrix(a, b, N/2, M/2, N, M, N/2, M/2);
    temp = sort_12n(b, N/2, M/2, cycle);
    copy_back_matrix(a, b, N/2, M/2, N, M, N/2, M/2, cycle, temp);        
    cycle = temp;

    delete[] b;

    cycle = two_s_way_M(a, N, M, 2, cycle);
    return cycle;
}

void print_usage() {
    fprintf(stderr, "Usage: sort -N=power_of_two -[a|r|h|d]\n");
}

bool pow_of_2(size_t N) {
    return (!(N & (N-1)) && N > 0);
}

int main(int argc, char *argv[]) {
    int opt;
    size_t z = 3;
    if (argc == 1) {
        print_usage();
        return -1;
    }

    while((opt = getopt(argc, argv, "N:ahrd")) != -1) {
        switch (opt) {
            case 'N':
                z = stoul(optarg);
                break;
            case 'a':
                N_DEBUG = true;
                break;
            case 'h':
                HUMAN = true;
                break;
            case 'r':
                RECORD = true;
                break;
            case 'd':
                DATA = true;
                break;
            default:
                print_usage();
                return -1;
        }
    }

    if (!pow_of_2(z)) {
        print_usage();
        return -1;
    }
    if (RECORD || DATA)
        inst_map_stack.push_back(new std::map<size_t, vector<struct inst> >());
    size_t N = z;
    size_t M = z;
    int *a = new int[N*M];
    init_rand(a, N*M);
    size_t cycle = sort_6n(a, N, M, 0);
    int *b = new int[N*M];
    memcpy(b, a, N*M*sizeof(int));
    assert_sorted_snake(a, N, M);
    sort(a, a+N*M);
    sort(b, b+N*M);
    for (size_t i = 0; i < N*M; i++)
        assert(a[i] == b[i]);
    delete[] a;
    delete[] b;
    
    cout << "sqrt(N) == " << N << "; cycles == " << cycle << endl;
    if (RECORD || DATA) {
        print_all(cycle, z*z);
        if (RECORD)
            cout << "slt down -- swap less than, i.e. swap only if my value is smaller than that of down." << endl;
        inst_map_stack.pop_back();
        assert(inst_map_stack.empty());
    }
    return 0;
}
