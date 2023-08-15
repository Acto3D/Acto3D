# *Acto3D* - 3D viewer for multichannel fluorocence images
This repository contains the complete source code and compiled binaries in the paper:
- Naoki Takeshita, Kenta Yashiro et al.  
[***Acto3D: a novel user- and budget-friendly software for multichannel three-dimensional imaging with high-resolution***](http://www....)  
Paper info  

Please [cite the paper](#how-to-cite) if you are using this software or code in your research.  

## Overview
Acto3D is a software that enables researchers to easily display and observe multi-channel images taken with a fluorescent microscope in 3D with very simple operations. You can adjust the color tone and opacity in detail for each channel, enabling advanced 3D displays. It is also possible to create sections from any angle and set animations. *Furthermore, for expert users, it is possible to apply any transfer function by changing the transfer function in the [template shader files](https://github.com/Acto3D/Acto3D/tree/main/ShaderTemplates)*.

***Limitations***  
According to the original paper, Acto3D is designed to expand entire images into a contiguous memory region that can be accessed from the GPU.
- A memory capacity sufficient to unfold all image data in memory is required.
- Acto3D is currently an application for Mac, and we recommend using a Mac equipped with Apple silicon.
- The dimensions in X, Y, Z must be less than or equal to 2048 pixels.
- The number of fluorescent channels is limited to 4.

## Turtorial
Acto3D recommends the use of multi-page TIFF files created by Fiji. While it's possible to create 3D from sequential image files with typical image formats, following the procedure below ensures that the XYZ resolution is set correctly. Therefore, create multi-page TIFF files from original format in accordance with the following steps.
#### Compatible formats
|                                     | 16 bits / sample        | 8 bits / sample                                                           |
| ----------------------------------- | ----------------------- | ------------------------------------------------------------------------- |
| Multipage TIFF<br>converted by FIJI | 1 - 4 channels          | 1 - 4 channels                                                            |
| TIFF stacks                         | 16 bits Grayscale image | 32 bits RGBA images (*)<br>24 bits RGB images<br>8 bits Gray scale images |
| PNG stacks                          |                         | 32 bits RGBA images (*)<br>24 bits RGB images<br>8 bits Gray scale images |
| JPG stacks                          |                         | 32 bits RGBA images (*)<br>24 bits RGB images<br>8 bits Gray scale images |

(*): Normally, the "A" in a 32-bit image refers to the opacity channel, but in Acto3D, the "A" can be used as the data for the fourth channel by storing the data of each fluorescent channel in R, G, B, and A.

#### Creation of multipage TIFF by FIJI
The following method has been confirmed to work with Fiji (version 2.3.0 / 1.53s):
1. Load into Fiji: Drag and drop the microscope image file into Fiji.
2. Configure Import Options:  
Color mode: Grayscale  
Virtual stack: On (either is acceptable if sufficient memory is available)  
Split channel: Off
3. Optional: Adjust the image range width.
4. Output to TIFF: Click **File** > **Save As** > **Tiff...**.

### Create 3D image in Acto3D
1. To load images, in Acto3D, click **Open images** > **Open ImageJ / Fiji TIFF** and select the file.
2. Optional: to adjust display ranges, XYZ resolution and limit channels, click **Image options**.
3. To create 3D image, click **View in 3D**.  

Please refer [this file](./aaa,pdf) for further instructions.   


## How to cite
RIS
```ris
@article{RN,
   author = {},
   title = {},
   journal = {},
   pages = {},
   abstract = {},
   DOI = {},
   url = {},
   year = {2023},
   type = {Journal Article}
}
```

EndNote

BibTeX
```bibtex
@article{RN,
   author = {},
   title = {},
   journal = {},
   pages = {},
   abstract = {},
   DOI = {},
   url = {},
   year = {2023},
   type = {Journal Article}
}
```
