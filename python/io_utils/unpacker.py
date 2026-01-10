# imaging/unpack.py
import numpy as np
import re

def load_hex_txt_to_bytes(path: str) -> bytes:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()

    tokens = re.findall(r"(?:0x)?([0-9a-fA-F])", text)
    if not tokens:
        raise ValueError("No hex byte tokens found in the txt file.")

    return bytes(int(t, 16) for t in tokens)

def extract_payload_after_header(data: bytes, header: int, payload_len: int) -> bytes:
    idx = data.find(bytes([header]))
    if idx < 0:
        raise ValueError(f"Header 0x{header:02X} not found in the file data.")

    start = idx + 1
    end = start + payload_len
    if len(data) < end:
        raise ValueError(f"Not enough bytes after header. Need {payload_len}, have {len(data) - start}.")

    return data[start:end]

def unpack_payload_to_image(payload: bytes, w: int, h: int, bitorder: str = "big") -> np.ndarray:
    expected = (w * h) // 8
    if len(payload) != expected:
        raise ValueError(f"Payload must be {expected} bytes, got {len(payload)} bytes.")

    arr = np.frombuffer(payload, dtype=np.uint8)
    bits = np.unpackbits(arr, bitorder=bitorder)[: w * h]
    return bits.reshape((h, w)).astype(np.uint8)

def to_img255(img01: np.ndarray) -> np.ndarray:
    return (img01.astype(np.uint8) * 255)
