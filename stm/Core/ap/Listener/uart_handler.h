/*
 * uart_handler.h
 *
 *  Created on: Jan 7, 2026
 *      Author: kccistc
 */

#ifndef AP_LISTENER_UART_HANDLER_H_
#define AP_LISTENER_UART_HANDLER_H_

#include "main.h"

// 공유 변수
extern float posX, posY;
extern int posZ;

// 함수 정의
void UART_StartReceive(void);



#endif /* AP_LISTENER_UART_HANDLER_H_ */
