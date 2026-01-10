import re
import serial
import time

def load_hex_txt_to_bytes(path: str) -> bytes:
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read()

    tokens = re.findall(r"(?:0x)?([0-9a-fA-F]{2})", text)
    if not tokens:
        raise ValueError("No hex byte tokens found in the txt file.")

    return bytes(int(t, 16) for t in tokens)



# def fpga_uart_receiver(self, mem_path: str, current_num: int):
#     ser = serial.Serial(port=self.target_port, baudrate=115200, timeout=10)

#     if ser.is_open:
#         time.sleep(3)
#         ser.reset_input_buffer()
#         ser.reset_output_buffer()

#         # [A] 데이터 송신
#         print(f"트리거 AA 전송 시작 ({self.target_port})")
#         ser.write(bytes.fromhex("AA"))
#         ser.flush()
#         time.sleep(0.1)  # FPGA가 수신 상태에서 연산 상태로 전환될 시간

#         with open(mem_path, 'r') as f:
#             pixels = f.read().split()

#         total_pixels = len(pixels)
#         for i, hex_val in enumerate(pixels):
#             if len(hex_val) == 6:
#                 ser.write(bytes.fromhex(hex_val))
#             if i % 500 == 0:
#                 time.sleep(0.001)
#             if (i + 1) % 1000 == 0 or (i + 1) == total_pixels:
#                 percent = (i + 1) / total_pixels * 100
#                 self.btn_start.setText(f"데이터 송신 중... {percent:.1f}%")
#                 QApplication.processEvents()

#         # [B] 데이터 수신 대기
#         self.btn_start.setText("수신 대기 중...")
#         QApplication.processEvents()

#         start_wait_time = time.time()
#         while ser.in_waiting == 0:
#             if time.time() - start_wait_time > 10:
#                 raise Exception("FPGA 응답 없음")
#             QApplication.processEvents()
#             time.sleep(0.01)

#         expected_bytes = 41280
#         received_raw = ser.read(expected_bytes)

#         # [C] 수신 데이터를 .mem 파일로 일자 저장
#         if len(received_raw) > 0:
#             with open(filtered_mem_path, "w") as f_out:
#                 for j in range(0, len(received_raw), 3):
#                     chunk = received_raw[j:j + 3]
#                     if len(chunk) == 3:
#                         # 구분자(공백, 줄바꿈) 없이 16진수 문자열만 기록
#                         f_out.write(chunk.hex())

#             print(f"수신 완료: {filtered_mem_path}")

#             # [D] .mem 파일을 읽어 공백 없는 이진수(Binary)로 변환
#             binary_output_path = os.path.join('images', f"filtered_{current_num}_binary.txt")

#             with open(filtered_mem_path, 'r') as f_mem:
#                 hex_content = f_mem.read()

#             all_bits = []
#             for char in hex_content:
#                 if char in '0123456789abcdefABCDEF':
#                     decimal_val = int(char, 16)
#                     binary_val = format(decimal_val, '08b')  # ← 핵심 수정
#                     all_bits.append(binary_val)

#             # 이진수 결과를 공백 없이 이어서 저장
#             with open(binary_output_path, 'w') as f_bin:
#                 f_bin.write("".join(all_bits))

#             print(f"이진 변환 완료: {binary_output_path}")
#             StatusDialog("SUCCESS",
#                             f"데이터 수신 및 일자 나열 변환 완료!\n{binary_output_path}",
#                             self).exec()
#         else:
#             raise Exception("데이터 수신 실패")

#         ser.close()
#     else:
#         raise Exception("포트 열기 실패")

# except Exception as e:
#     QMessageBox.critical(self, "오류", f"작업 실패: {str(e)}")
# finally:
#     self.btn_start.setEnabled(True)
#     self.btn_start.setText("전송 시작")