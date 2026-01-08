import re

def load_hex_txt_to_bytes(path: str) -> bytes:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()

    tokens = re.findall(r"(?:0x)?([0-9a-fA-F]{2})", text)
    if not tokens:
        raise ValueError("No hex byte tokens found in the txt file.")

    return bytes(int(t, 16) for t in tokens)
