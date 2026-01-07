// 저장 경로 Inc


#ifndef __PROCESS_HANDLER_H__
#define __PROCESS_HANDLER_H__

#include "cmsis_os.h"
#include "usart.h" // huart2 참조용

// 1. 좌표 구조체 정의
typedef struct {
    float x;
    float y;
    int z;
} Coord_t;

// 2. 시스템 상태 정의 (중복 방지 명칭)
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
uint8_t Parse_To_Struct(char* buf, Coord_t* data);

#endif
