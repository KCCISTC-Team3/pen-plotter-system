# Configuration parameters for the pen plotter system

# Image dimensions and payload length
W, H = 172, 240
PAYLOAD_LEN = (W * H) // 8  # 5160 bytes

# FPGA communication settings
HEADER_FPGA = 0xAA  # header byte from FPGA
BITORDER = "big"    # try "little" if needed

# Contour extraction settings
MIN_CONTOUR_LEN_PX = 2  # Minimum contour length in pixels

# Physical conversion settings
PIXEL_TO_MM = 0.5   # 1 pixel = 0.5 mm
STEP_MM = 0.2       # for densification of contours
EPSILON_MM = 1    # for RDP simplification (0.03 ~ 0.15 recommended)

# File paths
RECEIVE_PATH = "./sample/test_image1.txt"   # Input hex text file path
COMMAND_PATH = "./sample/out_commands.txt"  # Output command file path