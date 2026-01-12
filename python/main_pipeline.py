import numpy as np
import cv2

from config import *
from image_processing import *
from io_utils import *


def run_pipeline(receive_path=RECEIVE_PATH, command_path=COMMAND_PATH):
    ## 1. FPGA -> PC: Load filtered image from hex text file and extract contours
    # Load raw bytes from hex text file w/ 0xAA (test only)
    raw_bytes = load_hex_txt_to_bytes(receive_path)

    # Payload extraction
    payload = extract_payload_after_header(raw_bytes, payload_len=PAYLOAD_LEN)
    img255 = to_img255(unpack_payload_to_image(payload, w=W, h=H, bitorder=BITORDER))

    # Contour extraction
    contours = extract_contours_all(img255, min_len_px=MIN_CONTOUR_LEN_PX, retrieval=cv2.RETR_LIST)

    # Print contour statistics

    ## Contour optimization (greedy reorder)
    ordered_contours, penup_px = greedy_reorder_contours(
                contours,
                start_point=np.array([0, 0], dtype=np.int32)    # origin at (0,0)
    )

    # Print per-contour path for test (default: first 30 points)
    # Example output:
    # contour1: [8, 7] -> [7, 8] -> [7, 9] -> [7, 10] -> [7, 11] -> ... (total 202 pts)
    # contour2: [9, 10] -> [10, 9] -> [11, 9] -> [12, 9] -> [13, 9] -> ... (total 186 pts)
    # ...
    # print_contour_paths(ordered_contours, max_points_per_contour=5)



    ## Command generation
    # 1) Convert each contour to mm and densify and simplify
    contours_converted = []
    for c_xy in ordered_contours:
        # Convert to mm
        c_mm = contour_pixels_to_mm(c_xy, pixel_to_mm=PIXEL_TO_MM, origin_xy=(0.0, 0.0))

        # Compress straight-ish parts while keeping curve shape within epsilon
        c_simple = rdp_simplify(c_mm, epsilon=EPSILON_MM)

        # Densify so that consecutive points <= STEP_MM
        c_mm_dense = densify_polyline_mm(c_simple, step_mm=STEP_MM)
        # contours_converted.append(c_simple)
        contours_converted.append(c_mm_dense)
    # print(contours_converted)

    # 2) Build commands with pen up/down
    cmds = build_command_sequence_from_contours_xy(contours_converted, pen_up_z=1, pen_down_z=0)

    print("Total commands:", len(cmds))
    print("First 50 commands:")
    for line in cmds[:50]:
        print(line.strip())

    # Save STM commands
    with open(command_path, "w", encoding="utf-8") as f:
        f.writelines(cmds)


    ## Print summary statistics
    lengths = [len(c) for c in ordered_contours]
    if lengths:
        print("="*20 + " Summary " + "="*20)
        print(f"Contours kept: {len(contours)}")
        print(f"Ordered Contours kept: {len(ordered_contours)}")

        # Print pen-up distance before/after optimization
        before = total_penup_distance(contours)
        print(f"Pen-up distance before optimization (px): {before:.2f}")
        print(f"Pen-up distance after optimization (px): {penup_px:.2f}")
        print("="*50)

        # Print point count before/after RDP optimization
        before_pts = count_points([densify_polyline_mm(contour_pixels_to_mm(c, 0.5), 0.2) for c in ordered_contours])
        after_pts = count_points(contours_converted)

        print("points before simplify:", before_pts)
        print("points after  simplify:", after_pts)
        print("reduction:", (1 - after_pts / max(1, before_pts)) * 100, "%")

        
    ## Visualization: original binary, overlay, optimized with pen-up links
    binary_bgr = cv2.cvtColor(img255, cv2.COLOR_GRAY2BGR)   # original binary image in BGR
    overlay = draw_contours_overlay(img255, contours)       # overlay with contours drawn in red
    overlay_optimized = draw_contours_and_penup_links(
        img255,
        ordered_contours,
        draw_contours=True,
        draw_penup_links=True,
        draw_index_labels=False,
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
    run_pipeline()


