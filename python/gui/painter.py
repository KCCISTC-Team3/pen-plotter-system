from PyQt6.QtWidgets import QWidget
from PyQt6.QtGui import QPainter, QPen, QImage
from PyQt6.QtCore import Qt, QPoint, QRect


class PaintCanvas(QWidget):
    def __init__(self, target_w, target_h, display_w, display_h):
        super().__init__()
        self.base_w, self.base_h = target_w, target_h
        # 실제 데이터 해상도 (643x907)
        self.image = QImage(self.base_w, self.base_h, QImage.Format.Format_RGB32)
        self.image.fill(Qt.GlobalColor.white)

        # 화면 표시 크기 및 배율 설정
        self.setFixedSize(display_w, display_h)
        self.scale_x = display_w / self.base_w
        self.scale_y = display_h / self.base_h

        self.last_point = QPoint()
        self.tool_mode = 'pen'

    # 전체 지우기 기능
    def clear_canvas(self):
        self.image.fill(Qt.GlobalColor.white)
        self.update()

    def set_tool(self, mode):
        self.tool_mode = mode

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            x = int(event.position().x() / self.scale_x)
            y = int(event.position().y() / self.scale_y)
            self.last_point = QPoint(x, y)

    def mouseMoveEvent(self, event):
        if event.buttons() & Qt.MouseButton.LeftButton:
            painter = QPainter(self.image)

            if self.tool_mode == 'pen':
                color = Qt.GlobalColor.black
                size = 1
            else:  # 지우개 모드
                color = Qt.GlobalColor.white
                size = 30  # 지우개는 좀 더 크게 설정

            painter.setPen(QPen(color, size, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))

            x = int(event.position().x() / self.scale_x)
            y = int(event.position().y() / self.scale_y)
            curr_point = QPoint(x, y)

            painter.drawLine(self.last_point, curr_point)
            self.last_point = curr_point
            self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        painter.drawImage(self.rect(), self.image)

    def get_image(self):
        return self.image