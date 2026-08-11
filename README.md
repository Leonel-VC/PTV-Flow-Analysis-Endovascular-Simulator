# PTV-Flow-Analysis-Endovascular-Simulator

This repository contains a MATLAB implementation of Particle Tracking Velocimetry (PTV) for analyzing fluid flow in an endovascular simulator. The system tracks tracer particles in high-speed video sequences to estimate velocity fields, enabling quantitative hemodynamic analysis in vascular models.

## Results Summary

### Validation

The system was validated against known reference flow rates:

| Reference Flow (mL/min) | Estimated Flow (mL/min) | Error |
|------|------|------|
| 775 | 853 | +10.1% |
| 1,700 | 1,764 | +3.8% |

## Key Features

- **Automated Particle Detection**: HSV color filtering with morphological cleaning
- **Robust Tracking**: Hungarian algorithm-based particle matching with displacement constraints
- **Flow Quantification**: Velocity field estimation and volumetric flow rate calculation
- **Interactive Calibration**: User-guided pixel-to-mm conversion and ROI selection
- **Comprehensive Visualization**: Vector fields and speed histograms
- **Video Output**: Animated velocity fields and particle masks

## Getting Started

### Prerequisites

- **MATLAB R2020a** or later
- Required toolboxes:
  - Image Processing Toolbox
  - Statistics and Machine Learning Toolbox

### Running the Pipeline

**Step 1: Place your video file in the project directory**

**Step 2: Update the configuration parameters in ```src/ptv_flow.m```**

**Step 3: Run the main script**
```matlab
ptv_flow();
```

## Configuration

Modify the following parameters in ```src/ptv_flow.m```

| Parameter | Description | Default Value |
|------|------|------|
| ```videoFile``` | Input video filename | ```'10V_slow.mp4'``` |
| ```tubeWidth``` | Tube diameter for flow calculation | ```10``` mm |
| ```dt``` | Frame rate of slow-motion recording | ```1 / 120``` s |
| ```minParticleArea``` | Minimum particle area (pixels) | ```8``` |
| ```minCircularity``` | Particle circularity threshold | ```0.7``` |
| ```maxDisplacement``` | Max displacement between frames | ```50``` pixels |

## Repository Structure

```
├── data/
│ ├── 10V_slow.mp4            # Slow Flow Video
| └── 16V_slow.mp4            # High Flow Video
├── results/                  # Results generated automatically
│ ├── 10V_Particle_Masks.mp4  # Animated video of detected particle masks
│ ├── 10V_Velocity_Field.mp4  # Animated velocity field visualization
│ ├── 10V_Vector_Field.png    # Complete velocity vector field visualization
│ ├── 10V_Speed_Histogram.png # Speed distribution histogram with velocity components for Slow Flow
│ └── 16V_Speed_Histogram.png # Speed distribution histogram with velocity components for High Flow
├── src/
│ └── ptv_flow.m              # Main PTV analysis script
└── README.md                 # This file
```

## Output Files
After running the pipeline, you'll find:

| File | Description |
|------|------|
| ``` Vector_Field.png ``` | Complete velocity vector field visualization |
| ``` Speed_Histogram.png ``` | Speed distribution histogram with velocity components |
| ``` Particle_Masks.mp4 ``` | Animated video of detected particle masks |
| ``` Velocity_Field.mp4 ``` | Animated velocity field visualization |

## Methodology

### 1. Video Preprocessing
- Convert frames to HSV color space
- Apply color thresholding for particle isolation
- Morphological operations for noise removal
- Circularity-based particle filtering

### 2. Particle Tracking
- Centroid detection using regionprops
- Cost matrix construction (Euclidean distances)
- Hungarian assignment algorithm for optimal matching
- Displacement thresholding for outlier rejection

### 3. Flow Calculation
- Pixel-to-mm conversion via user calibration
- ROI-based velocity extraction
- Volumetric flow rate calculation using cross-sectional area
- Statistical analysis of velocity components

## License

This project is licensed under the MIT License - see the LICENSE file for details.
