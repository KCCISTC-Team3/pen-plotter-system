# Configuration parameters for the pen plotter system

# Ports (For Testing, set your own serial port here)
FPGA_1_PORT = ''        ### << YOUR SERIAL PORT HERE >> ###
FPGA_2_PORT = ''        ### << YOUR SERIAL PORT HERE >> ###
STM32_PORT = ''         ### << YOUR SERIAL PORT HERE >> ###

BAUD = 115200           # Baud Rate (fixed)


# Image dimensions and payload length
W, H = 176, 240         # Image width and height in pixels (only for test script)
PAYLOAD_LEN = (W * H + 7) // 8  # Payload length in bytes, ceiling division

# FPGA communication settings
BITORDER = "big"    # try "little" if needed

# Contour extraction settings
MIN_CONTOUR_LEN_PX = 2  # Minimum contour length in pixels

# Physical conversion settings
PIXEL_TO_MM = 0.5   # 1 pixel = 0.5 mm
STEP_MM = 0.2       # for densification of contours
EPSILON_MM = 1    # for RDP simplification (0.03 ~ 0.15 recommended)

# File paths (For Testing standalone, set your own paths here)
# RECEIVE_PATH = "./sample/05_canny_packed_1bpp_hex.txt"   # Input hex text file path
RECEIVE_PATH = "./images/filter_0.mem"
# RECEIVE_PATH = "./sample/05_canny_pixels_hex.txt"   # Input hex text file path
COMMAND_PATH = "./sample/06_out_commands.txt"  # Output command file path

