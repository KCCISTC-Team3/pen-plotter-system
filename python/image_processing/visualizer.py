from __future__ import annotations
from typing import List, Optional, Tuple
import numpy as np
import cv2


def _ensure_bgr(img255: np.ndarray) -> np.ndarray:
    # Ensure the image is BGR for colored drawing.
    if img255.ndim != 2:
        raise ValueError(f"Expected single-channel image, got shape={img255.shape}")
    if img255.dtype != np.uint8:
        img255 = img255.astype(np.uint8)
    return cv2.cvtColor(img255, cv2.COLOR_GRAY2BGR)


def draw_contours_and_penup_links(
    img255: np.ndarray,
    ordered_contours: List[np.ndarray],
    draw_contours: bool = True,
    draw_penup_links: bool = True,
    draw_index_labels: bool = True,
    thickness_contour: int = 1,
    thickness_link: int = 1,
    font_scale: float = 0.5,
    font_thickness: int = 1,
) -> np.ndarray:
    """
    Visualize greedy ordering:
      - Draw each contour polyline (red).
      - Draw pen-up travel links: end of contour i -> start of contour i+1 (green).
      - Draw contour index labels near each contour start point.

    Args:
        img255: Binary image in uint8 {0,255}.
        ordered_contours: List of (N,2) contours already reordered and direction-fixed.
    Returns:
        BGR overlay image.
    """
    out = _ensure_bgr(img255)
    if not ordered_contours:
        return out

    # Draw contour polylines
    if draw_contours:
        cv_contours = [c.reshape(-1, 1, 2).astype(np.int32) for c in ordered_contours]
        cv2.drawContours(out, cv_contours, contourIdx=-1, color=(0, 0, 255), thickness=thickness_contour)

    # Draw pen-up links and index labels
    for i, c in enumerate(ordered_contours, start=1):
        s = tuple(map(int, c[0]))   # start point
        e = tuple(map(int, c[-1]))  # end point

        if draw_index_labels:
            # Put the contour index label near the start point.
            # Offset to avoid covering the point itself.
            label_pos = (s[0] + 4, s[1] - 4)
            cv2.putText(
                out,
                str(i),
                label_pos,
                cv2.FONT_HERSHEY_SIMPLEX,
                font_scale,
                (255, 255, 0),   # light yellow/cyan-ish in BGR, easy to see
                font_thickness,
                cv2.LINE_AA,
            )

            # Optional: small dot at start and end for reference (can be removed if cluttered)
            cv2.circle(out, s, radius=1, color=(255, 0, 0), thickness=-1)
            cv2.circle(out, e, radius=1, color=(0, 255, 0), thickness=-1)

        if draw_penup_links and i < len(ordered_contours):
            n_start = tuple(map(int, ordered_contours[i][0]))  # next contour start (note: i is 1-based)
            cv2.line(out, e, n_start, color=(0, 255, 255), thickness=thickness_link, lineType=cv2.LINE_AA)

    return out


def print_contour_paths(
    ordered_contours: List[np.ndarray],
    max_points_per_contour: Optional[int] = 30,
    contour_name_prefix: str = "contour",
) -> None:
    """
    Print contour point sequences as:
      contour1: [x,y] -> [x,y] -> ...
    For large contours, prints only the first max_points_per_contour points by default.

    Args:
        max_points_per_contour:
            - None: print all points (can be huge).
            - int: print first N points and then show summary.
    """
    for i, c in enumerate(ordered_contours, start=1):
        n = len(c)
        if n == 0:
            print(f"{contour_name_prefix}{i}: (empty)")
            continue

        if max_points_per_contour is None or n <= max_points_per_contour:
            pts = c
            suffix = ""
        else:
            pts = c[:max_points_per_contour]
            suffix = f" -> ... (total {n} pts)"

        parts = [f"[{int(p[0])}, {int(p[1])}]" for p in pts]
        line = f"{contour_name_prefix}{i}: " + " -> ".join(parts) + suffix
        print(line)