from __future__ import annotations
from typing import List, Tuple, Optional
import numpy as np


def contour_endpoints(c: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    # Return (start_point, end_point) as (2,) arrays.
    return c[0], c[-1]


def euclidean(a: np.ndarray, b: np.ndarray) -> float:
    # Compute Euclidean distance between two (x,y) points.
    d = a.astype(np.float32) - b.astype(np.float32)
    return float(np.hypot(d[0], d[1]))


def greedy_reorder_contours(
    contours: List[np.ndarray],
    start_point: Optional[np.ndarray] = None,
) -> Tuple[List[np.ndarray], float]:
    """
    Reorder contours with a greedy heuristic to minimize pen-up travel distance.
    For each step, choose the next contour (and its direction) that minimizes
    distance from current point to the contour's start point.

    Args:
        contours: list of contours, each contour is an (N,2) array in pixel coords.
        start_point: optional (2,) point. If None, start at the first contour's start.

    Returns:
        ordered_contours: list of contours reordered; each contour may be reversed.
        total_penup_dist: sum of pen-up distances (in pixels) between contours.
    """
    if not contours:
        return [], 0.0

    remaining = [c for c in contours if len(c) >= 2]
    if not remaining:
        return [], 0.0

    # Choose initial contour:
    # If start_point is not given, pick the longest contour as a stable starting choice.
    if start_point is None:
        idx0 = int(np.argmax([len(c) for c in remaining]))
        current = remaining.pop(idx0)
        ordered = [current]
        cur_pt = current[-1]
        total = 0.0
    else:
        # If start_point is given, choose the best first contour and direction.
        best_i, best_rev, best_d = -1, False, float("inf")
        for i, c in enumerate(remaining):
            s, e = contour_endpoints(c)
            d_keep = euclidean(start_point, s)
            d_rev = euclidean(start_point, e)
            if d_keep < best_d:
                best_i, best_rev, best_d = i, False, d_keep
            if d_rev < best_d:
                best_i, best_rev, best_d = i, True, d_rev

        first = remaining.pop(best_i)
        if best_rev:
            first = first[::-1].copy()
        ordered = [first]
        cur_pt = first[-1]
        total = best_d

    # Greedy selection of next contours
    while remaining:
        best_i, best_rev, best_d = -1, False, float("inf")

        for i, c in enumerate(remaining):
            s, e = contour_endpoints(c)

            d_keep = euclidean(cur_pt, s)
            d_rev = euclidean(cur_pt, e)

            if d_keep < best_d:
                best_i, best_rev, best_d = i, False, d_keep
            if d_rev < best_d:
                best_i, best_rev, best_d = i, True, d_rev

        nxt = remaining.pop(best_i)
        if best_rev:
            nxt = nxt[::-1].copy()

        ordered.append(nxt)
        cur_pt = nxt[-1]
        total += best_d

    return ordered, total


def total_penup_distance(contours: List[np.ndarray], start_point: Optional[np.ndarray] = None) -> float:
    # Compute pen-up distance for a given contour order (no direction changes assumed here).
    if not contours:
        return 0.0

    total = 0.0
    if start_point is None:
        cur = contours[0][-1]
    else:
        cur = start_point

    for c in contours:
        s = c[0]
        total += euclidean(cur, s)
        cur = c[-1]

    return total