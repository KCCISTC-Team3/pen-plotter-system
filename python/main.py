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
    # raw_bytes = load_hex_txt_to_bytes("./contour_optimization/binary_dump_test.txt")
    raw_bytes = load_hex_txt_to_bytes("./contour_optimization/binary_dump_test_complex.txt")

    ## Payload extraction after 0xAA
    payload = extract_payload_after_header(raw_bytes, header=0xAA, payload_len=PAYLOAD_LEN)

    img255 = to_img255(unpack_payload_to_image(payload, w=W, h=H, bitorder=BITORDER))  # try "little" if needed


    ## Contour extraction and visualization
    contours = extract_contours_all(img255, min_len_px=MIN_CONTOUR_LEN_PX, retrieval=cv2.RETR_LIST)

    # # Print contour statistics
    # lengths = [len(c) for c in contours]
    # print(f"Contours kept: {len(contours)}")
    # if lengths:
    #     print(f"Length min/mean/max: {min(lengths)}/{sum(lengths)/len(lengths):.1f}/{max(lengths)}")
    #     print(f"Contour: {contours[0].shape}")
        # np.savetxt("contour0.txt", contours[0], fmt="%d")
    #     print(f"Contour: {contours[0]}")


    ## Contour optimization (greedy reorder)
    ordered_contours, penup_px = greedy_reorder_contours(
                contours,
                start_point=np.array([0, 0], dtype=np.int32) # origin at (0,0)
    )

    # Print per-contour path (default: first 30 points)
    # print_contour_paths(ordered_contours, max_points_per_contour=30)

    # Print summary statistics
    lengths = [len(c) for c in ordered_contours]
    if lengths:
        print("="*20 + " Summary " + "="*20)
        print(f"Contours kept: {len(ordered_contours)}")
        print(f"Length min/mean/max: {min(lengths)}/{sum(lengths)/len(lengths):.1f}/{max(lengths)}")
        print(f"Greedy pen-up distance (px): {penup_px:.2f}")
        before = total_penup_distance(contours)
        print(f"Pen-up distance before optimization (px): {before:.2f}")
        print(f"Pen-up distance after optimization (px): {penup_px:.2f}")
        print("="*50)


    ## Command generation


    # 1) Convert each contour to mm and densify
    contours_mm = []
    for c_xy in ordered_contours:
        c_mm = contour_pixels_to_mm(c_xy, pixel_to_mm=PIXEL_TO_MM, origin_xy=(0.0, 0.0))
        c_mm_dense = densify_polyline_mm(c_mm, step_mm=STEP_MM)
        contours_mm.append(c_mm_dense)

    # 2) Build commands with pen up/down
    cmds = build_command_sequence_from_contours_mm(contours_mm, pen_up_z=1, pen_down_z=0)

    print("Total commands:", len(cmds))
    print("First 50 commands:")
    for line in cmds[:50]:
        print(line.strip())

    # Optional: save for inspection
    with open("commands.txt", "w", encoding="utf-8") as f:
        f.writelines(cmds)
        
    ## Visualization: original binary, overlay, optimized with pen-up links
    binary_bgr = cv2.cvtColor(img255, cv2.COLOR_GRAY2BGR)   # original binary image in BGR
    overlay = draw_contours_overlay(img255, contours)       # overlay with contours drawn in red
    overlay_optimized = draw_contours_and_penup_links(
        img255,
        ordered_contours,
        draw_contours=True,
        draw_penup_links=True,
        draw_index_labels=True,
        font_scale=0.3,
        font_thickness=1,
    )

    combined = np.hstack([binary_bgr, overlay, overlay_optimized])
    
    cv2.namedWindow("Original | Overlay | Optimized", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("Original | Overlay | Optimized", 1400, 700)
    cv2.imshow("Original | Overlay | Optimized", combined)
    cv2.waitKey(0)
    cv2.destroyAllWindows()



if __name__ == "__main__":
    main()


