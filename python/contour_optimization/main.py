import re
import numpy as np

W, H = 170, 240
PAYLOAD_LEN = (W * H) // 8  # 5100 bytes


def load_hex_txt_to_bytes(path: str) -> bytes:
    # Extract all 2-hex-digit tokens (optionally prefixed with '0x') and convert to bytes.
    # Examples accepted: "AA 01 FF", "0xAA,0x01,0xFF", line-separated, etc.
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()

    tokens = re.findall(r"\b(?:0x)?([0-9a-fA-F]{2})\b", text)
    if not tokens:
        raise ValueError("No hex byte tokens found in the txt file.")

    return bytes(int(t, 16) for t in tokens)


def extract_payload_after_header(data: bytes, header: int = 0xAA, payload_len: int = PAYLOAD_LEN) -> bytes:
    # Find the first occurrence of the header byte and slice out the payload right after it.
    idx = data.find(bytes([header]))
    if idx < 0:
        raise ValueError(f"Header 0x{header:02X} not found in the file data.")

    start = idx + 1
    end = start + payload_len
    if len(data) < end:
        raise ValueError(
            f"Not enough bytes after header. Need {payload_len}, have {len(data) - start}."
        )

    return data[start:end]


def unpack_payload_to_image(payload_5100: bytes, w: int = W, h: int = H, bitorder: str = "big") -> np.ndarray:
    # Unpack 5100 bytes (40800 bits) into a (H, W) binary image.
    # bitorder="big" means MSB-first; use "little" if the image appears scrambled.
    expected = (w * h) // 8
    if len(payload_5100) != expected:
        raise ValueError(f"Payload must be {expected} bytes, got {len(payload_5100)} bytes.")

    arr = np.frombuffer(payload_5100, dtype=np.uint8)
    bits = np.unpackbits(arr, bitorder=bitorder)[: w * h]
    img = (bits.reshape((h, w)).astype(np.uint8))  # values: 0 or 1
    return img


if __name__ == "__main__":
    raw_bytes = load_hex_txt_to_bytes("binary_dump_test.txt")

    # Case 1) File contains [0xAA][5100 bytes] (or more) -> extract payload after 0xAA
    payload = extract_payload_after_header(raw_bytes, header=0xAA, payload_len=PAYLOAD_LEN)

    # Case 2) If your file contains exactly 5100 payload bytes only (no header), use this instead:
    # payload = raw_bytes[:PAYLOAD_LEN]

    img01 = unpack_payload_to_image(payload, bitorder="big")  # try "little" if needed

    print("img01 shape:", img01.shape)          # (240, 170)
    print("img01 dtype:", img01.dtype)          # uint8
    print("unique values:", np.unique(img01))   # [0 1] expected
    print(img01)
