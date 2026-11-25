"""
A class that demonstrates the use of a Least Recently Used algorithm for cache memory

It stores data using an array of size 10
It use a secondary array of the same size to track how recently each element was accessed or modified

Has three methods:
1. add
2. read
3. debug_print
"""

class LRU_Cache:
    def __init__(self):
        self.data = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1]    # -1 means that a value has not yet been assigned
        self.recency = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]   # 0 is default recency value
        return

    # adds a value to the internal array using LRU logic
    def add(self, val):
        # check for an existing hit first
        for i in range(len(self.data)):
            if self.data[i] == val:
                for j in range(len(self.data)):
                    if self.data[j] != -1:
                        self.recency[j] += 1
                self.recency[i] = 0
                return

        empty_flag = True
        for i in range(len(self.data)):
            if self.data[i] != -1:
                self.recency[i] += 1
                empty_flag = False

        # if the cache is completely empty
        if empty_flag:
            self.data[0] = val

        # if the cache has some values already assigned
        else:
            vacant_spaces = list()
            for i in range(len(self.data)):
                if self.data[i] == -1:
                    vacant_spaces.append(i)

            # if the cache still has unassigned slots
            if len(vacant_spaces) > 0:
                idx = min(vacant_spaces)
                self.data[idx] = val
                self.recency[idx] = 0

            # if the cache is comepletely full
            else:
                max_val = -1
                for i in range(len(self.recency)):
                    if self.recency[i] > max_val:
                        max_val = self.recency[i]

                for i in range(len(self.recency)):
                    if self.recency[i] == max_val:
                        self.recency[i] = 0
                        self.data[i] = val
        return                

    # gets a value from a specified location in the internal array
    def read(self, loc):
        if self.data[loc] == -1:
            return -1

        for i in range(len(self.data)):
            if self.data[i] != -1:
                self.recency[i] += 1
        
        self.recency[loc] = 0
        return self.data[loc]

    # debug print method
    def debug_print(self):
        print(self.data)
        print(self.recency)
        print()
        return 



if __name__ == "__main__":
    mem = LRU_Cache()
    mem.add(1)
    mem.add(5)
    mem.add(2)
    mem.add(9)
    mem.add(33)
    mem.debug_print()
    mem.add(17)
    mem.add(52)
    mem.add(19)
    mem.add(100)
    mem.add(12)
    mem.debug_print()
    mem.add(83)
    mem.add(75)
    mem.add(60)
    mem.add(55)
    mem.add(55)
    mem.debug_print()

