# Include configuration file
include conf.mk

# Define target-specific directories and files
TARGET := bootloader
TARGET_DIR := boot
BUILD_DIR := build
TARGET_BIN := $(BUILD_DIR)/$(TARGET).bin
TARGET_IMG := $(BUILD_DIR)/$(TARGET).img
TARGET_ELF := $(BUILD_DIR)/$(TARGET).elf
TARGET_O := $(BUILD_DIR)/$(TARGET).o

# Architecture-specific settings
ifeq ($(ARCH), x86)
    ifeq ($(TYPE), legacy)
        # Source directories
        SRC_DIR := $(ARCH)/$(TYPE)/src
        # Tools
        ASM := nasm
        CC := clang
        LINKER := ld
        VM := qemu-system-i386
        # I/O Formats
        CC_ARCH := i386
        CC_TARGET := i386-unknown-none
        ELF_ARCH := elf_i386
        ASM_OUTPUT := elf32
        ENTRY_POINT := 0x7c00
    else ifeq ($(TYPE), uefi)
       SRC_DIR := $(ARCH)/$(TYPE)/src
    endif
endif

# Stage-specific directories and source files
STAGE1_NAME := stage1
STAGE1_DIR := $(SRC_DIR)/stage1
STAGE1_SRC := $(STAGE1_DIR)/boot.asm
STAGE1_BIN := $(BUILD_DIR)/$(STAGE1_NAME).bin
STAGE1_ASM_O := $(STAGE1_DIR)/$(BUILD_DIR)/boot.o
STAGE1_DEBUG_O := $(STAGE1_DIR)/$(BUILD_DIR)/boot.debug.o

STAGE2_NAME := stage2
STAGE2_DIR := $(SRC_DIR)/stage2
STAGE2_C_SRCS := $(wildcard $(STAGE2_DIR)/*.c)
STAGE2_ASM_SRCS := $(wildcard $(STAGE2_DIR)/*.asm)
STAGE2_BIN := $(BUILD_DIR)/$(STAGE2_NAME).bin
STAGE2_C_O := $(patsubst $(STAGE2_DIR)/%.c, $(STAGE2_DIR)/$(BUILD_DIR)/%.o, $(STAGE2_C_SRCS))
STAGE2_DEBUG_C_O := $(patsubst $(STAGE2_DIR)/%.c, $(STAGE2_DIR)/$(BUILD_DIR)/%.debug.o, $(STAGE2_C_SRCS))
STAGE2_ASM_O := $(patsubst $(STAGE2_DIR)/%.asm, $(STAGE2_DIR)/$(BUILD_DIR)/%.o, $(STAGE2_ASM_SRCS))
STAGE2_DEBUG_ASM_O := $(patsubst $(STAGE2_DIR)/%.asm, $(STAGE2_DIR)/$(BUILD_DIR)/%.debug.o, $(STAGE2_ASM_SRCS))

# Compilation flags
LD_FLAGS := -Ttext $(ENTRY_POINT) -m $(ELF_ARCH) --oformat binary
LD_DEBUG_FLAGS := -Ttext $(ENTRY_POINT) -m $(ELF_ARCH)

# QEMU run flags
VM_FLAGS := -drive format=raw,file=$(TARGET_IMG),if=ide,bus=0,unit=0,media=disk -net none
VM_DEBUG_FLAGS := -s -S $(VM_FLAGS)

# Phony targets
.PHONY: all debug clean stages stages_debug run

# Silent
.SILENT: all

# Default target to build the bootloader binary
all: stages $(TARGET_IMG)

# Rule to produce the final file (.img)
$(TARGET_IMG): $(TARGET_BIN)
# Create build directory
	@mkdir -p $(BUILD_DIR)
# Create target image file
	@dd if=/dev/zero of=$(TARGET_IMG) bs=512 count=2880
# TODO: Make fs
# mkfs.fat -F 16 -n "os" $(TARGET_IMG)
# Write bootloader to disk image
	@dd if=$(TARGET_BIN) of=$(TARGET_IMG) bs=512 conv=notrunc
# Write kernel to disk image
# TODO: Make kernel
# Create target directory
	@mkdir -p $(TARGET_DIR)
# Copy image to target directory
	@cp $(TARGET_IMG) $(TARGET_DIR)/os.img

# Rule to produce .bin file
$(TARGET_BIN): $(STAGE1_ASM_O) $(STAGE2_C_O) $(STAGE2_ASM_O)
# Create build directory
	@mkdir -p $(BUILD_DIR)
# Link object files to create binary
	@$(LINKER) $(LD_FLAGS) -o $@ $^

# Debug target to build the ELF file for debugging
debug: stages_debug $(TARGET_ELF)

# Rule to build the ELF file for debugging
$(TARGET_ELF): $(STAGE1_DEBUG_O) $(STAGE2_DEBUG_C_O) $(STAGE2_DEBUG_ASM_O)
# Create build directory
	@mkdir -p $(BUILD_DIR)
# Link object files to create ELF
	@$(LINKER) $(LD_DEBUG_FLAGS) -o $@ $^

# Clean up the build directory
clean:
# Remove build directory
	@rm -rf $(BUILD_DIR)
# Clean up the build sub-directories
	@$(MAKE) -C $(STAGE1_DIR) clean
	@$(MAKE) -C $(STAGE2_DIR) clean

# Run the bootloader in QEMU
run: $(TARGET_BIN)
	if [ $(DEBUG) = true ]; then \
		$(VM) $(VM_DEBUG_FLAGS); \
	elif [ $(DEBUG) = false ]; then \
		$(VM) $(VM_FLAGS); \
	else \
		echo "Invalid DEBUG value: $(DEBUG)"; \
		echo "Try DEBUG=true or DEBUG=false"; \
	fi

# Build the bootloader stages
stages:
	@$(MAKE) -j 8 -C $(STAGE1_DIR)
	@$(MAKE) -j 8 -C $(STAGE2_DIR)

# Build the bootloader stages in debug mode
stages_debug:
	@$(MAKE) -C $(STAGE1_DIR) debug
	@$(MAKE) -C $(STAGE2_DIR) debug

