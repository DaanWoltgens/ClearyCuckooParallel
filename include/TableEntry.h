#include <utility>
#include <iostream>
#include <bitset>

template <class ADD, class REM>
class TableEntry {

protected:
    uint64_t val;

    __host__ __device__
    void setBits(int start, int end, uint64_t ins) {
        uint64_t mask = ((((uint64_t)1) << end) - 1) ^ ((((uint64_t)1) << (start - 1)) - 1);
        uint64_t tempval = val & ~mask;      //Remove all of the bits currently in the positions
        ins = ins << (start - 1);   //Shift new val to correct position
        ins = ins & mask;       //Mask the new val to prevent overflow
        uint64_t newval = tempval | ins;        //Place the new val

        //In devices, atomically exchange
        #ifdef  __CUDA_ARCH__
        atomicExch(&val, newval);
        #else
        val = newval;
        #endif
    }

    __host__ __device__
    uint64_t getBits(int start, int end) {
        uint64_t res = val;
        uint64_t mask = ((((uint64_t)1) << end) - ((uint64_t)1)) ^ ((((uint64_t)1) << (start - 1)) - ((uint64_t)1));
        res = res & mask;
        res = res >> (start - 1);
        return res;
    }

    __host__ __device__
    int signed_to_unsigned(int n, int size) {
        int res = 0;
        if (n < 0) {
            res = 1 << size;
            res = res | (-n);
            return res;
        }
        res = res | n;
        return res;
    }

    __host__ __device__
    int unsigned_to_signed(unsigned n, int size)
    {
        uint64_t mask = ((((uint64_t)1) << size) - 1) ^ ((((uint64_t)1) << (1 - 1)) - 1);
        int res = n & mask;
        if (n >> size == 1) {
            res = -res;
        }
        return res;
    }

    __host__ __device__
    uint64_t getValue() {
        return val;
    }

    __host__ __device__
    void setValue(uint64_t x) {
        val = x;
    }

public:
    __host__ __device__
    TableEntry() {
        val = 0;
    }

    __host__ __device__
        TableEntry(uint64_t x) {
        val = x;
    }

    __host__ __device__
    void exchValue(TableEntry* x) {
        //Atomically set this value to the new one
        uint64_t old =  atomicExch(&val, x->getValue());
        //Return an entry with prev val
        x->setValue(old);
        return;
    }

    __host__ __device__
    void print() {
        std::cout << std::bitset<64>(val) << "\n";
    }

};