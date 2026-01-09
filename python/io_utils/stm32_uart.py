import serial
import time


class STM32UartManager:
    def __init__(self, port, baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.ACK_BYTE = b'\xBB'  # STM32 완료 신호

    def send_coordinates_file(self, file_path, progress_cb=None):
        try:
            # 시리얼 오픈
            ser = serial.Serial(self.port, self.baudrate, timeout=1)
            with open(file_path, 'r') as f:
                lines = f.readlines()

            total = len(lines)
            for i, line in enumerate(lines):
                clean_line = line.strip()
                if not clean_line: continue

                # 1. 좌표 송신 (예: x:000.0y:000.0:z:0)
                print(f"[PC -> STM] 송신: {clean_line}")
                ser.write((clean_line + '\n').encode('utf-8'))

                # 2. 0xBB 응답 대기
                while True:
                    if ser.in_waiting > 0:
                        rx_byte = ser.read(1)
                        print(f"[STM -> PC] 수신 데이터(Hex): {rx_byte.hex().upper()}")

                        if rx_byte == self.ACK_BYTE:
                            print(f"--- ACK 확인 (0xBB) ---")
                            break  # 다음 좌표로
                    time.sleep(0.001)

                if progress_cb: progress_cb(int(((i + 1) / total) * 100))

            ser.close()
            return True
        except Exception as e:
            print(f"STM32 통신 에러: {e}")
            return False