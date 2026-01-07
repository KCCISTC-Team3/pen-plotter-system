import sys
import os
from PyQt6.QtWidgets import (QApplication, QMainWindow, QTabWidget, QWidget,
                             QVBoxLayout, QHBoxLayout, QPushButton, QFileDialog,
                             QLabel, QLineEdit, QDialog, QMessageBox, QFrame, QSizePolicy)
from PyQt6.QtCore import Qt, QTimer
from PyQt6.QtGui import QPixmap
from PIL import Image

# 사용자 정의 모듈
from painter import PaintCanvas
from serial_comm import SerialHandler
import style_sheets


# 1. 초기 시스템 연결 창
class PortConfigDialog(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("펜 플로터")
        self.setFixedSize(450, 320)
        self.setStyleSheet(style_sheets.STYLE_SHEET)

        layout = QVBoxLayout()
        layout.setContentsMargins(50, 40, 50, 40)
        layout.setSpacing(20)

        title = QLabel("하드웨어 연결")
        title.setObjectName("dialog_title")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.status_label = QLabel("하드웨어 스캔 중...")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.port_input = QLineEdit()
        self.port_input.setText("COM3")
        self.port_input.setAlignment(Qt.AlignmentFlag.AlignCenter)

        self.btn_connect = QPushButton("장치 연결 시작")
        self.btn_connect.setObjectName("connect_btn")
        self.btn_connect.setFixedHeight(50)
        self.btn_connect.clicked.connect(self.handle_connection)

        layout.addWidget(title)
        layout.addWidget(self.status_label)
        layout.addWidget(self.port_input)
        layout.addWidget(self.btn_connect)
        self.setLayout(layout)

    def handle_connection(self):
        self.status_label.setText("연결 시도 중...")
        self.btn_connect.setEnabled(False)
        QTimer.singleShot(800, self.accept)

    def get_port(self):
        return self.port_input.text()


# 2. 메인 제어 인터페이스
class MainWindow(QMainWindow):
    def __init__(self, port):
        super().__init__()
        self.TARGET_W, self.TARGET_H = 643, 907
        screen_geo = QApplication.primaryScreen().availableGeometry()
        display_h = int(screen_geo.height() * 0.52)
        self.SCALE = display_h / self.TARGET_H
        self.DISPLAY_W = int(self.TARGET_W * self.SCALE)
        self.DISPLAY_H = display_h

        self.setWindowTitle("펜 플로터")
        self.setStyleSheet(style_sheets.STYLE_SHEET)

        self.serial_manager = SerialHandler()
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

        # Content Body
        content_layout = QVBoxLayout()
        content_layout.setContentsMargins(30, 20, 30, 25)
        content_layout.setSpacing(15)

        self.tabs = QTabWidget()
        self.tabs.setFixedSize(self.DISPLAY_W + 60, self.DISPLAY_H + 125)

        # TAB 1: SOURCE
        upload_tab = QWidget()
        u_layout = QVBoxLayout(upload_tab)
        u_layout.setContentsMargins(15, 12, 15, 12)
        u_layout.setSpacing(8)
        self.btn_load = QPushButton("이미지 불러오기")
        self.btn_load.setFixedHeight(45)
        self.btn_load.setFixedWidth(self.DISPLAY_W)
        self.btn_load.clicked.connect(self.load_image)
        self.label_preview = QLabel("이미지를 로드하세요")
        self.label_preview.setObjectName("preview_area")
        self.label_preview.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)
        self.label_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
        u_layout.addWidget(self.btn_load, alignment=Qt.AlignmentFlag.AlignCenter)
        u_layout.addWidget(self.label_preview, alignment=Qt.AlignmentFlag.AlignCenter)
        u_layout.addStretch(1)

        # TAB 2: SKETCH
        paint_tab = QWidget()
        p_layout = QVBoxLayout(paint_tab)
        p_layout.setContentsMargins(15, 12, 15, 12)
        p_layout.setSpacing(8)
        self.paint_canvas = PaintCanvas(self.TARGET_W, self.TARGET_H, self.DISPLAY_W, self.DISPLAY_H)

        tool_container = QWidget()
        tool_container.setFixedWidth(self.DISPLAY_W)
        tool_layout = QHBoxLayout(tool_container)
        tool_layout.setContentsMargins(0, 0, 0, 0)
        tool_layout.setSpacing(4)

        tools = [("펜 도구", "pen"), ("지우개", "eraser"), ("전체 삭제", "clear")]
        for text, mode in tools:
            btn = QPushButton(text)
            btn.setFixedHeight(42)
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            if mode == "clear":
                btn.clicked.connect(self.paint_canvas.clear_canvas)
            else:
                btn.clicked.connect(lambda ch, m=mode: self.paint_canvas.set_tool(m))
            tool_layout.addWidget(btn)

        p_layout.addWidget(tool_container, alignment=Qt.AlignmentFlag.AlignCenter)
        p_layout.addWidget(self.paint_canvas, alignment=Qt.AlignmentFlag.AlignCenter)
        p_layout.addStretch(1)

        self.tabs.addTab(upload_tab, " 이미지 로드 ")
        self.tabs.addTab(paint_tab, " 실시간 스케치 ")
        content_layout.addWidget(self.tabs, alignment=Qt.AlignmentFlag.AlignCenter)

        # Bottom Button
        self.btn_start = QPushButton("시작")
        self.btn_start.setObjectName("start_btn")
        self.btn_start.setFixedHeight(55)
        self.btn_start.setFixedWidth(self.DISPLAY_W + 30)
        self.btn_start.clicked.connect(self.process_and_start)
        content_layout.addWidget(self.btn_start, alignment=Qt.AlignmentFlag.AlignCenter)

        main_layout.addLayout(content_layout)
        self.setCentralWidget(central_widget)

    def load_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, '이미지 선택', '', 'Images (*.png *.jpg *.bmp)')
        if fname:
            self.upload_img_path = fname
            pixmap = QPixmap(fname).scaled(self.DISPLAY_W, self.DISPLAY_H, Qt.AspectRatioMode.KeepAspectRatio,
                                           Qt.TransformationMode.SmoothTransformation)
            self.label_preview.setPixmap(pixmap)

    def get_next_file_path(self):
        """images 폴더 내 파일을 확인하여 다음 저장될 파일 번호를 반환"""
        idx = 0
        while True:
            bmp_name = f"image_{idx}.bmp"
            mem_name = f"image_{idx}.mem"
            if not os.path.exists(os.path.join('images', bmp_name)) and \
                    not os.path.exists(os.path.join('images', mem_name)):
                return idx
            idx += 1

    # RGB888 16진수 .mem 파일 생성 함수
    def save_as_mem(self, img_obj, current_num):
        """이미지를 643x907 해상도의 RGB888(24비트) 16진수 .mem 파일로 변환"""
        rgb_img = img_obj.convert("RGB")
        mem_path = os.path.join('images', f"image_{current_num}.mem")

        try:
            with open(mem_path, "w") as f:
                pixels = list(rgb_img.getdata())
                for i, (r, g, b) in enumerate(pixels):
                    # R, G, B 각각 8비트를 2자리 16진수로 변환 (RRGGBB)
                    hex_val = f"{r:02x}{g:02x}{b:02x}"
                    # Verilog $readmemh 가독성을 위해 8개 데이터마다 줄바꿈
                    f.write(hex_val + ("\n" if (i + 1) % 8 == 0 else " "))
            return True
        except Exception as e:
            print(f"MEM 파일 생성 실패: {e}")
            return False

    def process_and_start(self):
        # 중복되지 않는 다음 파일 번호 확인
        current_num = self.get_next_file_path()
        bmp_save_path = os.path.join('images', f"image_{current_num}.bmp")

        try:
            # 1. 이미지 리사이징 및 RGB 변환
            if self.tabs.currentIndex() == 0:
                if not self.upload_img_path:
                    return
                img = Image.open(self.upload_img_path)
            else:
                qimg = self.paint_canvas.get_image()
                ptr = qimg.bits()
                ptr.setsize(qimg.height() * qimg.width() * 4)
                img = Image.frombuffer("RGBA", (qimg.width(), qimg.height()), ptr, 'raw', "RGBA", 0, 1)

            # 공통 프로세스: 타겟 해상도로 리사이징
            img = img.resize((self.TARGET_W, self.TARGET_H), Image.Resampling.LANCZOS).convert("RGB")

            # 2. .bmp 파일 저장 (시각 확인용)
            img.save(bmp_save_path)

            # 3. .mem 16진수 파일 저장 (하드웨어용 RGB888)
            if not self.save_as_mem(img, current_num):
                raise Exception("MEM 파일 생성에 실패했습니다.")

            # 4. 장치 연결 및 전송 (트리거 AA)
            if self.serial_manager.connect(port=self.target_port):
                self.serial_manager.send_start_trigger()

                # 성공 다이얼로그
                StatusDialog("SUCCESS", f"image_{current_num} (.bmp/.mem) 저장 및\n트리거 전송 완료.", self).exec()

                # 5. 화면 초기화
                self.upload_img_path = None
                self.label_preview.clear()
                self.label_preview.setText("이미지를 로드하세요")
                self.paint_canvas.clear_canvas()

            else:
                StatusDialog("FAILURE", "장치 연결 실패.", self).exec()
        except Exception as e:
            QMessageBox.critical(self, "오류", str(e))


# 커스텀 성공 알림창
class StatusDialog(QDialog):
    def __init__(self, title, message, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.Dialog)
        self.setFixedSize(380, 200)
        self.setStyleSheet(style_sheets.STYLE_SHEET)
        layout = QVBoxLayout()
        layout.setContentsMargins(35, 30, 35, 30)
        layout.setSpacing(10)
        t_lbl = QLabel(title)
        t_lbl.setStyleSheet("color: #58a6ff; font-size: 20px; font-weight: bold; border:none;")
        t_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        m_lbl = QLabel(message)
        m_lbl.setStyleSheet("color: #8b949e; font-size: 13px; border:none;")
        m_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        btn = QPushButton("확인")
        btn.setFixedHeight(35)
        btn.setFixedWidth(120)
        btn.clicked.connect(self.accept)
        layout.addWidget(t_lbl)
        layout.addWidget(m_lbl)
        layout.addSpacing(10)
        layout.addWidget(btn, alignment=Qt.AlignmentFlag.AlignCenter)
        self.setLayout(layout)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    launcher = PortConfigDialog()
    if launcher.exec() == QDialog.DialogCode.Accepted:
        window = MainWindow(launcher.get_port())
        window.show()
        sys.exit(app.exec())