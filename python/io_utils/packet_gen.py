# packet_gen/commands.py
from __future__ import annotations
from typing import List
import numpy as np


def format_cmd(x_mm: float, y_mm: float, z: int) -> str:
    """
    Format command as a fixed pattern line.
    Note: Keep formatting consistent with MCU parser.
    """
    # Example format: x:123.4y:056.7z:1\n
    # Adjust width/precision to exactly match your STM32 parsing expectations.
    return f"x:{x_mm:05.1f}y:{y_mm:05.1f}z:{z:d}\n"


def build_command_sequence_from_contours_xy(
    contours_xy: List[np.ndarray],
    pen_up_z: int = 1,
    pen_down_z: int = 0,
) -> List[str]:
    """
    Build commands:
      - Start with pen up
      - For each contour:
          move to start (pen up)
          draw along points (pen down)
          lift pen (pen up)

    Args:
        contours_mm: list of (N,2) mm polylines (already densified)
    Returns:
        list of command strings
    """
    cmds: List[str] = []

    # Initial state: pen up at current position (position may be ignored by MCU)
    cmds.append(format_cmd(0.0, 0.0, pen_up_z))

    for c in contours_xy:
        if c is None or len(c) == 0:
            continue

        # Move to contour start with pen up
        x0, y0 = float(c[0, 0]), float(c[0, 1])
        cmds.append(format_cmd(x0, y0, pen_up_z))

        # Draw contour with pen down
        for p in c:
            x, y = float(p[0]), float(p[1])
            cmds.append(format_cmd(x, y, pen_down_z))

        # Lift pen after finishing contour
        x1, y1 = float(c[-1, 0]), float(c[-1, 1])
        cmds.append(format_cmd(x1, y1, pen_up_z))

    return cmds
