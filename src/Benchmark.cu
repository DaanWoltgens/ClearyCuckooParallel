#include <atomic>

#ifndef NUMGEN
#define NUMGEN
#include "numbergenerators.cu"
#endif

void readList(uint64_cu* xs, int N, int numLoops, int T = 1, int id = 0) {
    //printf("Reading List\n");
    int begin = 0;
    int end = N;

    if (T > 1) {
        int spread = N / T;
        begin = spread * id;
        end = begin + spread - 1;
        //printf("Begin: %i End:%i", begin, end);
    }

    for (int i = 0; i < numLoops; i++) {
        //printf("Reading List i:%i\n",i);
        uint64_cu val = 0;
        for (int j = begin; j < end; j++) {
            //printf("Reading List j:%i\n", j);
             val += xs[j];
        }
    }
}

void warmupThreads(int T, uint64_cu* xs, int N, int numLoops) {
    std::vector<std::thread> vecThread(T);
    for (int i = 0; i < T; i++) {
        vecThread.at(i) = std::thread(readList, xs, N, numLoops, T, i);
    }

    //Join Threads
    for (int i = 0; i < T; i++) {
        vecThread.at(i).join();
    }
}

void BenchmarkGeneralFilling(int NUM_TABLES_start, int NUM_TABLES, int INTERVAL, int NUM_SAMPLES, int NUM_THREADS, int NUM_LOOPS, int LOOP_STEP, int NUM_HASHES, int HASH_STEP, int NUM_REHASHES,
    int PERCENTAGE, int P_STEPSIZE, int DEPTH, std::vector<std::string>* params = nullptr) {

    const int WARMUP = 0;

    printf("=====================================================================\n");
    printf("                   Starting INSERTION  GENERAL BENCHMARK             \n");
    printf("=====================================================================\n");

    std::ofstream myfile;
    std::string specifier = "";
#ifdef GPUCODE
    specifier += "-GPU";
#else
    specifier += "-CPU";
#endif
#ifdef REHASH
    specifier += "-REHASH";
#endif
    std::string filename = "results/benchfill" + specifier + ".csv";

    if (params) {
        printf("Opening\n");
        myfile.open(filename, std::ios_base::app);
        printf("Maybe\n");
    }
    else {
        myfile.open(filename);
    }

    if (!myfile.is_open()) {
        printf("File Failed to Open\n");

        return;
    }
    printf("File Opened\n");

    if (!params) {
        myfile << "tablesize,numthreads,loops,hashes,rehashes,collision_percentage,collision_depth,samples,type,interval,time,test\n";
    }

    printf("=====================================================================\n");
    printf("                     Starting Cleary-Cuckoo                \n\n");

    //Tablesizes
    bool setup = true;
    for (int N = NUM_TABLES_start; N < NUM_TABLES_start + NUM_TABLES; N++) {
        if (params && setup) {
            N = std::stoi(params->at(0));
        }
        printf("Table Size:%i\n", N);

        int size = std::pow(2, N);
        int setsize = (int)(size / INTERVAL);
        int lookupSize = size / 4;

        if (setsize == 0) {
            printf("Error: Number of Intervals is greater than number of elements\n");
        }

        //Number of Threads
        //TODO change start to 0
        for (int T = 1; T < NUM_THREADS; T++) {
            if (params && setup) {
                T = std::stoi(params->at(1));
            }
            printf("\tNumber of Threads:%i\n", T);
            //Number of Loops
            for (int L = 0; L < NUM_LOOPS; L+= LOOP_STEP) {
#ifdef GPUCODE
                int numThreads = std::pow(2, T);
#else
                int numThreads = T + 1;
#endif

                if (params && setup) {
                    L = std::stoi(params->at(2));
                }
                printf("\t\tNumber of Loops:%i\n", L);
                //Number of Hashes
                for (int H = 1; H <= NUM_HASHES; H+=HASH_STEP) {
                    printf("\t\t\tNumber of Hashes:%i\n", H);
                    if (params && setup) {
                        H = std::stoi(params->at(3));
                    }

                    for (int R = 0; R <= NUM_REHASHES; R++) {
                        printf("\t\t\t\tRehashes:%i\n", R);
                        for (int P = 0; P <= PERCENTAGE; P += P_STEPSIZE) {
                            printf("\t\t\t\t\tPercentage:%i\n", P);
                            for (int D = 1; D <= DEPTH; D += 1) {
                                printf("\t\t\t\t\t\tDepth:%i\n", D);
                                //Number of samples
                                for (int S = 0; S < NUM_SAMPLES; S++) {
                                    printf("\t\t\t\t\t\t\tSample:%i\n", S);
                                    if (params && setup) {
                                        S = std::stoi(params->at(4));
                                    }
                                    setup = false;
                                    //Init Cleary Cuckoo

    #ifdef GPUCODE
                                    //printf("InitTable\n");
                                    ClearyCuckoo* cc;
                                    //printf("\tAllocTable\n");
                                    gpuErrchk(cudaMallocManaged((void**)&cc, sizeof(ClearyCuckoo)));
                                    //printf("\tStartTable\n");
                                    new (cc) ClearyCuckoo(N, H);
                                    //printf("InitFailFlag\n");
                                    int* failFlag;
                                    gpuErrchk(cudaMallocManaged((void**)&failFlag, sizeof(int)));
                                    (*failFlag) = false;
    #else
                                    ClearyCuckoo* cc = new ClearyCuckoo(N, H);
                                    int* failFlag = new int;
                                    (*failFlag) = false;
    #endif
                                    //printf("SetVals\n");
                                    cc->setMaxLoops(L);
                                    cc->setMaxRehashes(R);
                                    //printf("getHashlistCopy\n");
                                    int* hs = cc->getHashlistCopy();
                                    //printf("Generate CollisionSet\n");
                                    uint64_cu* vals = generateCollisionSet(size, N, H, hs, P, D);
                                    delete[] hs;
                                    //printf("Numsgenned\n");

                                    //printf("vals:\n");


                                    //Warmup
                                    //printf("Warmup\n");
                                    readList(vals, size, 20);
                                    cc->readEverything(size * 50);
                                    warmupThreads(numThreads, vals, size, 20);



                                    //printf("Starting\n");
                                    //Loop over intervals
                                    for (int j = 0; j < INTERVAL + WARMUP; j++) {
                                        //Fill the table
                                        std::chrono::steady_clock::time_point begin;
                                        std::chrono::steady_clock::time_point end;

                                        if (j < WARMUP) {
                                            //cc->readEverything(20);
                                        }

                                        if (j >= WARMUP && !(*failFlag)) {
                                            //printf("Insertion %i\n", j);
                                            begin = std::chrono::steady_clock::now();
    #ifdef GPUCODE
                                            fillClearyCuckoo << <1, std::pow(2, T) >> > (setsize, vals, cc, failFlag, setsize * (j - WARMUP));
                                            gpuErrchk(cudaPeekAtLastError());
                                            gpuErrchk(cudaDeviceSynchronize());
    #else
                                            std::vector<std::thread> vecThread(numThreads);
                                            SpinBarrier barrier(numThreads);
                                            //printf("LAUNCHING THREADS\n");
                                            for (int i = 0; i < numThreads; i++) {
                                                //printf("Starting Threads\n");
                                                vecThread.at(i) = std::thread(static_cast<void(*)(int, uint64_cu*, ClearyCuckoo*, SpinBarrier*, int*, addtype, int, int)>(fillClearyCuckoo), setsize, vals, cc, &barrier, failFlag, setsize * (j - WARMUP), i, numThreads);
                                            }

                                            //Join Threads
                                            for (int i = 0; i < numThreads; i++) {
                                                vecThread.at(i).join();
                                            }
    #endif
                                            //End the timer
                                            end = std::chrono::steady_clock::now();

                                            myfile << N << "," << numThreads << "," << L << "," << H << "," << R << "," << P << "," << D << "," << S << ",cuc," << (j - WARMUP) << "," << (std::chrono::duration_cast<std::chrono::nanoseconds> (end - begin).count()) / setsize << ", INS, \n";
                                        }

                                        if (failFlag) {
                                            myfile << N << "," << numThreads << "," << L << "," << H << "," << R << "," << P << "," << D << "," << S << ",cuc," << (j - WARMUP) << "," << -1 << ", INS,\n";
                                        }

                                        //Lookup Time Test
                                        if (j >= WARMUP && !(*failFlag)) {
                                            begin = std::chrono::steady_clock::now();
#ifdef GPUCODE
                                            lookupClearyCuckoo << <1, std::pow(2, T) >> > (lookupSize, 0, setsize * (j - WARMUP + 1), vals, cc);
                                            gpuErrchk(cudaPeekAtLastError());
                                            gpuErrchk(cudaDeviceSynchronize());
#else
                                            std::vector<std::thread> vecThread(numThreads);
                                            for (int i = 0; i < numThreads; i++) {
                                                //printf("Starting Threads\n");
                                                vecThread.at(i) = std::thread(lookupClearyCuckoo, lookupSize, 0, setsize * (j - WARMUP + 1), vals, cc, i, numThreads);
                                            }

                                            //Join Threads
                                            for (int i = 0; i < numThreads; i++) {
                                                vecThread.at(i).join();
                                            }
#endif
                                            //End the timer
                                            end = std::chrono::steady_clock::now();

                                            myfile << N << "," << numThreads << "," << L << "," << H << "," << R << "," << P << "," << D << "," << S << ",cuc," << (j - WARMUP) << "," << (std::chrono::duration_cast<std::chrono::nanoseconds> (end - begin).count()) / lookupSize << ", LOOK, \n";
                                        }

                                    }
    #ifdef GPUCODE
                                    gpuErrchk(cudaFree(cc));
                                    gpuErrchk(cudaFree(failFlag));
                                    gpuErrchk(cudaFree(vals));
    #else
                                    delete cc;
                                    delete failFlag;
                                    delete[] vals;
    #endif
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    /*
    printf("=====================================================================\n");
    printf("                     Starting Cleary                \n\n");

    for (int N = NUM_TABLES_start; N < NUM_TABLES_start + NUM_TABLES; N++) {
        if (params && setup) {
            N = std::stoi(params->at(0));
        }
        printf("Table Size:%i\n", N);

        int size = std::pow(2, N);
        int setsize = (int)(size / INTERVAL);
        for (int T = 0; T < NUM_THREADS; T++) {
            printf("\tNumber of Threads:%i\n", T);
#ifdef GPUCODE
            int numThreads = std::pow(2, T);
#else
            int numThreads = T + 1;
#endif
            for (int S = 0; S < NUM_SAMPLES; S++) {
                printf("\t\t\t\tSample Number:%i\n", S);
                //uint64_cu* vals = generateTestSetParallel(size, NUM_GEN_THREADS);
                uint64_cu* vals = generateRandomSet(size);

                //Init Cleary
#ifdef GPUCODE
                Cleary* c;
                gpuErrchk(cudaMallocManaged((void**)&c, sizeof(Cleary)));
                new (c) Cleary(N);
#else
                Cleary* c = new Cleary(N);
#endif

                //Loop over intervals
                for (int j = 0; j < INTERVAL + WARMUP; j++) {
                    std::chrono::steady_clock::time_point begin;
                    std::chrono::steady_clock::time_point end;

                    //Fill the table
                    if (j >= WARMUP) {
                        begin = std::chrono::steady_clock::now();
#ifdef GPUCODE

                        fillCleary << <1, numThreads >> > (setsize, vals, c, setsize * (j - WARMUP));
                        gpuErrchk(cudaPeekAtLastError());
                        gpuErrchk(cudaDeviceSynchronize());
#else

                        std::vector<std::thread> vecThread(numThreads);
                        //uint64_cu** valCopy = (uint64_cu**) malloc(sizeof(uint64_cu*) * numThreads);

                        for (int i = 0; i < numThreads; i++) {
                            //valCopy[i] = (uint64_cu*) malloc(sizeof(uint64_cu) * size);
                            //copyArray(vals, valCopy[i], size);
                            vecThread.at(i) = std::thread(fillCleary, setsize, vals, c, setsize * (j - WARMUP), i, numThreads);
                        }

                        //Join Threads
                        for (int i = 0; i < numThreads; i++) {
                            vecThread.at(i).join();
                            //delete[] valCopy[i];
                        }
#endif
                        //End the timer
                        end = std::chrono::steady_clock::now();
                        myfile << N << "," << numThreads << "," << -1 << "," << -1 << "," << -1 << "," << -1 << "," << -1 << "," << S << ",cle," << (j - WARMUP) << "," << (std::chrono::duration_cast<std::chrono::nanoseconds> (end - begin).count()) / setsize << ",\n";
                    }

                }
#ifdef GPUCODE
                gpuErrchk(cudaFree(c));
                gpuErrchk(cudaFree(vals));
#else
                delete c;
                delete[] vals;
#endif
            }
        }
    }
    */

    myfile.close();
    printf("\nBenchmark Done\n");
}


void BenchmarkSpeed(int NUM_TABLES_start, int NUM_TABLES, int INTERVAL, int NUM_SAMPLES, int NUM_THREADS, int PERCENTAGE, int P_STEPSIZE, int DEPTH) {

    const int WARMUP = 0;

    printf("=====================================================================\n");
    printf("                     Starting INSERTION  BENCHMARK                    \n");
    printf("=====================================================================\n");

    std::ofstream myfile;
    std::string specifier = "";
#ifdef GPUCODE
    specifier += "-GPU";
#else
    specifier += "-CPU";
#endif
#ifdef REHASH
    specifier += "-REHASH";
#endif
    std::string filename = "results/benchspeed" + specifier + ".csv";

    myfile.open(filename);

    if (!myfile.is_open()) {
        printf("File Failed to Open\n");

        return;
    }
    printf("File Opened\n");

    myfile << "tablesize,numthreads,collision_percentage,collision_depth,samples,type,interval,time,test\n";

    printf("=====================================================================\n");
    printf("                     Starting Cleary-Cuckoo                \n\n");

    //Tablesizes
    for (int N = NUM_TABLES_start; N < NUM_TABLES_start + NUM_TABLES; N++) {
        printf("Table Size:%i\n", N);

        int size = std::pow(2, N);
        int setsize = (int)(size / INTERVAL);
        int lookupSize = size / 4;

        if (setsize == 0) {
            printf("Error: Number of Intervals is greater than number of elements\n");
        }

        //Number of Threads
        for (int T = 0; T < NUM_THREADS; T++) {
            printf("\tNumber of Threads:%i\n", T);
#ifdef GPUCODE
            int numThreads = std::pow(2, T);
#else
            int numThreads = T + 1;
#endif

            for (int P = 0; P <= PERCENTAGE; P += P_STEPSIZE) {
                printf("\t\tPercentage:%i\n", P);
                for (int D = 1; D <= DEPTH; D += 1) {
                    printf("\t\t\tDepth:%i\n", D);
                    //Number of samples
                    for (int S = 0; S < NUM_SAMPLES; S++) {
                        printf("\t\t\t\tSample:%i\n", S);
                        //Init Cleary Cuckoo

#ifdef GPUCODE
                        ClearyCuckoo* cc;
                        gpuErrchk(cudaMallocManaged((void**)&cc, sizeof(ClearyCuckoo)));
                        new (cc) ClearyCuckoo(N);
                        int* failFlag;
                        gpuErrchk(cudaMallocManaged((void**)&failFlag, sizeof(int)));
                        (*failFlag) = false;
#else
                        ClearyCuckoo* cc = new ClearyCuckoo(N);

                        int* failFlag = new int;
                        (*failFlag) = false;
#endif

                        int* hs = cc->getHashlistCopy();
                        int H = cc->getHashNum();

                        uint64_cu* vals = generateCollisionSet(size, N, H, hs, P, D);
                        delete[] hs;
                        //printf("Numsgenned\n");

                        //printf("vals:\n");


                        //Warmup
                        //printf("Warmup\n");
                        readList(vals, size, 20);
                        cc->readEverything(size * 50);
                        warmupThreads(numThreads, vals, size, 20);


                        //printf("Reading\n");
                        //Loop over intervals
                        for (int j = 0; j < INTERVAL + WARMUP; j++) {
                            //Fill the table
                            std::chrono::steady_clock::time_point begin;
                            std::chrono::steady_clock::time_point end;

                            if (j < WARMUP) {
                                //cc->readEverything(20);
                            }

                            if (j >= WARMUP && !(*failFlag)) {
                                begin = std::chrono::steady_clock::now();
#ifdef GPUCODE
                                fillClearyCuckoo << <1, std::pow(2, T) >> > (setsize, vals, cc, failFlag, setsize * (j - WARMUP));
                                gpuErrchk(cudaPeekAtLastError());
                                gpuErrchk(cudaDeviceSynchronize());
#else
                                std::vector<std::thread> vecThread(numThreads);
                                SpinBarrier barrier(numThreads);

                                for (int i = 0; i < numThreads; i++) {
                                    //printf("Starting Threads\n");
                                    vecThread.at(i) = std::thread(static_cast<void(*)(int, uint64_cu*, ClearyCuckoo*, SpinBarrier*, int*, addtype, int, int)>(fillClearyCuckoo), setsize, vals, cc, &barrier, failFlag, setsize * (j - WARMUP), i, numThreads);
                                }

                                //Join Threads
                                for (int i = 0; i < numThreads; i++) {
                                    vecThread.at(i).join();
                                }
#endif
                                //End the timer
                                end = std::chrono::steady_clock::now();

                                myfile << N << "," << numThreads << "," << P << "," << D << "," << S << ",cuc," << (j - WARMUP) << "," << (std::chrono::duration_cast<std::chrono::nanoseconds> (end - begin).count()) / setsize << ", INS,\n";
                            }
                            if (*failFlag) {
                                myfile << N << "," << numThreads << "," << P << "," << D << "," << S << ",cuc," << (j - WARMUP) << "," << -1 << ",INS,\n";
                            }

                            //Lookup Time Test
                            if(j >= WARMUP && !(*failFlag)) {
                                begin = std::chrono::steady_clock::now();
#ifdef GPUCODE
                                lookupClearyCuckoo << <1, std::pow(2, T) >> > (lookupSize, 0, setsize*(j- WARMUP + 1), vals, cc);
                                gpuErrchk(cudaPeekAtLastError());
                                gpuErrchk(cudaDeviceSynchronize());
#else
                                std::vector<std::thread> vecThread(numThreads);

                                for (int i = 0; i < numThreads; i++) {
                                    //printf("Starting Threads\n");
                                    vecThread.at(i) = std::thread(lookupClearyCuckoo, lookupSize, 0, setsize * (j - WARMUP + 1), vals, cc, i, numThreads);
                                }

                                //Join Threads
                                for (int i = 0; i < numThreads; i++) {
                                    vecThread.at(i).join();
                                }
#endif
                                //End the timer
                                end = std::chrono::steady_clock::now();

                                myfile << N << "," << numThreads << "," << P << "," << D << "," << S << ",cuc," << (j - WARMUP) << "," << (std::chrono::duration_cast<std::chrono::nanoseconds> (end - begin).count()) / lookupSize << ",LOOK,\n";
                            }

                        }

                        //printf("Delete CC Vars\n");
#ifdef GPUCODE
                        gpuErrchk(cudaFree(cc));
                        gpuErrchk(cudaFree(failFlag));
#else
                        delete cc;
                        delete failFlag;
#endif

                        //Init Cleary
#ifdef GPUCODE
                        Cleary* c;
                        gpuErrchk(cudaMallocManaged((void**)&c, sizeof(Cleary)));
                        new (c) Cleary(N, numThreads);
#else
                        Cleary* c = new Cleary(N, numThreads);
#endif

                        //Loop over intervals
                        for (int j = 0; j < INTERVAL + WARMUP; j++) {
                            std::chrono::steady_clock::time_point begin;
                            std::chrono::steady_clock::time_point end;

                            //Fill the table
                            if (j >= WARMUP) {
                                begin = std::chrono::steady_clock::now();
#ifdef GPUCODE

                                fillCleary << <1, numThreads >> > (setsize, vals, c, setsize * (j - WARMUP));
                                gpuErrchk(cudaPeekAtLastError());
                                gpuErrchk(cudaDeviceSynchronize());
#else

                                std::vector<std::thread> vecThread(numThreads);
                                //uint64_cu** valCopy = (uint64_cu**) malloc(sizeof(uint64_cu*) * numThreads);

                                for (int i = 0; i < numThreads; i++) {
                                    //valCopy[i] = (uint64_cu*) malloc(sizeof(uint64_cu) * size);
                                    //copyArray(vals, valCopy[i], size);
                                    vecThread.at(i) = std::thread(fillCleary, setsize, vals, c, setsize * (j - WARMUP), i, numThreads);
                                }

                                //Join Threads
                                for (int i = 0; i < numThreads; i++) {
                                    vecThread.at(i).join();
                                    //delete[] valCopy[i];
                                }
#endif
                                //End the timer
                                end = std::chrono::steady_clock::now();
                                myfile << N << "," << numThreads << "," << P << "," << D << "," << S << ",cle," << (j - WARMUP) << "," << (std::chrono::duration_cast<std::chrono::nanoseconds> (end - begin).count()) / setsize << ",INS,\n";
                            }

                            //Lookup
                            if (j >= WARMUP) {
                                begin = std::chrono::steady_clock::now();
#ifdef GPUCODE
                                lookupCleary << <1, std::pow(2, T) >> > (lookupSize, 0, setsize * (j - WARMUP + 1), vals, c);
                                gpuErrchk(cudaPeekAtLastError());
                                gpuErrchk(cudaDeviceSynchronize());
#else
                                std::vector<std::thread> vecThread(numThreads);
                                for (int i = 0; i < numThreads; i++) {
                                    //printf("Starting Threads\n");
                                    vecThread.at(i) = std::thread(lookupCleary, lookupSize, 0, setsize * (j - WARMUP + 1), vals, c, i, numThreads);
                                }

                                //Join Threads
                                for (int i = 0; i < numThreads; i++) {
                                    vecThread.at(i).join();
                                }
#endif
                                //End the timer
                                end = std::chrono::steady_clock::now();

                                myfile << N << "," << numThreads << "," << P << "," << D << "," << S << ",cle," << (j - WARMUP ) << "," << (std::chrono::duration_cast<std::chrono::nanoseconds> (end - begin).count()) / lookupSize << ",LOOK,\n";
                            }

                        }

#ifdef GPUCODE
                        gpuErrchk(cudaFree(c));
                        gpuErrchk(cudaFree(vals));
#else
                        delete c;
                        delete[] vals;
#endif
                    }
                }
            }
        }
    }


    myfile.close();
    printf("\nBenchmark Done\n");
}



void BenchmarkMaxOccupancy(int TABLE_START, int NUM_TABLES, int HASH_START, int NUM_HASHES, int HASH_STEP, int NUM_LOOPS, int LOOP_STEP, int NUM_REHASHES, int REHASH_STEP, int NUM_SAMPLES) {

    printf("=====================================================================\n");
    printf("                   Starting MAX Occupancy Benchmark                  \n");
    printf("=====================================================================\n");

    std::ofstream myfile;
    std::string specifier = "";
#ifdef GPUCODE
    specifier += "-GPU";
#else
    specifier += "-CPU";
#endif
#ifdef REHASH
    specifier += "-REHASH";
#endif

    std::string filename = "results/benchmax";
    if (HASH_START == 4 && NUM_HASHES == 1) {
        filename = "results/benchmax_4";
    }

    filename = filename + specifier + ".csv";


    myfile.open(filename);
    if (!myfile.is_open()) {
        printf("File Failed to Open\n");
        return;
    }
    printf("File Opened");

    myfile << "tablesize,hashes,loops,rehashes,samples,max\n";

    //MAX_LOOPS
    for (int N = TABLE_START; N < TABLE_START + NUM_TABLES; N++) {
        printf("Table Size:%i\n", N);
        int size = std::pow(2, N);
        for (int H = HASH_START; H < HASH_START + NUM_HASHES; H+=HASH_STEP) {
            printf("\tNum of Hashes:%i\n", H);
            for (int L = 0; L < NUM_LOOPS; L+=LOOP_STEP) {
                printf("\t\tNum of Loops:%i\n", L);
                for (int R = 0; R <= NUM_REHASHES; R+=REHASH_STEP) {
                    printf("\t\t\tNum of Rehashes:%i\n", R);
                    for (int S = 0; S < NUM_SAMPLES; S++) {
                        //printf("\t\t'tSample Number:%i\n", S);
                        uint64_cu* vals = generateRandomSet(size);

                        //Init Cleary Cuckoo
                        //printf("INit Table\n");
#ifdef GPUCODE
                        ClearyCuckoo* cc;
                        gpuErrchk(cudaMallocManaged((void**)&cc, sizeof(ClearyCuckoo)));
                        new (cc) ClearyCuckoo(N, H);
#else
                        ClearyCuckoo* cc = new ClearyCuckoo(N, H);
#endif
                        cc->setMaxLoops(L);
                        cc->setMaxRehashes(R);

                        //printf("INit Complete\n");
#ifdef GPUCODE
                        int* failFlag;
                        gpuErrchk(cudaMallocManaged(&failFlag, sizeof(int)));
                        failFlag[0] = false;

                        //Var to store num of inserted values
                        addtype* occ;
                        gpuErrchk(cudaMallocManaged(&occ, sizeof(addtype)));
                        occ[0] = 0;

                        fillClearyCuckoo << <1, 1 >> > (size, vals, cc, occ, failFlag);
                        gpuErrchk(cudaPeekAtLastError());
                        gpuErrchk(cudaDeviceSynchronize());

                        myfile << N << "," << H << "," << L << "," << R << "," << S << "," << occ[0] << ",\n";
#else
                        std::atomic<bool> failFlag(false);
                        std::atomic<addtype> occ(0);
                        //printf("Filling Table\n");
                        SpinBarrier barrier(1);

                        fillClearyCuckoo(size, vals, cc, &barrier, &occ, &failFlag);
                        //printf("Writing\n");
                        myfile << N << "," << H << "," << L << "," << R << "," << S << "," << occ.load() << ",\n";
#endif


#ifdef GPUCODE

                        gpuErrchk(cudaFree(failFlag));
                        gpuErrchk(cudaFree(cc));
                        gpuErrchk(cudaFree(occ));
                        gpuErrchk(cudaFree(vals));
#else
                        //printf("Deleting\n");
                        delete cc;
                        delete[] vals;
#endif
                        //printf("Done\n");
                    }
                }
            }
        }
    }

    myfile.close();

    printf("\n\nBenchmark Done\n");
}
