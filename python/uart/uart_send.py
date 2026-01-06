from PIL import Image
import serial

WIDTH  = 170
HEIGHT = 240

ser = serial.Serial(
    port='COM3',
    baudrate=115200,
    timeout=1
)

# BMP 열기
img = Image.open("123.bmp").convert("RGB")
w, h = img.size
assert w == WIDTH and h == HEIGHT

pixels = img.load()

pixel_cnt = 0  # 0~255 반복 (1바이트)

ser.write(b'\xAA')

for y in range(HEIGHT):
    for x in range(WIDTH):
        r, g, b = pixels[x, y]

        packet = bytes([ r,  g,  b])

        ser.write(packet)

# for y in range(HEIGHT):
#     pixel_cnt = 0;

#     for x in range(WIDTH):
#         r, g, b = pixels[x, y]

#         packet = bytes([
#             pixel_cnt,
#             r,
#             g,
#             b
#         ])

#         ser.write(packet)

#         pixel_cnt = (pixel_cnt + 1)


ser.close()