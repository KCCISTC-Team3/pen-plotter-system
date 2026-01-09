import os
from PyQt6.QtWidgets import (QMainWindow, QTabWidget, QWidget, QVBoxLayout,
                             QHBoxLayout, QPushButton, QFileDialog, QLabel,
                             QFrame, QApplication, QMessageBox)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QPixmap
from PIL import Image

from gui.painter import PaintCanvas
from gui.components import StatusDialog
import gui.style_sheets as style_sheets
from io_utils.fpga_uart import FPGAUartManager
from io_utils.stm32_uart import STM32UartManager


class MainWindow(QMainWindow):
    def __init__(self, fpga_port, stm_port):  # main.py에서 넘겨준 2개의 포트를 받음
        super().__init__()
        self.TARGET_W, self.TARGET_H = 172, 240

        # 각각의 매니저에 독립된 포트 할당
        self.fpga_manager = FPGAUartManager(fpga_port)
        self.stm_manager = STM32UartManager(stm_port)

        # 해상도 설정
        screen_geo = QApplication.primaryScreen().availableGeometry()
        display_h = int(screen_geo.height() * 0.52)
        self.SCALE = display_h / self.TARGET_H
        self.DISPLAY_W = int(self.TARGET_W * self.SCALE)
        self.DISPLAY_H = display_h

        self.setWindowTitle("펜 플로터 허브")
        self.setStyleSheet(style_sheets.STYLE_SHEET)
        self.upload_img_path = None

        if not os.path.exists('images'): os.makedirs('images')
        self.init_ui()
        self.center_on_screen_top()

    def init_ui(self):
        central_widget = QWidget()
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)

        # Header
        header_frame = QFrame()
        header_frame.setObjectName("header_frame")
        h_layout = QHBoxLayout(header_frame)
        header_title = QLabel("PEN PLOTTER HUB")
        header_title.setObjectName("header_title")
        port_badge = QLabel(f"● FPGA:{self.fpga_manager.port} | STM:{self.stm_manager.port} ACTIVE")
        port_badge.setStyleSheet(
            "color: #3fb950; font-weight: bold; font-size: 11px; background: #21262d; padding: 5px 12px; border-radius: 12px;")
        h_layout.addWidget(header_title)
        h_layout.addStretch()
        h_layout.addWidget(port_badge)
        main_layout.addWidget(header_frame)

        # Tabs
        self.tabs = QTabWidget()
        self.tabs.setFixedSize(self.DISPLAY_W + 60, self.DISPLAY_H + 125)

        # Tab 1: Load Image
        upload_tab = QWidget()
        u_lay = QVBoxLayout(upload_tab)
        self.btn_load = QPushButton("이미지 불러오기")
        self.btn_load.clicked.connect(self.load_image)
        self.label_preview = QLabel("이미지를 로드하세요")
        self.label_preview.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)
        self.label_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.label_preview.setObjectName("preview_area")
        u_lay.addWidget(self.btn_load)
        u_lay.addWidget(self.label_preview, alignment=Qt.AlignmentFlag.AlignCenter)

        # Tab 2: Sketch
        paint_tab = QWidget()
        p_lay = QVBoxLayout(paint_tab)
        self.paint_canvas = PaintCanvas(self.TARGET_W, self.TARGET_H, self.DISPLAY_W, self.DISPLAY_H)
        tool_layout = QHBoxLayout()
        for text, mode in [("펜", "pen"), ("지우개", "eraser"), ("전체 삭제", "clear")]:
            btn = QPushButton(text)
            if mode == "clear":
                btn.clicked.connect(self.paint_canvas.clear_canvas)
            else:
                btn.clicked.connect(lambda ch, m=mode: self.paint_canvas.set_tool(m))
            tool_layout.addWidget(btn)
        p_lay.addLayout(tool_layout)
        p_lay.addWidget(self.paint_canvas, alignment=Qt.AlignmentFlag.AlignCenter)

        self.tabs.addTab(upload_tab, " 이미지 로드 ")
        self.tabs.addTab(paint_tab, " 실시간 스케치 ")

        # Bottom Button
        self.btn_start = QPushButton("전송 및 플로팅 시작")
        self.btn_start.setObjectName("start_btn")
        self.btn_start.setFixedHeight(55)
        self.btn_start.clicked.connect(self.process_and_start)

        content_layout = QVBoxLayout()
        content_layout.setContentsMargins(30, 20, 30, 25)
        content_layout.addWidget(self.tabs, alignment=Qt.AlignmentFlag.AlignCenter)
        content_layout.addWidget(self.btn_start)

        main_layout.addLayout(content_layout)
        self.setCentralWidget(central_widget)

    def center_on_screen_top(self):
        qr = self.frameGeometry()
        cp = QApplication.primaryScreen().availableGeometry().center()

        cp.setY(cp.y() - 200)

        qr.moveCenter(cp)
        self.move(qr.topLeft())

    def load_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, '이미지 선택', '', 'Images (*.png *.jpg *.bmp)')
        if fname:
            self.upload_img_path = fname
            pixmap = QPixmap(fname).scaled(self.DISPLAY_W, self.DISPLAY_H, Qt.AspectRatioMode.KeepAspectRatio)
            self.label_preview.setPixmap(pixmap)

    def process_and_start(self):
        idx = 0
        while os.path.exists(f"images/image_{idx}.mem"): idx += 1

        paths = {
            'mem': f"images/image_{idx}.mem",
            'filtered': f"images/filtered_{idx}.mem",
            'binary': f"images/filtered_{idx}_binary.txt",
            'source': f"images/source_{idx}.png",
            'commands': "out_commands.txt"
        }

        try:
            # [1] 이미지 획득
            if self.tabs.currentIndex() == 0:
                if not self.upload_img_path: raise Exception("이미지를 먼저 로드하세요.")
                img = Image.open(self.upload_img_path)
            else:
                qimg = self.paint_canvas.get_image()
                ptr = qimg.bits()
                ptr.setsize(qimg.height() * qimg.width() * 4)
                img = Image.frombuffer("RGBA", (qimg.width(), qimg.height()), ptr, 'raw', "RGBA", 0, 1).convert("RGB")

            img.save(paths['source'])
            self.btn_start.setEnabled(False)

            # [2] STEP 1: FPGA 통신 (이미지 송신 및 필터 결과 수신)
            self.btn_start.setText("FPGA 데이터 송신 중...")
            QApplication.processEvents()  # UI 갱신

            if self.fpga_manager.save_as_mem(img, paths['mem']):
                def fpga_cb(p):
                    self.btn_start.setText(f"FPGA 처리 중... {p}%")
                    QApplication.processEvents()

                success = self.fpga_manager.process_serial_communication(
                    paths['mem'], paths['filtered'], fpga_cb
                )

                if success:
                    # 수신 완료 후 이진 변환 저장
                    self.fpga_manager.convert_hex_to_binary_text(paths['filtered'], paths['binary'])
                    print("FPGA 수신 및 저장 완료")
                else:
                    raise Exception("FPGA 통신 실패")

            # [3] STEP 2: STM32 통신 (좌표 파일 송신)
            if os.path.exists(paths['commands']):
                self.btn_start.setText("STM32 플로팅 준비 중...")
                QApplication.processEvents()

                def stm_cb(p):
                    self.btn_start.setText(f"STM32 플로팅 중... {p}%")
                    QApplication.processEvents()

                # out_commands.txt를 한 줄씩 보내고 0xBB 기다림
                stm_success = self.stm_manager.send_coordinates_file(paths['commands'], stm_cb)

                if stm_success:
                    StatusDialog("SUCCESS", "이미지 처리 및 플로팅 전송이 완료되었습니다!", self).exec()
                else:
                    raise Exception("STM32 통신 중 오류 발생")
            else:
                QMessageBox.warning(self, "파일 없음", "out_commands.txt가 존재하지 않습니다.")

        except Exception as e:
            QMessageBox.critical(self, "오류", str(e))
        finally:
            self.btn_start.setEnabled(True)
            self.btn_start.setText("전송 및 플로팅 시작")