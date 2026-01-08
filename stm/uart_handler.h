// 저장 경로 Inc

#ifndef __UART_HANDLER_H
#define __UART_HANDLER_H

#include "main.h"

// 공유 변수
extern float posX, posY;
extern int posZ;

// 함수 정의
void UART_StartReceive(void);

#endif
