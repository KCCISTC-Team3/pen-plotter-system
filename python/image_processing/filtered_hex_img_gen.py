import os
import cv2
import numpy as np


def save_hex_txt_bytes(
    data: bytes,
    path: str,
    mode: str = "stream",   # "stream" or "tokens"
    upper: bool = True
) -> None:
    """
    Save raw bytes to a text file as hex.
    - stream: continuous hex string (e.g., "AA00FF...")
    - tokens: space-separated tokens (e.g., "AA 00 FF ...")
    """
    hex_str = data.hex()
    if upper:
        hex_str = hex_str.upper()

    if mode == "stream":
        text = hex_str
    elif mode == "tokens":
        text = " ".join(hex_str[i:i+2] for i in range(0, len(hex_str), 2))
    else:
        raise ValueError("mode must be 'stream' or 'tokens'")

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def process_and_save(
    image_path: str,
    out_dir: str,
    idx: int,
    gaussian_ksize: int = 5,
    gaussian_sigma: float = 1.0,
    sobel_ksize: int = 3,
    canny_low: int = 50,
    canny_high: int = 150,
    hex_mode: str = "stream",      # "stream" or "tokens"
    save_packed_1bpp: bool = True, # optional: 8 pixels -> 1 byte packing
) -> None:
    # Ensure output directory exists
    os.makedirs(out_dir, exist_ok=True)

    # Load image
    img_bgr = cv2.imread(image_path, cv2.IMREAD_COLOR)
    if img_bgr is None:
        raise FileNotFoundError(f"Failed to load image: {image_path}")

    # 1) Gray
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    # 2) Gaussian blur
    if gaussian_ksize % 2 == 0:
        gaussian_ksize += 1
    blur = cv2.GaussianBlur(gray, (gaussian_ksize, gaussian_ksize), gaussian_sigma)

    # 3) Sobel magnitude
    sobel_x = cv2.Sobel(blur, cv2.CV_32F, 1, 0, ksize=sobel_ksize)
    sobel_y = cv2.Sobel(blur, cv2.CV_32F, 0, 1, ksize=sobel_ksize)
    mag = cv2.magnitude(sobel_x, sobel_y)
    mag_u8 = cv2.normalize(mag, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)

    # 4) Canny edges
    edges = cv2.Canny(blur, canny_low, canny_high)  # uint8 {0,255}

    # Save PNG results
    cv2.imwrite(os.path.join(out_dir, f"01_gray_{idx}.png"), gray)
    cv2.imwrite(os.path.join(out_dir, f"02_gaussian_{idx}.png"), blur)
    cv2.imwrite(os.path.join(out_dir, f"03_sobel_mag_{idx}.png"), mag_u8)
    cv2.imwrite(os.path.join(out_dir, f"04_canny_{idx}.png"), edges)

    # Save per-pixel hex txt (0x00 or 0xFF per pixel)
    # This is a raw raster dump: length = H*W bytes
    edges_bytes = edges.tobytes()
    save_hex_txt_bytes(edges_bytes, os.path.join(out_dir, f"05_canny_pixels_hex_{idx}.txt"), mode=hex_mode)

    # Optional: save packed 1bpp (8 pixels -> 1 byte), matching your FPGA/PC unpacking style
    if save_packed_1bpp:
        # Convert to 0/1 first
        edges01 = (edges > 0).astype(np.uint8)

        # Pack bits: MSB-first by default (bitorder='big')
        packed = np.packbits(edges01, axis=None, bitorder="big").tobytes()

        save_hex_txt_bytes(packed, os.path.join(out_dir, f"05_canny_packed_1bpp_hex_{idx}.txt"), mode=hex_mode)

    print("Saved outputs to:", os.path.abspath(out_dir))
    print(f"PNG: 01_gray_{idx}.png / 02_gaussian_{idx}.png / 03_sobel_mag_{idx}.png / 04_canny_{idx}.png")
    print(f"HEX (per-pixel bytes): 05_canny_pixels_hex_{idx}.txt")
    if save_packed_1bpp:
        print(f"HEX (packed 1bpp): 05_canny_packed_1bpp_hex_{idx}.txt")

if __name__ == "__main__":
    IMAGE_PATH = "images/hello.png"  # change this
    process_and_save(
        IMAGE_PATH,
        out_dir="images",
        idx=0,
        gaussian_ksize=5,
        gaussian_sigma=1.0,
        sobel_ksize=3,
        canny_low=50,
        canny_high=150,
        hex_mode="stream",      # "stream" or "tokens"
        save_packed_1bpp=True,
    )
