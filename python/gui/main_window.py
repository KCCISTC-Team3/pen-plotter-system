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

from config import *
from main_pipeline import run_pipeline


class MainWindow(QMainWindow):
    def __init__(self, fpga_port, stm_port):
        super().__init__()
        # self.TARGET_W, self.TARGET_H = 176, 240
        self.TARGET_W, self.TARGET_H = W, H

        # 매니저 초기화
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
        # 1. 메인 위젯 및 레이아웃 생성
        central_widget = QWidget()
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)

        # 2. Header (포트 정보 표시 등)
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

        # 3. [중요] Tabs 객체를 먼저 생성!
        self.tabs = QTabWidget()
        self.tabs.setFixedSize(self.DISPLAY_W + 60, self.DISPLAY_H + 125)

        # 4. 각 탭의 내용물(위젯)들 구성
        # Tab 1: 이미지 로드
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

        # Tab 2: 실시간 스케치
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

        # Tab 3: 카메라 수신
        self.camera_tab = QWidget()
        c_lay = QVBoxLayout(self.camera_tab)
        self.label_camera_status = QLabel("카메라 탭을 선택하면 수신을 시작합니다.")
        self.label_camera_status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.label_camera_status.setObjectName("preview_area")
        self.label_camera_status.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)
        self.btn_send_camera_stm = QPushButton("STM32로 좌표 전송 시작")
        self.btn_send_camera_stm.setObjectName("start_btn")
        self.btn_send_camera_stm.setFixedHeight(55)
        self.btn_send_camera_stm.setVisible(False)
        self.btn_send_camera_stm.clicked.connect(self.send_camera_commands_to_stm)
        c_lay.addStretch()
        c_lay.addWidget(self.label_camera_status, alignment=Qt.AlignmentFlag.AlignCenter)
        c_lay.addWidget(self.btn_send_camera_stm)
        c_lay.addStretch()

        # 5. 탭 추가
        self.tabs.addTab(upload_tab, " 이미지 로드 ")
        self.tabs.addTab(paint_tab, " 실시간 스케치 ")
        self.tabs.addTab(self.camera_tab, " 카메라 수신 ")

        # 6. [중요] 모든 탭 구성이 끝난 후 이벤트를 연결!
        self.tabs.currentChanged.connect(self.on_tab_changed)

        # 7. 하단 버튼 및 최종 레이아웃 합치기
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

    def _get_next_index(self):
        idx = 0
        while os.path.exists(f"images/image_{idx}.mem") or \
                os.path.exists(f"images/filter_{idx}.mem"):
            idx += 1
        return idx

    def on_tab_changed(self, index):
        """탭이 바뀔 때마다 실행되는 제어 로직"""
        self.fpga_manager.is_receiving = False
        self.btn_send_camera_stm.setVisible(False)
        # 카메라 탭(2번)일 때만 하단 시작 버튼 숨기기
        self.btn_start.setVisible(index != 2)

        if index == 2:
            self.run_camera_mode()

    def run_camera_mode(self):
        idx = self._get_next_index()
        save_path = f"images/filter_{idx}.mem"
        self.label_camera_status.setText("📷 FPGA 데이터 수신 대기 중...")
        QApplication.processEvents()

        success = self.fpga_manager.receive_only_mode(
            save_path,
            lambda p: self.label_camera_status.setText(f"데이터 수신 중... {p}%")
        )

        if success:
            self.label_camera_status.setText(f"✅ 수신 완료!\n파일: {os.path.basename(save_path)}")
            self.btn_send_camera_stm.setVisible(True)
        else:
            if not self.fpga_manager.is_receiving:
                self.label_camera_status.setText("수신이 중단되었습니다.")
            else:
                self.label_camera_status.setText("❌ 수신 오류 발생")

    def send_camera_commands_to_stm(self):
        path = "out_commands.txt"
        if os.path.exists(path):
            self.stm_manager.send_coordinates_file(path,
                                                   lambda p: self.btn_send_camera_stm.setText(f"송신 중... {p}%"))
            StatusDialog("SUCCESS", "플로팅 명령 전송이 완료되었습니다.", self).exec()
            self.btn_send_camera_stm.setText("STM32로 좌표 전송 시작")

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
            'filtered': f"images/filtered_{idx}.txt",
            'binary': f"images/filtered_{idx}_binary.txt",
            'source': f"images/source_{idx}.png",
            'commands': f"images/out_commands_{idx}.txt"
        }

        try:
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

            self.btn_start.setText("FPGA 데이터 송신 중...")
            QApplication.processEvents()

            if self.fpga_manager.save_as_mem(img, paths['mem']):
                def fpga_cb(p):
                    self.btn_start.setText(f"FPGA 처리 중... {p}%")
                    QApplication.processEvents()

                success = self.fpga_manager.process_serial_communication(
                    paths['mem'], paths['filtered'], fpga_cb
                )

                if success:
                    self.fpga_manager.convert_hex_to_binary_text(paths['filtered'], paths['binary'])
                    print("FPGA communication finished")
                else:
                    raise Exception("FPGA communication failed")

            ## Main pipeline runner (Added 01.10.2026)
            if os.path.exists(paths['filtered']):
                self.btn_start.setText("이미지 처리 중...")
                QApplication.processEvents()

                run_pipeline(receive_path=paths['filtered'], command_path=paths['commands'])
                print("main_pipeline runner finished")
            else:
                raise Exception("Text file for main pipeline not found.")
                

            if os.path.exists(paths['commands']):
                self.btn_start.setText("STM32 플로팅 준비 중...")
                QApplication.processEvents()

                def stm_cb(p):
                    self.btn_start.setText(f"STM32 플로팅 중... {p}%")
                    QApplication.processEvents()

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