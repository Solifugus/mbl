#include <stdio.h>
#include "record.h"

int main() {
    // Create some sample records
    Record* record1 = createRecord("Record1");
    Record* record2 = createRecord("Record2");
    putRecordUnder(record2, record1);

    // Print the structure
    printf("Record1\n");
    printf("  |_ %s\n", record1->unders->name);
    return 0;
}
