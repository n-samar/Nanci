#include <stdio.h>
#include <iostream>
#include <iomanip>

using namespace std;

int main() {
  for (int i = 64; i >= 4; i/=4) {
    for (int j = i-1; j >= 0; j--) {
      cout << "../data/" << setw(4) << setfill('0') << i
	   << "/" << setw(4) << setfill('0') << j
	   << ".data";
    }
  }
  return 0;
}
