# path/segment.py
from __future__ import annotations
from typing import Iterable
import numpy as np


def densify_polyline_mm(
    pts_mm: np.ndarray,
    step_mm: float = 0.2,
) -> np.ndarray:
    """
    Insert intermediate points so that distance between consecutive points <= step_mm.

    Args:
        pts_mm: (N,2) polyline points in millimeters
        step_mm: maximum allowed spacing in mm
    Returns:
        (M,2) densified polyline in mm
    """
    if pts_mm.ndim != 2 or pts_mm.shape[1] != 2:
        raise ValueError(f"pts_mm must be (N,2), got {pts_mm.shape}")
    if len(pts_mm) < 2:
        return pts_mm.copy()

    out = [pts_mm[0]]
    for i in range(len(pts_mm) - 1):
        p0 = pts_mm[i]
        p1 = pts_mm[i + 1]
        v = p1 - p0
        dist = float(np.hypot(v[0], v[1]))

        if dist <= step_mm or dist == 0.0:
            out.append(p1)
            continue

        # Number of segments needed so that each segment <= step_mm
        n_seg = int(np.ceil(dist / step_mm))
        # Insert intermediate points (excluding p0, including p1 at the end)
        for k in range(1, n_seg + 1):
            t = k / n_seg
            out.append(p0 + t * v)

    return np.vstack(out)


def contour_pixels_to_mm(
    contour_xy: np.ndarray,
    pixel_to_mm: float = 0.5,
    origin_xy: tuple[float, float] = (0.0, 0.0),
) -> np.ndarray:
    """
    Convert pixel coordinates to mm coordinates.
    origin_xy shifts the pixel coordinates before scaling if needed.

    Args:
        contour_xy: (N,2) pixel coords [x,y]
        pixel_to_mm: mm per pixel
        origin_xy: (ox, oy) pixel origin offset
    Returns:
        (N,2) mm coords
    """
    if contour_xy.ndim != 2 or contour_xy.shape[1] != 2:
        raise ValueError(f"contour_xy must be (N,2), got {contour_xy.shape}")

    pts = contour_xy.astype(np.float32)
    pts[:, 0] = (pts[:, 0] - float(origin_xy[0])) * float(pixel_to_mm)
    pts[:, 1] = (pts[:, 1] - float(origin_xy[1])) * float(pixel_to_mm)
    return pts
