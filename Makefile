CC = gcc
CFLAGS = -Wall -Wextra

# Add any additional source files here
SRCS = main.c record.c

# Generate object file names from source file names
OBJS = $(SRCS:.c=.o)

# Specify the name of the executable
TARGET = record_test

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o $(TARGET)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)
