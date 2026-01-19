import numpy as np
import cv2

from config import RECEIVE_PATH, COMMAND_PATH, BITORDER, MIN_CONTOUR_LEN_PX, PIXEL_TO_MM, STEP_MM, EPSILON_MM, CROP_TOP, CROP_LEFT
from image_processing import *
from io_utils import *


def run_pipeline(w, h, receive_path=RECEIVE_PATH, command_path=COMMAND_PATH, data_format="1bpp", show_visualization=True):
    """
    Run the path optimization pipeline.
    
    Args:
        w: Image width
        h: Image height
        receive_path: Path to the hex text file with received data
        command_path: Path to save the output commands
        data_format: "1bpp" (packed 1 bit per pixel) or "byte_per_pixel" (1 byte per pixel, for camera data)
    """
    ## 1. FPGA -> PC: Load filtered image from hex text file and extract contours
    # Load raw bytes from hex text file
    raw_bytes = load_hex_txt_to_bytes(receive_path)

    # Convert bytes to image based on data format
    if data_format == "byte_per_pixel":
        # Camera mode: 1 byte per pixel (W*H bytes total)
        payload = extract_payload_after_header(raw_bytes, payload_len=w * h)
        # Convert bytes directly to image (0-255 values, assuming 0=black, 255=white or inverted)
        img255 = np.frombuffer(payload, dtype=np.uint8).reshape((h, w))
        # Ensure binary (0 or 255) - threshold at 127
        img255 = np.where(img255 > 127, 255, 0).astype(np.uint8)
    else:
        # Default: 1bpp packed format
        payload = extract_payload_after_header(raw_bytes, payload_len=(w * h + 7) // 8)
        img255 = to_img255(unpack_payload_to_image(payload, w, h, bitorder=BITORDER))

    # Crop image to remove noise (top rows and left columns)
    if CROP_TOP > 0 or CROP_LEFT > 0:
        img255 = img255[CROP_TOP:, CROP_LEFT:]
        # Update dimensions for subsequent processing
        w = w - CROP_LEFT
        h = h - CROP_TOP
        print(f"Image cropped: removed {CROP_TOP} rows from top, {CROP_LEFT} columns from left. New size: {w}x{h}")

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
        # c_mm_dense = densify_polyline_mm(c_simple, step_mm=STEP_MM)
        # contours_converted.append(c_simple)
        contours_converted.append(c_simple)
    # print(contours_converted)

    # 2) Build commands with pen up/down
    cmds = build_command_sequence_from_contours_xy(contours_converted, pen_up_z=1, pen_down_z=0)


    # Save STM commands
    with open(command_path, "w", encoding="utf-8") as f:
        f.writelines(cmds)


    ## Print summary statistics
    lengths = [len(c) for c in ordered_contours]
    if lengths:
        print()
        print("="*20 + " Summary " + "="*20)
        print(f"Contours kept: {len(contours)}")
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
        print("="*50)

        print("Total STM commands:", len(cmds))
        print("="*50)
        print("First 50 commands:")
        for line in cmds[:50]:
            print(line.strip())

    ## Visualization: original binary, overlay, optimized with pen-up links (optional)
    if show_visualization:
        binary_bgr = cv2.cvtColor(img255, cv2.COLOR_GRAY2BGR)   # original binary image in BGR
        overlay = draw_contours_overlay(img255, contours)       # overlay with contours drawn in red
        overlay_optimized = draw_contours_and_penup_links(
            img255,
            ordered_contours,
            draw_contours=True,
            draw_penup_links=True,
            draw_index_labels=True,
            font_scale=0.5,
            font_thickness=0,
        )

        combined = np.hstack([binary_bgr, overlay, overlay_optimized])
        
        cv2.namedWindow("Original | Overlay | Optimized", cv2.WINDOW_NORMAL)
        cv2.resizeWindow("Original | Overlay | Optimized", 1400, 700)
        cv2.imshow("Original | Overlay | Optimized", combined)
        # 창을 띄운 상태로 바로 반환 (waitKey 제거하여 창을 닫지 않고 계속 진행)
        cv2.waitKey(1)  # 1ms 대기로 창 업데이트만 수행



if __name__ == "__main__":
    run_pipeline()


