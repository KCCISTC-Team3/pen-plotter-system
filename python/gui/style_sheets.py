STYLE_SHEET = """
    /* 전역 설정: Gmarket Sans 적용 */
    * { 
        font-family: "Gmarket Sans TTF", "Gmarket Sans", "Malgun Gothic", sans-serif; 
        color: #e6edf3;
    }

    QMainWindow, QDialog { 
        background-color: #0d1117; 
    }

    /* 초기 연결창 */
    #dialog_title {
        color: #58a6ff; font-size: 22px; font-weight: bold;
        border-bottom: 2px solid #58a6ff; padding-bottom: 10px;
    }

    #status_label {
        color: #8b949e; font-size: 13px;
    }

    /* 입력창 */
    QLineEdit {
        background-color: #1c2128; border: 1px solid #444c56;
        border-radius: 8px; padding: 10px; color: #ffffff;
        font-size: 14px;
    }

    /* 버튼: 텍스트 잘림 방지를 위해 패딩 조정 */
    QPushButton {
        background-color: #21262d; color: #c9d1d9; border: 1px solid #30363d;
        border-radius: 8px; 
        padding: 2px 5px; /* 상하 패딩을 줄여 글자 공간 확보 */
        font-weight: bold; 
        font-size: 12px;
    }
    QPushButton:hover { background-color: #30363d; border-color: #8b949e; }

    /* 실행 버튼 */
    QPushButton#start_btn {
        background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #238636, stop:1 #2ea043);
        color: white; font-size: 16px; border: none;
    }

    /* 헤더 및 탭 */
    #header_frame { background-color: #161b22; border-bottom: 2px solid #2f81f7; }
    #header_title { color: #2f81f7; font-size: 19px; font-weight: bold; }

    QTabWidget::pane { border: 1px solid #30363d; background: #0d1117; border-radius: 8px; }
    QTabBar::tab {
        background: #161b22; color: #8b949e; padding: 10px 25px; 
        border: 1px solid #30363d; border-bottom: none;
        border-top-left-radius: 8px; border-top-right-radius: 8px; margin-right: 4px;
    }
    QTabBar::tab:selected { background: #0d1117; color: #58a6ff; border-bottom: 2px solid #58a6ff; }

    #preview_area { background-color: #010409; border: 1px solid #30363d; border-radius: 12px; }
"""