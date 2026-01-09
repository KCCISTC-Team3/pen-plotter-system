/*
 * process_handler.h
 *
 *  Created on: Jan 7, 2026
 *      Author: kccistc
 */

#ifndef AP_LISTENER_PROCESS_HANDLER_H_
#define AP_LISTENER_PROCESS_HANDLER_H_

#include "cmsis_os.h"
#include "usart.h" // huart2 참조용
#include "../Common/types.h"

typedef enum {
    SYS_IDLE_STATE = 0,
    SYS_DRAW_READY_STATE,
    SYS_DRAWING_STATE
} SystemState_t;


// 3. 전역 변수 외부 참조
extern uint8_t data_ready_flag;
extern char rx_buffer[64];

// 4. 함수 프로토타입
void Process_Init(void);
void Process_Main_Loop(void);
void Set_Data_Ready(uint8_t state);
uint8_t Parse_To_Struct(char* buf, coordinate_t* data);


#endif /* AP_LISTENER_PROCESS_HANDLER_H_ */
