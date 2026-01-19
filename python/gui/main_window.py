import os
import numpy as np
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
from PyQt6.QtCore import Qt, QTimer

class MainWindow(QMainWindow):
    def __init__(self, fpga_port, stm_port):
        super().__init__()
        self.TARGET_W, self.TARGET_H = W, H     # Default target size is defined in config.py

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
        camera_tab = QWidget()
        c_lay = QVBoxLayout(camera_tab)

        self.label_camera_status = QLabel("카메라 모드입니다. 트리거 버튼을 누르면 수신을 시작합니다.")
        self.label_camera_status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.label_camera_status.setObjectName("preview_area")
        self.label_camera_status.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)

        # [신규] 카메라 모드 트리거 송신 버튼 - 녹색 스타일
        self.btn_trigger_aa = QPushButton("데이터 수신 시작")
        self.btn_trigger_aa.setObjectName("start_btn")  # 녹색 스타일 적용
        self.btn_trigger_aa.setFixedSize(self.DISPLAY_W + 60, 55)  # 메인 버튼과 동일한 사이즈
        self.btn_trigger_aa.clicked.connect(self.start_camera_trigger)  # 신규 메서드 연결

        self.btn_send_camera_stm = QPushButton("전송 및 플로팅 시작")
        self.btn_send_camera_stm.setObjectName("start_btn")  # 녹색 스타일 적용
        self.btn_send_camera_stm.setFixedSize(self.DISPLAY_W + 60, 55)  # 메인 버튼과 동일한 사이즈
        self.btn_send_camera_stm.setVisible(False)
        self.btn_send_camera_stm.clicked.connect(self.send_camera_commands_to_stm)

        c_lay.addWidget(self.label_camera_status, alignment=Qt.AlignmentFlag.AlignCenter)
        c_lay.addWidget(self.btn_trigger_aa)  # 트리거 버튼 배치
        c_lay.addWidget(self.btn_send_camera_stm)

        # 5. 탭 추가
        self.tabs.addTab(upload_tab, " 이미지 로드 ")
        self.tabs.addTab(paint_tab, " 실시간 스케치 ")
        self.tabs.addTab(camera_tab, " 카메라 모드 ")

        # 6. [중요] 모든 탭 구성이 끝난 후 이벤트를 연결!
        self.tabs.currentChanged.connect(self.on_tab_changed)

        # 7. 하단 버튼 및 최종 레이아웃 합치기
        self.btn_start = QPushButton("전송 및 플로팅 시작")
        self.btn_start.setObjectName("start_btn")
        self.btn_start.setFixedSize(self.DISPLAY_W + 60, 55)  # 탭과 동일한 너비
        self.btn_start.clicked.connect(self.process_and_start)

        content_layout = QVBoxLayout()
        content_layout.setContentsMargins(30, 20, 30, 25)
        content_layout.addWidget(self.tabs, alignment=Qt.AlignmentFlag.AlignCenter)
        content_layout.addWidget(self.btn_start)

        main_layout.addLayout(content_layout)
        self.setCentralWidget(central_widget)

    ## Automatic Image size and canvas management methods

    def _recalc_display_geometry(self):
        """Recalculate DISPLAY_W/H and SCALE based on current TARGET_W/H"""
        screen_geo = QApplication.primaryScreen().availableGeometry()
        display_h = int(screen_geo.height() * 0.52)

        self.SCALE = display_h / self.TARGET_H
        self.DISPLAY_W = int(self.TARGET_W * self.SCALE)
        self.DISPLAY_H = display_h


    def _rebuild_paint_canvas(self):
        """Rebuild the PaintCanvas in the sketch tab based on the current TARGET/DISPLAY sizes"""
        # The paint_tab layout was created as p_lay in init_ui().
        # Find and replace the parent layout containing self.paint_canvas
        parent_layout = self.paint_canvas.parentWidget().layout()

        # Remove and delete the old canvas
        parent_layout.removeWidget(self.paint_canvas)
        self.paint_canvas.setParent(None)
        self.paint_canvas.deleteLater()

        # Create a new canvas
        self.paint_canvas = PaintCanvas(self.TARGET_W, self.TARGET_H, self.DISPLAY_W, self.DISPLAY_H)
        parent_layout.addWidget(self.paint_canvas, alignment=Qt.AlignmentFlag.AlignCenter)


    def _apply_new_target_size(self, w: int, h: int):
        """Update TARGET_W/H and related UI based on image resolution"""
        # Prevent zero/negative values
        if w <= 0 or h <= 0:
            raise ValueError(f"Invalid image size: {w}x{h}")

        self.TARGET_W, self.TARGET_H = w, h
        # print(w, h)
        print(self.TARGET_W, self.TARGET_H)
        self._recalc_display_geometry()

        # Resize tabs and preview areas
        self.tabs.setFixedSize(self.DISPLAY_W + 60, self.DISPLAY_H + 125)
        self.label_preview.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)
        self.label_camera_status.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)

        # Rebuild the sketch canvas
        self._rebuild_paint_canvas()

        # Adjust main window size
        self.adjustSize()



    def _get_next_index(self):
        idx = 0
        while os.path.exists(f"images/image_{idx}.mem") or \
                os.path.exists(f"images/filter_{idx}.txt"):
            idx += 1
        return idx

    def on_tab_changed(self, index):
        """탭이 바뀔 때마다 실행되는 제어 로직"""
        self.fpga_manager.is_receiving = False
        self.btn_send_camera_stm.setVisible(False)
        # 카메라 탭(2번)일 때만 하단 시작 버튼 숨기기
        self.btn_start.setVisible(index != 2)

        if index == 2:
            # 탭 이동 시 수신 대기 상태 안내만 표시
            self.label_camera_status.setText("트리거를 송신하려면 버튼을 누르세요.")
            self.btn_trigger_aa.setEnabled(True)

            # self.run_camera_mode()
            # QTimer.singleShot(200, self.run_camera_mode)

    def start_camera_trigger(self):
        """사용자 버튼 클릭 시 실행: 통합 모드 호출"""
        try:
            self.btn_trigger_aa.setEnabled(False)
            self.label_camera_status.setText("📡 FPGA 트리거 송신 및 수신 시작...")
            QApplication.processEvents()

            # 별도의 송신 없이, 통합 메서드 하나만 호출합니다.
            idx = self._get_next_index()
            save_path = f"images/filter_{idx}.txt"

            # 이 함수 안에서 AA를 쏘고 바로 수신까지 처리합니다.
            def progress_callback(p):
                self.label_camera_status.setText(f"데이터 수신 중... {p}%")
                QApplication.processEvents()  # GUI 업데이트 강제
            
            success = self.fpga_manager.trigger_and_receive_mode(
                save_path,
                progress_callback,
                target_size=(self.TARGET_W * self.TARGET_H)
            )

            if success:
                self.label_camera_status.setText(f"✅ 완료! 파일: {os.path.basename(save_path)}")
                # 카메라 데이터 수신 후 자동으로 경로 최적화 및 STM 전송 준비
                self.process_and_start()
            else:
                raise Exception("통신 실패 또는 타임아웃")

        except Exception as e:
            QMessageBox.critical(self, "통신 에러", str(e))
            self.btn_trigger_aa.setEnabled(True)

    def run_camera_mode(self):
        """FPGA에 트리거(AA)를 송신하고 즉시 데이터를 수신하는 통합 로직"""
        # 버튼 중복 클릭 방지
        self.btn_trigger_aa.setEnabled(False)

        idx = self._get_next_index()
        save_path = f"images/filter_{idx}.txt"

        # 1. 상태 표시 업데이트
        self.label_camera_status.setText("📷 FPGA 트리거 송신 및 수신 대기 중...")
        QApplication.processEvents()

        # 2. [수정 포인트] 통합된 메서드 호출 (AA 송신 + 데이터 수신)
        # 이 내부에서 AA를 쏘고 바로 수신 루프에 진입해야 데이터 유실이 없습니다.
        success = self.fpga_manager.trigger_and_receive_mode(
            save_path,
            lambda p: self.label_camera_status.setText(f"데이터 수신 중... {p}%"),
            target_size=(self.TARGET_W * self.TARGET_H)
        )

        # 3. 결과 처리
        if success:
            with open(save_path, 'r') as f:
                hex_data = f.read().split()
            pixels = [(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)) for h in hex_data]
            img_preview = Image.new("RGB", (self.TARGET_W, self.TARGET_H))
            img_preview.putdata(pixels)

            from PIL.ImageQt import ImageQt
            qimg = ImageQt(img_preview)
            pixmap = QPixmap.fromImage(qimg).scaled(self.DISPLAY_W, self.DISPLAY_H, Qt.AspectRatioMode.KeepAspectRatio)
            self.label_camera_status.setPixmap(pixmap)

            self.label_camera_status.setText(f"✅ 수신 완료!\n파일: {os.path.basename(save_path)}")
            self.process_and_start()
            self.btn_send_camera_stm.setVisible(True)
        else:
            # 타임아웃이나 중단 시 처리
            if not self.fpga_manager.is_receiving:
                self.label_camera_status.setText("수신이 중단되었습니다.")
            else:
                self.label_camera_status.setText("❌ 수신 실패 (타임아웃 또는 보드 무응답)")

            # 실패 시 다시 시도할 수 있도록 버튼 활성화
            self.btn_trigger_aa.setEnabled(True)

    def send_camera_commands_to_stm(self):
        path = "out_commands.txt"
        if os.path.exists(path):
            self.stm_manager.send_coordinates_file(path,
                                                   lambda p: self.btn_send_camera_stm.setText(f"송신 중... {p}%"))
            StatusDialog("SUCCESS", "플로팅 명령 전송이 완료되었습니다.", self).exec()
            self.btn_send_camera_stm.setText("전송 및 플로팅 시작")

    def center_on_screen_top(self):
        qr = self.frameGeometry()
        cp = QApplication.primaryScreen().availableGeometry().center()
        cp.setY(cp.y() - 200)
        qr.moveCenter(cp)
        self.move(qr.topLeft())

    def load_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, '이미지 선택', '', 'Images (*.png *.jpg *.bmp)')
        if not fname:
            return

        try:
            # 1) 이미지 실제 해상도 읽기
            with Image.open(fname) as im:
                w, h = im.size

            # # 2) TARGET/DISPLAY/UI 일괄 갱신
            # self._apply_new_target_size(w, h)

            # 3) 경로 저장 및 프리뷰 표시
            self.upload_img_path = fname
            pixmap = QPixmap(fname).scaled(
                self.DISPLAY_W, self.DISPLAY_H,
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation
            )
            self.label_preview.setPixmap(pixmap)

        except Exception as e:
            QMessageBox.critical(self, "오류", f"이미지 로드 실패: {e}")

    def process_and_start(self):
        idx = 0
        while os.path.exists(f"images/image_{idx}.mem"): idx += 1

        # 절대 경로로 변환하여 명확하게
        base_dir = os.path.abspath('images')
        paths = {
            'mem': os.path.join(base_dir, f"image_{idx}.mem"),
            'filtered': os.path.join(base_dir, f"filtered_{idx}.txt"),  # FPGA 수신 데이터 저장 경로
            'binary': os.path.join(base_dir, f"filtered_{idx}_binary.txt"),
            'source': os.path.join(base_dir, f"source_{idx}.png"),  # FPGA 수신 데이터로부터 생성된 이미지
            'commands': os.path.join(base_dir, f"out_commands_{idx}.txt")
        }

        try:
            if self.tabs.currentIndex() == 0: # 이미지 로드 탭
                if not self.upload_img_path: raise Exception("이미지를 먼저 로드하세요.")
                img = Image.open(self.upload_img_path)
            elif self.tabs.currentIndex() == 1: # 스케치 탭
                qimg = self.paint_canvas.get_image()
                ptr = qimg.bits()
                ptr.setsize(qimg.height() * qimg.width() * 4)
                img = Image.frombuffer("RGBA", (qimg.width(), qimg.height()), ptr, 'raw', "RGBA", 0, 1).convert("RGB")
            elif self.tabs.currentIndex() == 2: # 카메라 수신 탭
                # 카메라 모드: FPGA 전송 건너뛰고 수신한 데이터를 바로 경로 최적화에 사용
                current_idx = self._get_next_index() - 1
                paths['filtered'] = f"images/filter_{current_idx}.txt"
                if not os.path.exists(paths['filtered']):
                    raise Exception("수신된 카메라 데이터 파일이 없습니다.")
                
                # source.png는 선택사항 (디버깅용) - 카메라 데이터로부터 생성
                from io_utils.unpacker import load_hex_txt_to_bytes
                raw_bytes = load_hex_txt_to_bytes(paths['filtered'])
                if len(raw_bytes) >= self.TARGET_W * self.TARGET_H:
                    img_data = raw_bytes[:self.TARGET_W * self.TARGET_H]
                    img_array = np.frombuffer(img_data, dtype=np.uint8).reshape((self.TARGET_H, self.TARGET_W))
                    # 0-255 값을 0 또는 255로 변환
                    img_array = np.where(img_array > 127, 255, 0).astype(np.uint8)
                    img = Image.fromarray(img_array, mode='L').convert('RGB')
                    img.save(paths['source'])
                
                self.btn_start.setEnabled(False)
                self.btn_start.setText("경로 최적화 중...")
                QApplication.processEvents()
                
                # 카메라 데이터는 바로 경로 최적화로 넘기기 (이미지 프로세싱 없음)
                try:
                    run_pipeline(
                        w=self.TARGET_W, 
                        h=self.TARGET_H, 
                        receive_path=paths['filtered'], 
                        command_path=paths['commands'],
                        data_format="byte_per_pixel",  # 카메라 데이터는 픽셀당 1바이트
                        show_visualization=True  # 경로 최적화 결과 시각화
                    )
                    print("main_pipeline runner finished (camera mode)")
                except Exception as e:
                    print(f"run_pipeline error: {e}")
                    import traceback
                    traceback.print_exc()
                    raise
                
                # 카메라 모드일 때는 FPGA 전송 건너뛰고 바로 STM 전송으로
                if os.path.exists(paths['commands']):
                    print(f"Commands file created: {paths['commands']}")
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
                return  # 카메라 모드일 때는 여기서 종료

            print(f"resize: {self.TARGET_W}*{self.TARGET_H}")
            img_resized = img.resize((self.TARGET_W, self.TARGET_H), Image.Resampling.LANCZOS)

            # 원본 이미지는 source.png로 저장하지 않음 (FPGA 수신 데이터로 대체)
            self.btn_start.setEnabled(False)

            self.btn_start.setText("처리 중...")
            QApplication.processEvents()

            ########## FPGA FLOW (Enabled - 0xAA + RGB888 전송 후 수신) ###########
            self.btn_start.setText("FPGA 데이터 송신 중...")
            QApplication.processEvents()

            def fpga_cb(p):
                # p: 0-50% = 송신, 50-100% = 수신
                if p < 50:
                    self.btn_start.setText(f"FPGA 송신 중... {p*2}%")
                else:
                    self.btn_start.setText(f"FPGA 수신 중... {(p-50)*2}%")
                QApplication.processEvents()

            success = self.fpga_manager.send_image_to_fpga(
                img_resized, 
                paths['filtered'], 
                fpga_cb
            )

            if success:
                print("FPGA communication finished (sent 0xAA + RGB888, received 1bpp packed data)")
                
                # FPGA 수신 데이터를 1bpp 패킹에서 언패킹하여 이미지로 변환
                from io_utils.unpacker import load_hex_txt_to_bytes, unpack_payload_to_image, to_img255
                raw_bytes = load_hex_txt_to_bytes(paths['filtered'])
                expected_size = (self.TARGET_W * self.TARGET_H + 7) // 8
                if len(raw_bytes) >= expected_size:
                    payload = raw_bytes[:expected_size]
                    # 1bpp 패킹 언패킹 (0 또는 1 값)
                    img01 = unpack_payload_to_image(payload, self.TARGET_W, self.TARGET_H, bitorder=BITORDER)
                    # 0/1을 0/255로 변환
                    img255 = to_img255(img01)
                    img_received = Image.fromarray(img255, mode='L').convert('RGB')
                    img_received.save(paths['source'])
                    print(f"Source image saved from FPGA received data (1bpp unpacked): {paths['source']}")
            else:
                raise Exception("FPGA communication failed")
            

            ## Main pipeline runner (Added 01.10.2026)
            if os.path.exists(paths['filtered']):
                self.btn_start.setText("이미지 처리 중...")
                QApplication.processEvents()

                # FPGA 수신 데이터는 1bpp 패킹 형식이므로 기본 형식 사용
                run_pipeline(
                    w=self.TARGET_W, 
                    h=self.TARGET_H, 
                    receive_path=paths['filtered'], 
                    command_path=paths['commands'],
                    data_format="1bpp"  # 8픽셀당 1바이트 패킹 형식
                )
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