#include <time.h>

#ifndef RECORD_H
#define RECORD_H

#define VALUE_NOTHING 0
#define VALUE_UNKNOWN 1
#define VALUE_TEXT 2

typedef struct Value {
    int    type;  // 0 = nothing, 1 = unknown, 2 = text
    char*  text;  // text value
    time_t asof;  // time of value
    struct Value* prev;  // previous value
} Value;

typedef struct Record {
    char*  name;  // name of record
    struct Value*  value; // current value
    struct Record* overs; // links to records over this record
    struct Record* unders; // links to records under this record
} Record;

// Support Functions
Record* createRecord(const char* name);
int putRecordUnder(Record* subRecord, Record* superRecord);
void assignValue(Record* record, int type, const char* text);
void copySlice(Record* srcRecord, Record* destRecord, int startIndex, int endIndex);
void spliceValue(Record* destRecord, int index, int deleteCount, const char* insertText);

#endif // RECORD_H
