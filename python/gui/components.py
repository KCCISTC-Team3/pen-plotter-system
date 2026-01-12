from PyQt6.QtWidgets import QDialog, QVBoxLayout, QLabel, QLineEdit, QPushButton
from PyQt6.QtCore import Qt
import gui.style_sheets as style_sheets


class PortConfigDialog(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("시스템 연결 설정")
        self.setFixedSize(450, 400)
        self.setStyleSheet(style_sheets.STYLE_SHEET)

        layout = QVBoxLayout()
        layout.setContentsMargins(40, 30, 40, 30)
        layout.setSpacing(15)

        # FPGA 포트 입력
        layout.addWidget(QLabel("FPGA Port (이미지 처리):"))
        self.fpga_port = QLineEdit("COM4")
        self.fpga_port.setFixedHeight(35)
        layout.addWidget(self.fpga_port)

        # STM32 포트 입력
        layout.addWidget(QLabel("STM32 Port (모터 제어):"))
        self.stm_port = QLineEdit("COM8")
        self.stm_port.setFixedHeight(35)
        layout.addWidget(self.stm_port)

        layout.addStretch()

        self.btn_connect = QPushButton("연결 정보 저장")
        self.btn_connect.setFixedHeight(50)
        self.btn_connect.clicked.connect(self.accept)
        layout.addWidget(self.btn_connect)

        self.setLayout(layout)

    def get_ports(self):
        return self.fpga_port.text(), self.stm_port.text()


class StatusDialog(QDialog):
    def __init__(self, title, message, parent=None):
        super().__init__(parent)
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.Dialog)
        self.setFixedSize(380, 200)
        self.setStyleSheet(style_sheets.STYLE_SHEET)
        layout = QVBoxLayout()
        layout.setContentsMargins(35, 30, 35, 30)

        t_lbl = QLabel(title)
        t_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        t_lbl.setStyleSheet("color: #58a6ff; font-size: 20px; font-weight: bold; border:none;")

        m_lbl = QLabel(message)
        m_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        m_lbl.setStyleSheet("color: #8b949e; font-size: 13px; border:none;")

        btn = QPushButton("확인")
        btn.clicked.connect(self.accept)

        layout.addWidget(t_lbl)
        layout.addWidget(m_lbl)
        layout.addWidget(btn)
        self.setLayout(layout)