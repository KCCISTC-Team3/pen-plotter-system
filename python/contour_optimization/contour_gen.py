from typing import List
import numpy as np
import cv2

# Deprecated
# def extract_external_contours(img255: np.ndarray, min_len_px: int) -> List[np.ndarray]:
#     # Extract external contours only and return each contour as an (N, 2) array.
#     if img255.ndim != 2:
#         raise ValueError(f"Expected a single-channel image, got shape={img255.shape}")
#     if img255.dtype != np.uint8:
#         raise ValueError("img255 must be uint8 with values {0,255}.")

#     # OpenCV version compatibility: findContours may return (contours, hierarchy) or (image, contours, hierarchy)
#     result = cv2.findContours(img255.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
#     contours = result[0] if len(result) == 2 else result[1]

#     out: List[np.ndarray] = []
#     for c in contours:
#         c2 = c.reshape(-1, 2).astype(np.int32)  # (N,1,2) -> (N,2)
#         if len(c2) >= min_len_px:
#             out.append(c2)
#     return out

def extract_contours_all(
    img255: np.ndarray,
    min_len_px: int,
    method: int = cv2.CHAIN_APPROX_NONE,
    retrieval: int = cv2.RETR_LIST,
) -> List[np.ndarray]:
    # Extract all visible contours (not only external) and return each contour as an (N, 2) array.
    if img255.ndim != 2:
        raise ValueError(f"Expected a single-channel image, got shape={img255.shape}")
    if img255.dtype != np.uint8:
        raise ValueError("img255 must be uint8 with values {0,255}.")

    result = cv2.findContours(img255.copy(), retrieval, method)
    contours = result[0] if len(result) == 2 else result[1]

    out: List[np.ndarray] = []
    for c in contours:
        c2 = c.reshape(-1, 2).astype(np.int32)
        if len(c2) >= min_len_px:
            out.append(c2)
    return out


def draw_contours_overlay(img255: np.ndarray, contours_xy: List[np.ndarray]) -> np.ndarray:
    # Draw contours on a BGR copy for visualization.
    bgr = cv2.cvtColor(img255, cv2.COLOR_GRAY2BGR)
    cv_contours = [c.reshape(-1, 1, 2).astype(np.int32) for c in contours_xy]
    cv2.drawContours(bgr, cv_contours, contourIdx=-1, color=(0, 0, 255), thickness=1)
    return bgr