# import serial
# import time
#
# # 1. 시리얼 포트 설정 (본인의 COM 포트 번호로 수정)
# PORT = 'COM8'
# BAUD = 115200
#
#
# def start_test():
#     try:
#         # 포트 열기 (timeout을 설정해야 readline이 무한 대기하지 않음)
#         ser = serial.Serial(PORT, BAUD, timeout=1)
#         print(f"--- {PORT} 연결됨 ---")
#         time.sleep(2)  # 보드 초기화 시간 대기
#
#         # 2. 보낼 데이터 생성 (반드시 \n 포함)
#         test_msg = "x:123.4y:567.8z:1\n"
#         print(f"보내는 데이터: {test_msg.strip()}")
#
#         # 데이터 전송
#         ser.write(test_msg.encode('ascii'))
#
#         # 3. STM32 응답 읽기 (최대 2초간 대기)
#         startTime = time.time()
#         while time.time() - startTime < 2:
#             if ser.in_waiting > 0:
#                 # decode('ascii', errors='ignore')를 써서 깨진 문자가 있어도 에러 안 나게 처리
#                 line = ser.readline().decode('ascii', errors='ignore').strip()
#                 if line:
#                     print(f"STM32 응답: {line}")
#                 if "[OK]" in line:  # 파싱 성공 메시지가 오면 종료
#                     break
#
#         ser.close()
#         print("--- 테스트 종료 ---")
#
#     except Exception as e:
#         print(f"에러 발생: {e}")
#
#
# if __name__ == "__main__":
#     start_test()

# import serial
# import time

# # 1. 시리얼 포트 설정 (본인 환경에 맞게 수정 필수!)
# ser = serial.Serial('COM8', 115200, timeout=0.1)

# queue_size = 64
# sent_idx = 0
# current_in_queue = 0

# print("실험 시작: 데이터를 64개 먼저 쏩니다.")

# # 100개의 테스트 좌표 전송 시뮬레이션
# while sent_idx < 100:
#     # STM32로부터 0xBB(디큐 신호)가 왔는지 체크
#     if ser.in_waiting > 0:
#         rx = ser.read(ser.in_waiting)
#         for byte in rx:
#             if byte == 0xBB:
#                 current_in_queue -= 1
#                 print(f"<< [0xBB 수신] 큐 공간 확보 (현재 큐: {current_in_queue})")

#     # 큐가 64개 미만이면 계속 전송
#     if current_in_queue < queue_size:
#         data = f"x:{sent_idx}.0y:{sent_idx}.0z:1\n"
#         ser.write(data.encode())
#         sent_idx += 1
#         current_in_queue += 1
#         print(f">> [데이터 송신] {data.strip()} (전체: {sent_idx}, 큐: {current_in_queue})")
#         time.sleep(0.001)
#     else:
#         # 큐가 꽉 찼으면 0xBB 신호를 기다리며 아주 짧게 대기
#         time.sleep(0.01)

# print("모든 실험 데이터 전송 완료!")
# ser.close()


#====================================== 1 by 1

import serial
import time

# 1. 시리얼 포트 설정
# timeout을 None으로 설정하면 0xBB가 올 때까지 무한정 기다립니다.
# 보드가 모터 동작으로 인해 오래 걸릴 수 있으므로 timeout을 넉넉히 주거나 None으로 설정하세요.
ser = serial.Serial('COM7', 115200, timeout=1.0)

sent_idx = 0
total_data = 100

print(f"실험 시작: 1:1 동기화 방식으로 {total_data}개의 데이터를 전송합니다.")

while sent_idx < total_data:
    # 1. 전송할 데이터 생성 및 송신
    data = f"x:{sent_idx}.0y:{sent_idx}.0z:1\n"
    ser.write(data.encode())
    print(f">> [데이터 송신] {data.strip()} (순서: {sent_idx + 1}/{total_data})")

    # 2. STM32로부터 0xBB(ACK) 신호가 올 때까지 무한 대기
    # ser.read(1)은 데이터가 1바이트 들어올 때까지 코드 실행을 멈추고 기다립니다.
    while True:
        rx_byte = ser.read(1)

        if rx_byte == b'\xbb':
            print(f"<< [0xBB 수신] 보드가 다음 명령을 받을 준비가 되었습니다.")
            break  # 성공적으로 받았으므로 다음 데이터 전송으로 넘어감

        elif len(rx_byte) == 0:
            # 설정한 timeout(1.0초) 동안 아무것도 안 왔을 때
            # print("...보드 응답 대기 중...")
            # 필요하다면 여기서 다시 read를 하거나 에러 처리를 합니다.
            continue

    sent_idx += 1

print("\n모든 실험 데이터 전송 완료!")
ser.close()