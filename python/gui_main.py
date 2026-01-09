import sys
from PyQt6.QtWidgets import QApplication, QDialog
from gui.main_window import MainWindow
from gui.components import PortConfigDialog


def main():
    app = QApplication(sys.argv)

    # 1. 포트 설정창 실행
    launcher = PortConfigDialog()

    if launcher.exec() == QDialog.DialogCode.Accepted:
        # 2. 두 개의 포트 정보를 가져옴
        f_port, s_port = launcher.get_ports()

        # 3. 메인 윈도우 생성 및 포트 전달
        window = MainWindow(f_port, s_port)
        window.show()
        sys.exit(app.exec())
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()