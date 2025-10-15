CC = gcc
CFLAGS = -Wall -Wextra -std=gnu99
LDFLAGS = 

# Source files
SRCS = main.c chunk.c memory.c debug.c value.c vm.c scanner.c compiler.c object.c table.c 

# Object files
OBJS = $(SRCS:.c=.o)

# Output executable name
TARGET = app

# Default rule
all: $(TARGET)

# Link object files into the final executable
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

# Compile each .c into a .o
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Clean up build files
clean:
	rm -f $(OBJS) $(TARGET) $(TARGET).exe