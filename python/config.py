# Configuration parameters for the pen plotter system

# Image dimensions and payload length
W, H = 170, 240
PAYLOAD_LEN = (W * H) // 8  # 5100 bytes

# FPGA communication settings
HEADER_FPGA = 0xAA
BITORDER = "big"

# Contour extraction settings
MIN_CONTOUR_LEN_PX = 2

# Physical conversion settings
PIXEL_TO_MM = 0.5
STEP_MM = 0.2

# File paths
RECEIVE_PATH = "./sample/test_image1.txt"
COMMAND_PATH = "./sample/out_commands.txt"