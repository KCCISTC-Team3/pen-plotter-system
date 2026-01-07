import numpy as np
import cv2

from config import *
from contour_optimization import *
from imaging import *
# from gui import *
from io_utils import *
from packet_gen import *



def main():
    ## Load raw bytes from hex text file (test only)
    raw_bytes = load_hex_txt_to_bytes("./contour_optimization/binary_dump_test.txt")

    ## Payload extraction after 0xAA
    payload = extract_payload_after_header(raw_bytes, header=0xAA, payload_len=PAYLOAD_LEN)

    img255 = to_img255(unpack_payload_to_image(payload, w=W, h=H, bitorder=BITORDER))  # try "little" if needed


    ## Contour extraction and visualization
    contours = extract_contours_all(img255, min_len_px=MIN_CONTOUR_LEN_PX, retrieval=cv2.RETR_LIST)

    # Print contour statistics
    lengths = [len(c) for c in contours]
    print(f"Contours kept: {len(contours)}")
    if lengths:
        print(f"Length min/mean/max: {min(lengths)}/{sum(lengths)/len(lengths):.1f}/{max(lengths)}")
        print(f"Contour: {contours[0].shape}")
        # np.savetxt("contour0.txt", contours[0], fmt="%d")
        print(f"Contour: {contours[0]}")

    binary_bgr = cv2.cvtColor(img255, cv2.COLOR_GRAY2BGR)   # original binary image in BGR
    overlay = draw_contours_overlay(img255, contours)       # overlay with contours drawn in red

    both = np.hstack([binary_bgr, overlay])
    cv2.imshow("Binary | Overlay", both)
    cv2.waitKey(0)
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()


