#include <iostream>
#include <random>
#include <algorithm>
#include <fstream>
#include <inttypes.h>
#include <chrono>
#include <vector>
#include <unordered_set>
#include <string>
#include <iomanip>
#include <sstream>
#include <thread>

#include <cuda.h>
#include <curand_kernel.h>

#include <windows.h>

#ifndef MAIN
#define MAIN
#include "main.h"
#endif

#ifndef HASHTABLE
#define HASHTABLE
#include "HashTable.h"
#endif

#ifndef HASHINCLUDED
#define HASHINCLUDED
#include "hashfunctions.cu"
#endif

#include "Test.cu"

#include "Benchmark.cu"

#ifndef TABLES
#define TABLES
#include "ClearyCuckoo.cu"
#include "Cleary.cu"
#endif


/*
 *
 *	Helper Functions
 *
 */


//Sources: https://stackoverflow.com/questions/1894886/parsing-a-comma-delimited-stdstring
//         https://stackoverflow.com/questions/11876290/c-fastest-way-to-read-only-last-line-of-text-file
std::vector<std::string>* getLastArgs(std::string filename) {
    std::string line;
    std::ifstream infile;
    infile.open(filename);

    if (infile.is_open())
    {
        char ch;
        infile.seekg(-1, std::ios::end);        // move to location 65
        infile.get(ch);                         // get next char at loc 66
        if (ch == '\n')
        {
            infile.seekg(-2, std::ios::cur);    // move to loc 64 for get() to read loc 65
            infile.seekg(-1, std::ios::cur);    // move to loc 63 to avoid reading loc 65
            infile.get(ch);                     // get the char at loc 64 ('5')
            while (ch != '\n')                   // read each char backward till the next '\n'
            {
                infile.seekg(-2, std::ios::cur);
                infile.get(ch);
            }
            std::string lastLine;
            std::getline(infile, lastLine);
            std::cout << "The last line : " << lastLine << '\n';
            line = lastLine;
        }
        else
            printf("Exception:Check CSV format\n");
            throw std::exception();
    }
    else {
        printf("File failed to open\n");
        return nullptr;
    }

    std::vector<std::string>* vect = new  std::vector<std::string>;
    std::stringstream ss(line);
    std::string field;

    while (getline(ss, field, ',')) {
        vect->push_back(field);
    }

    for (std::size_t i = 0; i < vect->size(); i++){
        std::cout << vect->at(i) << std::endl;
    }

    return vect;
}

void copyArray(uint64_cu* source, uint64_cu* dest, int N) {
    for (int i = 0; i < N; i++) {
        dest[i] = source[i];
    }
}

/*
 *
 * Main Function
 *
 */

int main(int argc, char* argv[])
{
    if (argc == 1) {
        printf("No Arguments Passed\n");
    }

    if (strcmp(argv[1], "test") == 0) {
        if (strcmp(argv[2], "TABLE") == 0) {
            bool c = false;
            bool cc = false;

            if (argc < 6) {
                printf("Not Enough Arguments Passed\n");
                printf("Required: TABLESIZE, NUM_THREADS, SAMPLES, TABlETYPE (c cc ccc)\n");
                return 0;
            }

            std::string s = argv[6];
            c = s == "c";
            cc = s == "cc";
            if (s == "ccc") {
                c = true;
                cc = true;
            }

            TableTest(std::stoi(argv[3]), std::stoi(argv[4]), std::stoi(argv[5]), c, cc);
        }
        else if (strcmp(argv[2], "NUMGEN") == 0) {
            numGenTest(std::stoi(argv[3]), std::stoi(argv[4]), std::stoi(argv[5]), std::stoi(argv[6]));
        }
        else {
            printf("Possible Tests:\nTABLE, NUMGEN\n");
        }
    }
    else if (strcmp(argv[1], "benchmax") == 0) {
        if (argc < 6) {
            printf("Not Enough Arguments Passed\n");
            printf("Required: TABLESIZES, NUM_HASHES, NUM_LOOPS, NUM_SAMPLES\n");
            return 0;
        }
        BenchmarkMaxOccupancy(std::stoi(argv[2]), std::stoi(argv[3]), std::stoi(argv[4]), std::stoi(argv[5]));
    }
    else if (strcmp(argv[1], "benchfill") == 0) {
        if (argc < 10) {
            printf("Not Enough Arguments Passed\n");
            printf("Required: NUM_TABLES start, end, INTERVAL, NUM_SAMPLES, NUM_THREADS, NUM_LOOPS, NUM_HASHES, PERCENTAGE, PERCENTAGE_STEPSIZE, DEPTH\n");
            return 0;
        }
        else if (strcmp(argv[2], "continue") == 0) {
            printf("Continuing from Last Position\n");
            std::vector<std::string>* lastargs = getLastArgs("results/benchfill.csv");

            BenchmarkFilling(std::stoi(argv[3]), std::stoi(argv[4]), std::stoi(argv[5]), std::stoi(argv[6]), std::stoi(argv[7]), std::stoi(argv[8]), std::stoi(argv[9]), std::stoi(argv[9]), std::stoi(argv[10]), std::stoi(argv[11]), lastargs);
            delete lastargs;
            return 0;
        }

        BenchmarkFilling(std::stoi(argv[2]), std::stoi(argv[3]), std::stoi(argv[4]), std::stoi(argv[5]), std::stoi(argv[6]), std::stoi(argv[7]), std::stoi(argv[8]), std::stoi(argv[9]), std::stoi(argv[10]), std::stoi(argv[11]));
    }

    else if (strcmp(argv[1], "debug") == 0) {
        int NUM_THREADS = 8;

        uint64_cu* test2 = generateTestSetParallel(10000, NUM_THREADS);
        printf("Generated:\n");
        for (int i = 0; i < 10000; i++) {
            printf("%i: %" PRIu64 "\n",i, test2[i]);
        }
    }

    return 0;
}
