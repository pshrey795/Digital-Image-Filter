Digital Image Filter
===

The exact specifications of the image filter can be found in the [problem statement](https://github.com/pshrey795/Digital-Image-Filter/blob/main/Statement.pdf).

* Contains VHDL code for a digital image filter, in **filter.vhdl**.
* Some features of this image filter are:
 1. Uses RAM for the user image input, while the matrix(3*3) for filtering is stored in ROM.
 2. The final pixel value is calculated using a MAC(multiplier-accumulator).
 3. Supports two different types of filtering: smoothening and sharpening.
* For more details regarding the features or functioning of the filter, refer the detailed comments in the code or the [user manual](https://github.com/pshrey795/Digital-Image-Filter/blob/main/Manual/UserManual.pdf).
* For detailed understanding of the algorithm/procedure used for filtering, refer the [ASM chart](https://github.com/pshrey795/Digital-Image-Filter/blob/main/Manual/ASMChart.pdf).