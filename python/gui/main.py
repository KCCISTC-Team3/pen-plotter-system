import sys
import os
import serial
import time
from PyQt6.QtWidgets import (QApplication, QMainWindow, QTabWidget, QWidget,
                             QVBoxLayout, QHBoxLayout, QPushButton, QFileDialog,
                             QLabel, QLineEdit, QDialog, QMessageBox, QFrame, QSizePolicy)
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QPixmap
from PIL import Image

# 사용자 정의 모듈 (painter.py, style_sheets.py가 같은 경로에 있어야 함)
from painter import PaintCanvas
import style_sheets


# 1. 초기 시스템 연결 창
class PortConfigDialog(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("펜 플로터 연결")
        self.setFixedSize(450, 320)
        self.setStyleSheet(style_sheets.STYLE_SHEET)

        layout = QVBoxLayout()
        layout.setContentsMargins(50, 40, 50, 40)
        layout.setSpacing(20)

        title = QLabel("하드웨어 연결")
        title.setObjectName("dialog_title")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.status_label = QLabel("FPGA 포트를 입력하세요 (예: COM8)")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.port_input = QLineEdit()
        self.port_input.setText("COM8")
        self.port_input.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.btn_connect = QPushButton("장치 연결 확인")
        self.btn_connect.setObjectName("connect_btn")
        self.btn_connect.setFixedHeight(50)
        self.btn_connect.clicked.connect(self.handle_connection)

        layout.addWidget(title)
        layout.addWidget(self.status_label)
        layout.addWidget(self.port_input)
        layout.addWidget(self.btn_connect)
        self.setLayout(layout)

    def handle_connection(self):
        self.accept()

    def get_port(self):
        return self.port_input.text()


# 2. 메인 제어 인터페이스
class MainWindow(QMainWindow):
    def __init__(self, port):
        super().__init__()
        # 해상도 172x240 고정 (총 40,800 픽셀)
        self.TARGET_W, self.TARGET_H = 172, 240

        screen_geo = QApplication.primaryScreen().availableGeometry()
        display_h = int(screen_geo.height() * 0.52)
        self.SCALE = display_h / self.TARGET_H
        self.DISPLAY_W = int(self.TARGET_W * self.SCALE)
        self.DISPLAY_H = display_h

        self.setWindowTitle("펜 플로터 허브 (Bidirectional Filter Mode)")
        self.setStyleSheet(style_sheets.STYLE_SHEET)

        self.target_port = port
        self.upload_img_path = None

        if not os.path.exists('images'): os.makedirs('images')
        self.init_ui()
        self.position_window_upper_center()

    def position_window_upper_center(self):
        screen = QApplication.primaryScreen().availableGeometry()
        size = self.frameGeometry()
        x = (screen.width() - size.width()) // 2
        y = int(screen.height() * 0.03)
        self.move(x, y)

    def init_ui(self):
        central_widget = QWidget()
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # Header
        header_frame = QFrame()
        header_frame.setObjectName("header_frame")
        header_layout = QHBoxLayout(header_frame)
        header_layout.setContentsMargins(30, 15, 30, 15)
        header_title = QLabel("PEN PLOTTER HUB")
        header_title.setObjectName("header_title")
        port_badge = QLabel(f"● {self.target_port} ACTIVE")
        port_badge.setStyleSheet(
            "color: #3fb950; font-weight: bold; font-size: 11px; background: #21262d; padding: 5px 12px; border-radius: 12px;")
        header_layout.addWidget(header_title)
        header_layout.addStretch()
        header_layout.addWidget(port_badge)
        main_layout.addWidget(header_frame)

        content_layout = QVBoxLayout()
        content_layout.setContentsMargins(30, 20, 30, 25)
        content_layout.setSpacing(15)

        self.tabs = QTabWidget()
        self.tabs.setFixedSize(self.DISPLAY_W + 60, self.DISPLAY_H + 125)

        # TAB 1: 이미지 로드
        upload_tab = QWidget()
        u_layout = QVBoxLayout(upload_tab)
        self.btn_load = QPushButton("이미지 불러오기")
        self.btn_load.setFixedHeight(45)
        self.btn_load.clicked.connect(self.load_image)
        self.label_preview = QLabel("이미지를 로드하세요")
        self.label_preview.setObjectName("preview_area")
        self.label_preview.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)
        self.label_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
        u_layout.addWidget(self.btn_load)
        u_layout.addWidget(self.label_preview, alignment=Qt.AlignmentFlag.AlignCenter)

        # TAB 2: 실시간 스케치
        paint_tab = QWidget()
        p_layout = QVBoxLayout(paint_tab)
        self.paint_canvas = PaintCanvas(self.TARGET_W, self.TARGET_H, self.DISPLAY_W, self.DISPLAY_H)
        tool_layout = QHBoxLayout()
        tools = [("펜", "pen"), ("지우개", "eraser"), ("전체 삭제", "clear")]
        for text, mode in tools:
            btn = QPushButton(text)
            if mode == "clear":
                btn.clicked.connect(self.paint_canvas.clear_canvas)
            else:
                btn.clicked.connect(lambda ch, m=mode: self.paint_canvas.set_tool(m))
            tool_layout.addWidget(btn)
        p_layout.addLayout(tool_layout)
        p_layout.addWidget(self.paint_canvas, alignment=Qt.AlignmentFlag.AlignCenter)

        self.tabs.addTab(upload_tab, " 이미지 로드 ")
        self.tabs.addTab(paint_tab, " 실시간 스케치 ")
        content_layout.addWidget(self.tabs, alignment=Qt.AlignmentFlag.AlignCenter)

        self.btn_start = QPushButton("전송 및 필터 수신 시작")
        self.btn_start.setObjectName("start_btn")
        self.btn_start.setFixedHeight(55)
        self.btn_start.clicked.connect(self.process_and_start)
        content_layout.addWidget(self.btn_start)

        main_layout.addLayout(content_layout)
        self.setCentralWidget(central_widget)

    def load_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, '이미지 선택', '', 'Images (*.png *.jpg *.bmp)')
        if fname:
            self.upload_img_path = fname
            pixmap = QPixmap(fname).scaled(self.DISPLAY_W, self.DISPLAY_H, Qt.AspectRatioMode.KeepAspectRatio)
            self.label_preview.setPixmap(pixmap)

    def get_next_file_path(self):
        idx = 0
        while os.path.exists(os.path.join('images', f"image_{idx}.mem")): idx += 1
        return idx

    def save_as_mem(self, img_obj, current_num):
        rgb_img = img_obj.resize((self.TARGET_W, self.TARGET_H), Image.Resampling.LANCZOS).convert("RGB")
        mem_path = os.path.join('images', f"image_{current_num}.mem")
        try:
            with open(mem_path, "w") as f:
                pixels = list(rgb_img.getdata())
                for i, (r, g, b) in enumerate(pixels):
                    f.write(f"{r:02x}{g:02x}{b:02x}" + ("\n" if (i + 1) % 8 == 0 else " "))
            return True
        except Exception as e:
            print(f"파일 저장 실패: {e}")
            return False

    def process_and_start(self):
        current_num = self.get_next_file_path()
        mem_path = os.path.join('images', f"image_{current_num}.mem")
        filtered_mem_path = os.path.join('images', f"filtered_{current_num}.mem")
        source_img_path = os.path.join('images', f"source_{current_num}.png")
        try:
            # 1. 이미지 처리
            if self.tabs.currentIndex() == 0:
                if not self.upload_img_path:
                    QMessageBox.warning(self, "알림", "이미지를 먼저 로드해주세요.")
                    return
                img = Image.open(self.upload_img_path)
            else:
                qimg = self.paint_canvas.get_image()
                ptr = qimg.bits()
                ptr.setsize(qimg.height() * qimg.width() * 4)
                img = Image.frombuffer("RGBA", (qimg.width(), qimg.height()), ptr, 'raw', "RGBA", 0, 1).convert("RGB")

            img.save(source_img_path)
            print(f"원본 이미지 저장 완료: {source_img_path}")

            if not self.save_as_mem(img, current_num):
                raise Exception("이미지 저장 오류")

            # 2. UI 잠금 및 시리얼 연결
            self.btn_start.setEnabled(False)
            self.btn_start.setText("전송 준비 중...")
            QApplication.processEvents()

            ser = serial.Serial(port=self.target_port, baudrate=115200, timeout=10)

            if ser.is_open:
                time.sleep(3)
                ser.reset_input_buffer()
                ser.reset_output_buffer()

                # [A] 데이터 송신
                print(f"트리거 AA 전송 시작 ({self.target_port})")
                ser.write(bytes.fromhex("AA"))
                ser.flush()
                time.sleep(0.1)  # FPGA가 수신 상태에서 연산 상태로 전환될 시간

                with open(mem_path, 'r') as f:
                    pixels = f.read().split()

                total_pixels = len(pixels)
                for i, hex_val in enumerate(pixels):
                    if len(hex_val) == 6:
                        ser.write(bytes.fromhex(hex_val))
                    if i % 500 == 0:
                        time.sleep(0.001)
                    if (i + 1) % 1000 == 0 or (i + 1) == total_pixels:
                        percent = (i + 1) / total_pixels * 100
                        self.btn_start.setText(f"데이터 송신 중... {percent:.1f}%")
                        QApplication.processEvents()

                # [B] 데이터 수신 대기
                self.btn_start.setText("수신 대기 중...")
                QApplication.processEvents()

                start_wait_time = time.time()
                while ser.in_waiting == 0:
                    if time.time() - start_wait_time > 10:
                        raise Exception("FPGA 응답 없음")
                    QApplication.processEvents()
                    time.sleep(0.01)

                expected_bytes = total_pixels * 3
                received_raw = ser.read(expected_bytes)

                # [C] 수신 데이터를 .mem 파일로 일자 저장
                if len(received_raw) > 0:
                    with open(filtered_mem_path, "w") as f_out:
                        for j in range(0, len(received_raw), 3):
                            chunk = received_raw[j:j + 3]
                            if len(chunk) == 3:
                                # 구분자(공백, 줄바꿈) 없이 16진수 문자열만 기록
                                f_out.write(chunk.hex())

                    print(f"수신 완료: {filtered_mem_path}")

                    # [D] .mem 파일을 읽어 공백 없는 이진수(Binary)로 변환
                    binary_output_path = os.path.join('images', f"filtered_{current_num}_binary.txt")

                    with open(filtered_mem_path, 'r') as f_mem:
                        # 공백이 없으므로 split() 대신 read()로 전체 문자를 가져옴
                        hex_content = f_mem.read()

                    all_bits = []
                    for char in hex_content:
                        try:
                            # 16진수 한 글자(4비트)씩 이진수로 변환
                            decimal_val = int(char, 16)
                            binary_val = bin(decimal_val)[2:].zfill(4)
                            all_bits.append(binary_val)
                        except ValueError:
                            continue

                    # 이진수 결과도 구분자 없이 쭈욱 합쳐서 저장
                    with open(binary_output_path, 'w') as f_bin:
                        f_bin.write("".join(all_bits))

                    print(f"이진 변환 완료: {binary_output_path}")
                    StatusDialog("SUCCESS",
                                 f"데이터 수신 및 일자 나열 변환 완료!\n{binary_output_path}",
                                 self).exec()
                else:
                    raise Exception("데이터 수신 실패")

                ser.close()
            else:
                raise Exception("포트 열기 실패")

        except Exception as e:
            QMessageBox.critical(self, "오류", f"작업 실패: {str(e)}")
        finally:
            self.btn_start.setEnabled(True)
            self.btn_start.setText("전송 시작")


# StatusDialog 및 메인문 코드는 이전과 동일
class StatusDialog(QDialog):
    def __init__(self, title, message, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.Dialog)
        self.setFixedSize(380, 200)
        self.setStyleSheet(style_sheets.STYLE_SHEET)
        layout = QVBoxLayout()
        layout.setContentsMargins(35, 30, 35, 30)
        t_lbl = QLabel(title);
        t_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        t_lbl.setStyleSheet("color: #58a6ff; font-size: 20px; font-weight: bold; border:none;")
        m_lbl = QLabel(message);
        m_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        m_lbl.setStyleSheet("color: #8b949e; font-size: 13px; border:none;")
        btn = QPushButton("확인");
        btn.clicked.connect(self.accept)
        layout.addWidget(t_lbl);
        layout.addWidget(m_lbl);
        layout.addWidget(btn)
        self.setLayout(layout)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    launcher = PortConfigDialog()
    if launcher.exec() == QDialog.DialogCode.Accepted:
        window = MainWindow(launcher.get_port())
        window.show()
        sys.exit(app.exec())