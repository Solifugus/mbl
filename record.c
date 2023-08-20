#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "record.h"

// Function to create a new Record
Record* createRecord(const char* name) {
    // Allocate memory for the new Record
    Record* newRecord = (Record*)malloc(sizeof(Record));

    if (newRecord == NULL) {
        fprintf(stderr, "Failed to allocate memory for Record\n");
        return NULL;
    }

    // Allocate memory for the name and copy it
    newRecord->name = (char*)malloc(strlen(name) + 1);
    
    if (newRecord->name == NULL) {
        fprintf(stderr, "Failed to allocate memory for Record name\n");
        free(newRecord);
        return NULL;
    }

    strcpy(newRecord->name, name);

    // Initialize other fields
    newRecord->value = NULL;
    newRecord->overs = NULL;
    newRecord->unders = NULL;

    return newRecord;
}

// Function to put a subRecord under a superRecord
int putRecordUnder(Record* subRecord, Record* superRecord) {
    if (subRecord == NULL || superRecord == NULL) {
        fprintf(stderr, "Invalid subRecord or superRecord\n");
        return 0; // Return 0 to indicate failure
    }

    // Add subRecord to the unders of superRecord
    subRecord->unders = superRecord->unders; // Preserve existing unders
    superRecord->unders = subRecord; // Add subRecord under superRecord

    // Set the overs of subRecord to superRecord
    subRecord->overs = superRecord;

    return 1; // Return 1 to indicate success
}

// Function to assign a value to a record
void assignValue(Record* record, int type, const char* text) {
    // Check if the record or text is NULL
    if (record == NULL || text == NULL) {
        fprintf(stderr, "Error: Invalid record or text.\n");
        return;
    }

    // Check if the value is different from the last one
    if (record->value == NULL || record->value->type != type || strcmp(record->value->text, text) != 0) {
        // Create a new value
        Value* newValue = (Value*)malloc(sizeof(Value));
        if (newValue == NULL) {
            fprintf(stderr, "Error: Memory allocation failed.\n");
            exit(EXIT_FAILURE); // Handle memory allocation failure
        }

        // Assign the new value
        newValue->type = type;
        newValue->text = strdup(text); // Make a copy of the text
        newValue->asof = time(NULL);
        newValue->prev = record->value;

        // Update the record's value
        record->value = newValue;
    }
}

// Function to copy a slice of a record's value to another record
void copySlice(Record* srcRecord, Record* destRecord, int startIndex, int endIndex) {
    // Check if the records or indices are valid
    if (srcRecord == NULL || destRecord == NULL || startIndex < 0 || endIndex < startIndex) {
        fprintf(stderr, "Error: Invalid records or indices.\n");
        return;
    }

    // Ensure that the source record has a value
    if (srcRecord->value == NULL) {
        fprintf(stderr, "Error: Source record does not have a value.\n");
        return;
    }

    // Get the length of the source text
    int textLength = strlen(srcRecord->value->text);

    // Check if the indices are within bounds
    if (startIndex >= textLength || endIndex >= textLength) {
        fprintf(stderr, "Error: Slice indices out of bounds.\n");
        return;
    }

    // Calculate the length of the slice
    int sliceLength = endIndex - startIndex + 1;

    // Allocate memory for the slice text
    char* sliceText = (char*)malloc((sliceLength + 1) * sizeof(char)); // +1 for the null terminator
    if (sliceText == NULL) {
        fprintf(stderr, "Error: Memory allocation failed.\n");
        exit(EXIT_FAILURE); // Handle memory allocation failure
    }

    // Copy the slice from the source text
    strncpy(sliceText, srcRecord->value->text + startIndex, sliceLength);
    sliceText[sliceLength] = '\0'; // Null-terminate the slice text

    // Assign the slice text to the destination record's value
    assignValue(destRecord, VALUE_TEXT, sliceText);

    // Free the allocated slice text
    free(sliceText);
}

// Function to splice a value into a record
void spliceValue(Record* destRecord, int index, int deleteCount, const char* insertText) {
    int destLength = strlen(destRecord->value->text);
    int insertLength = strlen(insertText);

    // Calculate the new length of the destination text
    int newLength = destLength - deleteCount + insertLength;

    // Allocate memory for the new text
    char* newText = (char*)malloc((newLength + 1) * sizeof(char)); // +1 for the null terminator
    if (newText == NULL) {
        fprintf(stderr, "Error: Memory allocation failed.\n");
        exit(EXIT_FAILURE); // Handle memory allocation failure
    }

    // Copy the portion of the destination text before the splice index
    strncpy(newText, destRecord->value->text, index);

    // Copy the insert text
    strncpy(newText + index, insertText, insertLength);

    // Copy the portion of the destination text after the splice index (with deletion)
    strcpy(newText + index + insertLength, destRecord->value->text + index + deleteCount);

    // Null-terminate the new text
    newText[newLength] = '\0';

    // Assign the new text to the destination record's value
    assignValue(destRecord, VALUE_TEXT, newText);

    // Free the allocated new text
    free(newText);
}
