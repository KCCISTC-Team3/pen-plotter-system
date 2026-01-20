import os
from PyQt6.QtWidgets import (QMainWindow, QTabWidget, QWidget, QVBoxLayout,
                             QHBoxLayout, QPushButton, QFileDialog, QLabel,
                             QFrame, QApplication, QMessageBox, QProgressBar)
from PyQt6.QtGui import QPixmap, QImage
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
        self.TARGET_W, self.TARGET_H = W, H

        self.fpga_manager = FPGAUartManager(fpga_port)
        self.stm_manager = STM32UartManager(stm_port)

        # --- [수정] 해상도 설정: 화면 전체 크기를 가져옵니다 ---
        screen_geo = QApplication.primaryScreen().availableGeometry()

        # 헤더와 하단 버튼 공간을 제외한 실제 콘텐츠 높이 계산 (여유값 증가: 280px)
        available_h = screen_geo.height() - 280  # 220 -> 280으로 증가
        available_w = screen_geo.width() - 100

        # 이미지 비율을 유지하면서 화면에 꽉 차도록 배율 계산
        scale_w = available_w / self.TARGET_W
        scale_h = available_h / self.TARGET_H
        self.SCALE = min(scale_w, scale_h) * 0.9  # 0.9 배율 적용하여 여유 공간 확보

        self.DISPLAY_W = int(self.TARGET_W * self.SCALE)
        self.DISPLAY_H = int(self.TARGET_H * self.SCALE)
        # --------------------------------------------------

        self.setWindowTitle("펜 플로터 허브")
        self.setStyleSheet(style_sheets.STYLE_SHEET)
        self.upload_img_path = None

        if not os.path.exists('images'): os.makedirs('images')

        self.init_ui()
        self.showMaximized()

    def init_ui(self):
        # 1. 메인 위젯 및 가로 레이아웃 생성
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_h_layout = QHBoxLayout(central_widget)
        main_h_layout.setContentsMargins(10, 10, 10, 10)
        main_h_layout.setSpacing(20)

        # --- [좌측 영역] 제어 패널 (비율 1) ---
        left_container = QWidget()
        left_layout = QVBoxLayout(left_container)
        left_layout.setContentsMargins(0, 0, 0, 0)
        left_layout.setSpacing(10)

        # [좌측 헤더]
        left_header = QFrame()
        left_header.setObjectName("header_frame")
        left_header.setFixedHeight(70)
        lh_lay = QHBoxLayout(left_header)
        lh_lay.setContentsMargins(20, 0, 20, 0)

        header_title = QLabel("PEN PLOTTER HUB")
        header_title.setObjectName("header_title")
        header_title.setStyleSheet("font-size: 25px; font-weight: bold; color: #58a6ff; border: none;")

        lh_lay.addWidget(header_title)
        left_layout.addWidget(left_header)

        # [좌측 탭 버튼 영역] - 너비 일치화
        self.tabs = QTabWidget()
        self.tabs.setFixedSize(self.DISPLAY_W + 60, self.DISPLAY_H + 130)

        # Tab 1: 이미지 로드
        upload_tab = QWidget()
        u_lay = QVBoxLayout(upload_tab)
        self.btn_load = QPushButton("이미지 불러오기")
        self.btn_load.setStyleSheet("font-size: 20px; font-weight: bold;")
        self.btn_load.setFixedHeight(45)
        self.btn_load.clicked.connect(self.load_image)

        # === [NEW] 진행률 표시 로딩바 추가 ===
        self.progress_bar = QProgressBar()
        self.progress_bar.setFixedHeight(25)
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        self.progress_bar.setTextVisible(True)
        self.progress_bar.setFormat("대기 중")
        self.progress_bar.setStyleSheet("""
            QProgressBar {
                border: 2px solid #30363d;
                border-radius: 5px;
                background-color: #161b22;
                text-align: center;
                color: #ffffff;
                font-size: 14px;
                font-weight: bold;
            }
            QProgressBar::chunk {
                border-radius: 3px;
            }
        """)
        self.progress_bar.setVisible(False)  # 초기에는 숨김

        self.label_preview = QLabel("이미지를 로드하세요")
        self.label_preview.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)
        self.label_preview.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.label_preview.setObjectName("preview_area")
        self.paint_canvas = PaintCanvas(self.TARGET_W, self.TARGET_H, self.DISPLAY_W, self.DISPLAY_H)
        
        u_lay.addWidget(self.btn_load)
        u_lay.addWidget(self.progress_bar)  # 로딩바 추가
        u_lay.addWidget(self.label_preview, alignment=Qt.AlignmentFlag.AlignCenter)

        # Tab 2: 실시간 스케치
        paint_tab = QWidget()
        p_lay = QVBoxLayout(paint_tab)
        p_lay.setSpacing(15)

        # 1. 스케치 도구 버튼 영역
        tool_lay = QHBoxLayout()
        for text, mode in [("펜", "pen"), ("지우개", "eraser"), ("전체 삭제", "clear")]:
            btn = QPushButton(text)
            btn.setFixedHeight(45)
            btn.setStyleSheet("font-size: 20px; font-weight: bold;") 
            
            if mode == "clear":
                btn.clicked.connect(self.paint_canvas.clear_canvas)
            else:
                btn.clicked.connect(lambda ch, m=mode: self.paint_canvas.set_tool(m))
            tool_lay.addWidget(btn)

        # 스케치 탭 로딩바 추가
        self.progress_bar_sketch = QProgressBar()
        self.progress_bar_sketch.setFixedHeight(25)
        self.progress_bar_sketch.setRange(0, 100)
        self.progress_bar_sketch.setValue(0)
        self.progress_bar_sketch.setTextVisible(True)
        self.progress_bar_sketch.setFormat("대기 중")
        self.progress_bar_sketch.setStyleSheet("""
            QProgressBar {
                border: 2px solid #30363d;
                border-radius: 5px;
                background-color: #161b22;
                text-align: center;
                color: #ffffff;
                font-size: 14px;
                font-weight: bold;
            }
            QProgressBar::chunk {
                border-radius: 3px;
            }
        """)
        self.progress_bar_sketch.setVisible(False)

        self.paint_canvas.setObjectName("preview_area") 
        
        p_lay.addLayout(tool_lay)
        p_lay.addWidget(self.progress_bar_sketch)
        p_lay.addWidget(self.paint_canvas, alignment=Qt.AlignmentFlag.AlignCenter)

        # Tab 3: 카메라 수신
        camera_tab = QWidget()
        c_lay = QVBoxLayout(camera_tab)
        c_lay.setSpacing(15)

        # 카메라 탭 로딩바 추가
        self.progress_bar_camera = QProgressBar()
        self.progress_bar_camera.setFixedHeight(25)
        self.progress_bar_camera.setRange(0, 100)
        self.progress_bar_camera.setValue(0)
        self.progress_bar_camera.setTextVisible(True)
        self.progress_bar_camera.setFormat("대기 중")
        self.progress_bar_camera.setStyleSheet("""
            QProgressBar {
                border: 2px solid #30363d;
                border-radius: 5px;
                background-color: #161b22;
                text-align: center;
                color: #ffffff;
                font-size: 14px;
                font-weight: bold;
            }
            QProgressBar::chunk {
                border-radius: 3px;
            }
        """)
        self.progress_bar_camera.setVisible(False)

        self.label_camera_status = QLabel("카메라 데이터 대기 중...")
        self.label_camera_status.setObjectName("preview_area")
        self.label_camera_status.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)
        self.label_camera_status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.label_camera_status.setStyleSheet("font-size: 25px; font-weight: bold; color: #8b949e; border: none;")

        c_lay.addWidget(self.progress_bar_camera)
        c_lay.addWidget(self.label_camera_status, alignment=Qt.AlignmentFlag.AlignCenter)
        
        # --- 탭 추가 및 레이아웃 배치 ---
        self.tabs = QTabWidget()
        
        self.tabs.setUsesScrollButtons(False)
        self.tabs.tabBar().setExpanding(True)
        self.tabs.tabBar().setDocumentMode(True)

        total_width = self.DISPLAY_W + 60
        tab_width = (total_width // 3) - 2 
        
        self.tabs.setStyleSheet(f"""
            QTabBar::tab {{
                font-size: 18px; 
                font-weight: bold; 
                width: {tab_width}px;
                height: 50px; 
                color: #adbac7;
                background-color: #161b22;
                border: 1px solid #30363d;
                margin: 0;
            }}
            QTabBar::tab:selected {{
                color: #58a6ff;
                background-color: #0d1117;
                border-bottom: 2px solid #58a6ff;
            }}
        """)

        self.tabs.addTab(upload_tab, "이미지")
        self.tabs.addTab(paint_tab, "스케치")
        self.tabs.addTab(camera_tab, "카메라")

        left_layout.addWidget(self.tabs)

        # 하단 메인 시작 버튼
        self.btn_start = QPushButton("전송 및 플로팅 시작")
        self.btn_start.setObjectName("start_btn")
        self.btn_start.setFixedHeight(60)
        self.btn_start.setStyleSheet("font-size: 25px; font-weight: bold; background-color: #238636;")
        self.btn_start.clicked.connect(self.process_and_start)
        
        left_layout.addWidget(self.btn_start)
        left_layout.addStretch()

        # --- [우측 영역] 결과 표시창 (비율 2) ---
        right_container = QWidget()
        right_layout = QVBoxLayout(right_container)
        right_layout.setContentsMargins(0, 0, 0, 0)
        right_layout.setSpacing(10)

        # [우측 헤더]
        right_header = QFrame()
        right_header.setObjectName("header_frame")
        right_header.setFixedHeight(70)
        rh_lay = QHBoxLayout(right_header)
        rh_lay.setContentsMargins(20, 0, 20, 0)

        right_title = QLabel("PROCESS MONITORING VIEW")
        right_title.setObjectName("header_title")
        right_title.setStyleSheet("font-size: 25px; font-weight: bold; color: #58a6ff;")

        rh_lay.addWidget(right_title)
        rh_lay.addStretch()
        right_layout.addWidget(right_header)

        # [결과물 전용 프레임 틀]
        self.result_frame = QFrame()
        self.result_frame.setObjectName("preview_area")
        self.result_frame.setStyleSheet("border: 2px solid #30363d; border-radius: 10px; background-color: #0d1117;")
        rf_lay = QVBoxLayout(self.result_frame)

        self.label_result = QLabel("프로세스 결과가 여기에 표시됩니다")
        self.label_result.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.label_result.setStyleSheet("color: #8b949e; font-size: 25px; border: none;")

        rf_lay.addWidget(self.label_result)
        right_layout.addWidget(self.result_frame, 1)

        main_h_layout.addWidget(left_container, 1)
        main_h_layout.addWidget(right_container, 2)
        
    def update_progress(self, value, message="", bar=None):
        """진행률 업데이트 헬퍼 함수 - 무지개색 그라데이션"""
        # bar가 지정되지 않으면 현재 탭에 맞는 로딩바 자동 선택
        if bar is None:
            current_tab = self.tabs.currentIndex()
            if current_tab == 0:
                bar = self.progress_bar
            elif current_tab == 1:
                bar = self.progress_bar_sketch
            elif current_tab == 2:
                bar = self.progress_bar_camera
            else:
                return
        
        bar.setValue(value)
        
        # 진행률에 따른 무지개색 계산 (0-100% -> 빨주노초파남보)
        if value < 16:  # 빨강 -> 주황
            r, g, b = 255, int(value * 255 / 16), 0
        elif value < 33:  # 주황 -> 노랑
            r, g, b = 255, 255, 0
        elif value < 50:  # 노랑 -> 초록
            r, g, b = int(255 - (value - 33) * 255 / 17), 255, 0
        elif value < 66:  # 초록 -> 청록
            r, g, b = 0, 255, int((value - 50) * 255 / 16)
        elif value < 83:  # 청록 -> 파랑
            r, g, b = 0, int(255 - (value - 66) * 255 / 17), 255
        else:  # 파랑 -> 보라
            r, g, b = int((value - 83) * 255 / 17), 0, 255
        
        # 동적으로 스타일시트 업데이트
        bar.setStyleSheet(f"""
            QProgressBar {{
                border: 2px solid #30363d;
                border-radius: 5px;
                background-color: #161b22;
                text-align: center;
                color: #ffffff;
                font-size: 14px;
                font-weight: bold;
            }}
            QProgressBar::chunk {{
                background-color: rgb({r}, {g}, {b});
                border-radius: 3px;
            }}
        """)
        
        if message:
            bar.setFormat(f"{message} ({value}%)")
        else:
            bar.setFormat(f"{value}%")
        QApplication.processEvents()

    def _recalc_display_geometry(self):
        """Recalculate DISPLAY_W/H and SCALE based on current TARGET_W/H"""
        screen_geo = QApplication.primaryScreen().availableGeometry()
        display_h = int(screen_geo.height() * 0.45)  # 0.52 -> 0.45로 축소

        self.SCALE = display_h / self.TARGET_H
        self.DISPLAY_W = int(self.TARGET_W * self.SCALE)
        self.DISPLAY_H = display_h

    def _rebuild_paint_canvas(self):
        """Rebuild the PaintCanvas in the sketch tab based on the current TARGET/DISPLAY sizes"""
        parent_layout = self.paint_canvas.parentWidget().layout()

        parent_layout.removeWidget(self.paint_canvas)
        self.paint_canvas.setParent(None)
        self.paint_canvas.deleteLater()

        self.paint_canvas = PaintCanvas(self.TARGET_W, self.TARGET_H, self.DISPLAY_W, self.DISPLAY_H)
        parent_layout.addWidget(self.paint_canvas, alignment=Qt.AlignmentFlag.AlignCenter)

    def _apply_new_target_size(self, w: int, h: int):
        """Update TARGET_W/H and related UI based on image resolution"""
        if w <= 0 or h <= 0:
            raise ValueError(f"Invalid image size: {w}x{h}")

        self.TARGET_W, self.TARGET_H = w, h
        print(self.TARGET_W, self.TARGET_H)
        self._recalc_display_geometry()

        self.tabs.setFixedSize(self.DISPLAY_W + 60, self.DISPLAY_H + 125)
        self.label_preview.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)
        self.label_camera_status.setFixedSize(self.DISPLAY_W, self.DISPLAY_H)

        self._rebuild_paint_canvas()
        self.adjustSize()

    def _get_next_index(self):
        idx = 0
        while os.path.exists(f"images/image_{idx}.mem") or \
                os.path.exists(f"images/filter_{idx}.mem"):
            idx += 1
        return idx

    def on_tab_changed(self, index):
        """탭이 바뀔 때마다 실행되는 제어 로직"""
        self.fpga_manager.is_receiving = False
        # 버튼이 항상 표시되도록 강제 설정
        self.btn_start.setVisible(True)
        self.btn_start.setEnabled(True)
        self.btn_start.setText("전송 및 플로팅 시작")

        # 카메라 탭으로 전환 시 상태 메시지만 변경
        if index == 2:
            self.label_camera_status.setText("'전송 및 플로팅 시작' 버튼을 눌러 카메라 데이터를 수신하세요.")

    def start_camera_trigger(self):
        """사용자 버튼 클릭 시 실행: 통합 모드 호출 - 더 이상 사용하지 않음"""
        pass

    def run_camera_mode(self):
        """FPGA에 트리거(AA)를 송신하고 즉시 데이터를 수신하는 통합 로직 - 더 이상 사용하지 않음"""
        pass

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
        if not fname:
            return

        try:
            with Image.open(fname) as im:
                w, h = im.size

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
        # 현재 탭에 맞는 로딩바 선택 및 표시
        current_tab = self.tabs.currentIndex()
        if current_tab == 0:
            current_bar = self.progress_bar
        elif current_tab == 1:
            current_bar = self.progress_bar_sketch
        elif current_tab == 2:
            current_bar = self.progress_bar_camera
        else:
            current_bar = self.progress_bar
        
        # 진행률 바 표시 및 초기화
        current_bar.setVisible(True)
        self.update_progress(0, "준비 중", current_bar)
        
        self.btn_start.setEnabled(False)
        self.btn_start.setText("처리 중...")
        QApplication.processEvents()
        
        idx = 0
        while os.path.exists(f"images/image_{idx}.mem"):
            idx += 1

        paths = {
            'mem': f"images/image_{idx}.mem",
            'filtered': f"images/05_canny_packed_1bpp_hex_{idx}.txt",
            'binary': f"images/filtered_{idx}_binary.txt",
            'source': f"images/source_{idx}.png",
            'commands': f"images/out_commands_{idx}.txt"
        }

        try:
            # 카메라 탭인 경우 먼저 FPGA에서 데이터 수신
            if self.tabs.currentIndex() == 2:
                self.update_progress(5, "FPGA 트리거 송신", current_bar)
                self.label_camera_status.setText("📷 FPGA 트리거 송신 및 수신 대기 중...")
                QApplication.processEvents()
                
                save_path = f"images/filter_{idx}.mem"
                
                success = self.fpga_manager.trigger_and_receive_mode(
                    save_path,
                    lambda p: self.label_camera_status.setText(f"데이터 수신 중... {p}%"),
                    target_size=(self.TARGET_W * self.TARGET_H)
                )
                
                if not success:
                    if not self.fpga_manager.is_receiving:
                        raise Exception("수신이 중단되었습니다.")
                    else:
                        raise Exception("수신 실패 (타임아웃 또는 보드 무응답)")
                
                # 수신된 데이터를 이미지로 변환하여 표시
                with open(save_path, 'r') as f:
                    hex_data = f.read().split()
                pixels = [(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)) for h in hex_data]
                img = Image.new("RGB", (self.TARGET_W, self.TARGET_H))
                img.putdata(pixels)
                
                from PIL.ImageQt import ImageQt
                qimg = ImageQt(img)
                pixmap = QPixmap.fromImage(qimg).scaled(self.DISPLAY_W, self.DISPLAY_H, Qt.AspectRatioMode.KeepAspectRatio)
                self.label_camera_status.setPixmap(pixmap)
                
            self.update_progress(10, "이미지 로딩", current_bar)
            
            # 현재 선택된 탭에 따라 이미지 소스 가져오기
            if self.tabs.currentIndex() == 0:
                if not self.upload_img_path:
                    raise Exception("이미지를 먼저 로드하세요.")
                img = Image.open(self.upload_img_path)
            elif self.tabs.currentIndex() == 1:
                qimg = self.paint_canvas.get_image()
                ptr = qimg.bits()
                ptr.setsize(qimg.height() * qimg.width() * 4)
                img = Image.frombuffer("RGBA", (qimg.width(), qimg.height()), ptr, 'raw', "RGBA", 0, 1).convert("RGB")
            elif self.tabs.currentIndex() == 2:
                # 카메라 탭의 경우 이미 위에서 img 생성됨
                pass

            self.update_progress(20, "리사이징", current_bar)
            print(f"이미지 리사이징 중: {self.TARGET_W}*{self.TARGET_H} -> 176*240")
            img_resized = img.resize((176, 240), Image.Resampling.LANCZOS)
            img_resized.save(paths['source'])

            self.update_progress(35, "필터 처리", current_bar)
            self.btn_start.setText("이미지 처리 중...")
            QApplication.processEvents()

            from image_processing.filtered_hex_img_gen import process_and_save
            process_and_save(
                paths['source'],
                out_dir="images",
                idx=idx,
                gaussian_ksize=5,
                gaussian_sigma=1.0,
                sobel_ksize=3,
                canny_low=50,
                canny_high=150,
                hex_mode="stream",
                save_packed_1bpp=True,
            )

            self.update_progress(55, "경로 최적화", current_bar)
            if os.path.exists(paths['filtered']):
                self.btn_start.setText("경로 최적화 중...")
                QApplication.processEvents()

                combined_arr = run_pipeline(
                    w=self.TARGET_W,
                    h=self.TARGET_H,
                    receive_path=paths['filtered'],
                    command_path=paths['commands']
                )

                self.update_progress(75, "결과 생성", current_bar)
                if combined_arr is not None:
                    import cv2
                    from PyQt6.QtGui import QImage

                    rgb_image = cv2.cvtColor(combined_arr, cv2.COLOR_BGR2RGB)
                    h, w, ch = rgb_image.shape
                    bytes_per_line = ch * w
                    qt_img = QImage(rgb_image.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)

                    self.label_result.setPixmap(QPixmap.fromImage(qt_img).scaled(
                        self.label_result.width() - 40,
                        self.label_result.height() - 40,
                        Qt.AspectRatioMode.KeepAspectRatio,
                        Qt.TransformationMode.SmoothTransformation
                    ))
                    self.label_result.setText("")
            else:
                raise Exception("이미지 처리 결과 파일(.txt)을 찾을 수 없습니다.")

            self.update_progress(85, "플로팅 전송", current_bar)
            if os.path.exists(paths['commands']):
                self.btn_start.setText("STM32 플로팅 준비 중...")
                QApplication.processEvents()

                def stm_cb(p):
                    # STM 전송 진행률을 85%~100% 범위로 매핑
                    mapped_progress = 85 + int(p * 0.15)
                    self.update_progress(mapped_progress, f"플로팅 전송", current_bar)
                    self.btn_start.setText(f"STM32 플로팅 중... {p}%")
                    QApplication.processEvents()

                stm_success = self.stm_manager.send_coordinates_file(paths['commands'], stm_cb)

                if stm_success:
                    self.update_progress(100, "완료", current_bar)
                    StatusDialog("SUCCESS", "플로팅 완료!", self).exec()

        except Exception as e:
            current_bar.setVisible(False)
            QMessageBox.critical(self, "오류", str(e))
        
        finally:
            # 작업 완료 후 로딩바 숨김 및 버튼 복구
            QTimer.singleShot(1000, lambda: current_bar.setVisible(False))
            
            # 버튼 상태 복구 (실종 방지)
            self.btn_start.setEnabled(True)
            self.btn_start.setText("전송 및 플로팅 시작")
            self.btn_start.setVisible(True)  # 명시적으로 표시
            self.btn_start.show()  # show() 메서드도 호출
            self.btn_start.raise_()  # 위젯을 최상위로 올림
            QApplication.processEvents()