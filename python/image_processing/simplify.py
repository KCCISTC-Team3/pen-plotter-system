from __future__ import annotations
import numpy as np


def _perp_dist_point_to_segment(p: np.ndarray, a: np.ndarray, b: np.ndarray) -> float:
    # Compute perpendicular distance from point p to segment ab (in 2D).
    ab = b - a
    ap = p - a
    denom = float(np.dot(ab, ab))
    if denom == 0.0:
        return float(np.hypot(ap[0], ap[1]))

    t = float(np.dot(ap, ab) / denom)
    t = max(0.0, min(1.0, t))
    proj = a + t * ab
    d = p - proj
    return float(np.hypot(d[0], d[1]))


def rdp_simplify(poly: np.ndarray, epsilon: float) -> np.ndarray:
    """
    Ramer-Douglas-Peucker polyline simplification.

    Args:
        poly: (N,2) polyline in mm (float)
        epsilon: max allowed deviation in mm
    Returns:
        simplified polyline (M,2)
    """
    if poly.ndim != 2 or poly.shape[1] != 2:
        raise ValueError(f"poly must be (N,2), got {poly.shape}")
    n = len(poly)
    if n <= 2:
        return poly.copy()

    keep = np.zeros(n, dtype=bool)
    keep[0] = True
    keep[-1] = True

    stack = [(0, n - 1)]
    while stack:
        i0, i1 = stack.pop()
        a = poly[i0]
        b = poly[i1]

        max_d = -1.0
        idx = -1
        for i in range(i0 + 1, i1):
            d = _perp_dist_point_to_segment(poly[i], a, b)
            if d > max_d:
                max_d = d
                idx = i

        if max_d > epsilon and idx != -1:
            keep[idx] = True
            stack.append((i0, idx))
            stack.append((idx, i1))

    return poly[keep].copy()
