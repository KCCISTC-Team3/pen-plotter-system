import serial
import time
import os
from PIL import Image


class FPGAUartManager:
    def __init__(self, port, baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.is_receiving = False


    def save_as_mem(self, img_obj, mem_path, target_size):
        """이미지를 FPGA용 .mem 형식으로 변환"""
        rgb_img = img_obj.resize(target_size, Image.Resampling.LANCZOS).convert("RGB")
        try:
            with open(mem_path, "w") as f:
                pixels = list(rgb_img.getdata())
                for i, (r, g, b) in enumerate(pixels):
                    f.write(f"{r:02x}{g:02x}{b:02x}" + ("\n" if (i + 1) % 8 == 0 else " "))
            return True
        except Exception as e:
            print(f"파일 저장 실패: {e}")
            return False

    def process_serial_communication(self, mem_path, filtered_path, progress_cb=None, target_size=None):
        """AA 트리거 송신 -> 데이터 송신 -> 데이터 수신 로직"""
        ser = serial.Serial(port=self.port, baudrate=self.baudrate, timeout=20)
        try:
            if ser.is_open:
                time.sleep(3)
                ser.reset_input_buffer()
                ser.reset_output_buffer()

                # [A] 트리거 송신
                ser.write(bytes.fromhex("AA"))
                ser.flush()
                time.sleep(0.1)

                # [B] 데이터 송신
                with open(mem_path, 'r') as f:
                    pixels = f.read().split()

                total = len(pixels)
                for i, hex_val in enumerate(pixels):
                    if len(hex_val) == 6:
                        ser.write(bytes.fromhex(hex_val))
                    if i % 500 == 0:
                        time.sleep(0.001)
                    if progress_cb and i % 1000 == 0:
                        progress_cb(int((i / total) * 100))

                # [C] 데이터 수신 대기
                start_wait = time.time()
                while ser.in_waiting == 0:
                    if time.time() - start_wait > 10:
                        raise Exception("FPGA 응답 없음 (Timeout)")
                    time.sleep(0.01)

                # [D] 데이터 수신
                received_raw = ser.read(target_size)
                if received_raw:
                    with open(filtered_path, "w") as f_out:
                        # f_out.write(HEADER_FPGA)   # header
                        for j in range(0, len(received_raw), 3):
                            chunk = received_raw[j:j + 3]
                            if len(chunk) == 3:
                                f_out.write(chunk.hex())
                    return True
            return False
        finally:
            ser.close()

    def receive_only_mode(self, save_path, progress_cb=None, target_size=None):
        """[추가] 카메라 탭용: 트리거 없이 데이터가 올 때까지 대기 및 수신"""
        self.is_receiving = True
        received_data = bytearray()
        # target_size = W * H  # 예상 수신 크기

        try:
            # 타임아웃을 짧게 주어 루프가 돌면서 중단 플래그를 체크하게 함
            ser = serial.Serial(self.port, self.baudrate, timeout=0.1)

            while self.is_receiving and len(received_data) < target_size:
                if ser.in_waiting > 0:
                    chunk = ser.read(ser.in_waiting)
                    received_data.extend(chunk)
                    if progress_cb:
                        p = int((len(received_data) / target_size) * 100)
                        progress_cb(min(p, 100))

                # 다른 탭 클릭 등의 이벤트를 처리하기 위해 잠시 양보
                # QCoreApplication.processEvents()
                time.sleep(0.01)

            if not self.is_receiving:  # 탭 이동으로 중단된 경우
                return False

            if len(received_data) >= target_size:
                with open(save_path, "w") as f:
                    f.write(received_data.hex())
                return True
            return False
        except Exception as e:
            print(f"수신 에러: {e}")
            return False
        finally:
            if 'ser' in locals(): ser.close()

    def convert_hex_to_binary_text(self, hex_path, bin_path):
        """수신된 Hex 파일을 일자 나열된 Binary 텍스트로 변환"""
        with open(hex_path, 'r') as f_mem:
            hex_content = f_mem.read()

        all_bits = []
        for char in hex_content:
            if char in '0123456789abcdefABCDEF':
                # 16진수 한 자리를 4비트로 변환하여 8비트(1바이트) 쌍을 맞춤
                decimal_val = int(char, 16)
                all_bits.append(format(decimal_val, '08b'))

        with open(bin_path, 'w') as f_bin:
            f_bin.write("".join(all_bits))