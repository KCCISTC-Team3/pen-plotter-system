import serial
import time
import os
from PIL import Image
from config import W, H


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
                ser.write(bytes.fromhex("30"))
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

    def trigger_and_receive_mode(self, save_path, progress_cb=None, target_size=None):
        """[개선] 0xAA 트리거 송신 직후 즉시 수신 모드로 전환 (카메라 탭용)"""
        self.is_receiving = True
        received_data = bytearray()
        start_time = time.time()  # 타임아웃 체크용

        try:
            # 포트를 열고 송수신을 한 세션에서 처리
            ser = serial.Serial(self.port, self.baudrate, timeout=0.1)

            if ser.is_open:
                # 1. 트리거(AA) 송신
                ser.write(bytes.fromhex("30"))
                ser.flush()
                print("Trigger AA sent. Entering receive mode...")

                # 2. 즉시 수신 루프 진입
                while self.is_receiving and len(received_data) < target_size:
                    # 10초간 데이터가 전혀 오지 않으면 튕김 방지를 위해 탈출
                    if time.time() - start_time > 10:
                        print("Timeout: No response from FPGA")
                        break

                    if ser.in_waiting > 0:
                        chunk = ser.read(ser.in_waiting)
                        received_data.extend(chunk)
                        start_time = time.time()  # 데이터가 들어오면 타이머 리셋

                        if progress_cb:
                            p = int((len(received_data) / target_size) * 100)
                            progress_cb(min(p, 100))

                    # GUI가 멈추지 않도록 제어권 반환 (Main 쪽에서 호출 시 필요)
                    time.sleep(0.001)

                if len(received_data) >= target_size:
                    with open(save_path, "w") as f:
                        f.write(received_data.hex())
                    return True
            return False
        except Exception as e:
            print(f"통신 에러: {e}")
            return False
        finally:
            if 'ser' in locals(): ser.close()

    def send_image_to_fpga(self, img_obj, filtered_path, progress_cb=None):
        """
        이미지를 WxH로 리사이징하고 FPGA에 0x30 + RGB888 데이터 전송 후 수신
        
        Args:
            img_obj: PIL Image 객체
            filtered_path: FPGA로부터 수신한 데이터를 저장할 경로 (.txt)
            progress_cb: 진행률 콜백 함수 (옵션)
        
        Returns:
            bool: 성공 여부
        """
        ser = serial.Serial(port=self.port, baudrate=self.baudrate, timeout=20)
        try:
            if ser.is_open:
                time.sleep(3)
                ser.reset_input_buffer()
                ser.reset_output_buffer()

                # 이미지를 WxH로 리사이징하고 RGB로 변환
                rgb_img = img_obj.resize((W, H), Image.Resampling.LANCZOS).convert("RGB")
                pixels = list(rgb_img.getdata())
                total_pixels = len(pixels)

                # [A] 트리거 송신 (0x30)
                ser.write(bytes.fromhex("30"))
                ser.flush()
                time.sleep(0.1)

                # [B] RGB888 데이터 송신 (R, G, B를 각각 별도의 바이트로 전송)
                for i, (r, g, b) in enumerate(pixels):
                    ser.write(bytes([r, g, b]))
                    
                    # 진행률 업데이트
                    if progress_cb and i % 1000 == 0:
                        progress_cb(int((i / total_pixels) * 100))
                    
                    # 너무 빠르게 보내지 않도록 약간의 딜레이
                    if i % 500 == 0:
                        time.sleep(0.001)

                ser.flush()

                # [C] 데이터 수신 대기
                start_wait = time.time()
                while ser.in_waiting == 0:
                    if time.time() - start_wait > 10:
                        raise Exception("FPGA 응답 없음 (Timeout)")
                    time.sleep(0.01)

                # [D] 데이터 수신 (W*H 바이트)
                target_size = W * H
                received_raw = ser.read(target_size)
                
                if received_raw:
                    with open(filtered_path, "w") as f_out:
                        # Hex 텍스트 형식으로 저장 (2자리씩)
                        for byte_val in received_raw:
                            f_out.write(f"{byte_val:02x}")
                    return True
            return False
        except Exception as e:
            print(f"FPGA 통신 에러: {e}")
            return False
        finally:
            ser.close()

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