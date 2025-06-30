# Weight-Stationary Systolic Matrix Multiplication

This repository contains a small Verilog project developed for self-learning and skill enhancement during job hunting.

The implemented design is a **weight-stationary systolic array** architecture, which is commonly used to accelerate matrix multiplication in hardware. In this design, weights are kept stationary in the processing elements (PEs), enabling efficient reuse and reducing memory access overhead—especially beneficial when the weights are fixed, such as in AI model inference.

### Features
- **Weight-Stationary Dataflow**: Optimized for low-cost weight reuse.
- **Soft-IP Style Design**: The number of processing elements (mesh size) is configurable via parameters.
- **Square Matrix Multiplication**: Currently supports multiplication of two square matrices of equal size.

### Usage
This project is intended for educational purposes, and as a demonstration of systolic architecture and parameterized Verilog design.
