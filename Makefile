CUDA_PATH ?= /usr/local/cuda
NVCC      := $(CUDA_PATH)/bin/nvcc
CC        := g++

# Target GPU architectures (SASS): Turing (75), Ampere (86), Ada (89), Blackwell (120).
# sm_120 requires CUDA Toolkit 12.8 or newer.
SM_ARCHS  := 75 86 89 120
GENCODE   := $(foreach arch,$(SM_ARCHS),-gencode arch=compute_$(arch),code=sm_$(arch))

# Same optimization flags as cCUDA.
CXXFLAGS  := -std=c++17
NVCCFLAGS := -O3 -use_fast_math --ptxas-options=-O3 $(GENCODE) $(CXXFLAGS)
CCFLAGS   := -O3 $(CXXFLAGS) -pthread -I$(CUDA_PATH)/include
LDFLAGS   := -cudart=static -lpthread -lm

CPU_SRC := RCKangaroo.cpp GpuKang.cpp Ec.cpp utils.cpp
GPU_SRC := RCGpuCore.cu
HDRS    := $(wildcard *.h)

CPP_OBJECTS := $(CPU_SRC:.cpp=.o)
CU_OBJECTS  := $(GPU_SRC:.cu=.o)

TARGET := cCUDAKangaroo

.PHONY: all clean ptxinfo

all: $(TARGET)

$(TARGET): $(CPP_OBJECTS) $(CU_OBJECTS)
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.cpp $(HDRS)
	$(CC) $(CCFLAGS) -c $< -o $@

%.o: %.cu $(HDRS)
	$(NVCC) $(NVCCFLAGS) -c $< -o $@

# ---- Codegen inspection (no effect on the shipped binary), like cCUDA's ptxinfo target ----
# Verbose ptxas resource report -- registers/thread, spill stores/loads, stack frame -- for
# every kernel, printed once per target arch. All device kernels live in RCGpuCore.cu, so
# compiling just that TU with the shipped flags yields the same usage as the release build.
ptxinfo: $(GPU_SRC) $(HDRS)
	$(NVCC) $(NVCCFLAGS) -Xptxas -v -c $(GPU_SRC) -o RCGpuCore-ptxinfo.o
	@rm -f RCGpuCore-ptxinfo.o

clean:
	rm -f $(CPP_OBJECTS) $(CU_OBJECTS) $(TARGET) RCGpuCore-ptxinfo.o
