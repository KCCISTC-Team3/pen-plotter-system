/*
 * Presenter_Plotter.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#include "Presenter_Plotter.h"
#include "tim.h"
#include "queue.h"
#include "FreeRTOS.h"
#include "../../driver/lcd/lcd.h"
#include "i2c.h"
#include "../Common/Common.h"

extern osThreadId Motor_TaskHandle;

extern TIM_HandleTypeDef htim1;
extern TIM_HandleTypeDef htim2;
extern osMessageQId Motion_QueueHandle;
extern UART_HandleTypeDef huart2;
volatile ISR_Context_t isr_ctx;
volatile extern uint8_t kill_flag;

void Presenter_Plotter_Init(osThreadId tid) {
	Motor_TaskHandle = tid;

	LCD_Init(&hi2c1);
	HAL_Delay(500); // 500ms 대기: 초기화 후 내부 회로가 안정될 시간을 줍니다.
	LCD_WriteStringXY(0, 0, "READY");
// 1. Z축 서보 초기화 (TIM1)----------------------------------------
	Servo_Init();
	Servo_Set_30();
	osDelay(200);
// 2. 스테핑 모터 핀 초기화 ------------------------------------------
	Step_Init();
// 3. 타이머(TIM2) 인터럽트 대기 상태
	__HAL_TIM_SET_AUTORELOAD(&htim2, 4999); // 기본 속도 세팅
}

void Presenter_Plotter_Execute() {
    motion_t move;

    // 현재 움직이는 중인지 기억하는 변수 (static 필수)
    static bool is_active = false;

    // 1. Kill Flag 체크 (최우선)
    if (kill_flag) {
         LCD_WriteStringXY(0, 0, "STOP! KILL SW   "); // 공백으로 뒤까지 싹 지움
         is_active = false; // 멈췄으므로 활동 상태 해제
         osDelay(100);
         // 큐 비우기 등의 추가 처리가 필요하다면 여기서 수행
         return;
    }

    // 2. 큐 데이터 수신 (100ms만 기다림 - 중요!)
    // portMAX_DELAY 대신 100을 써야 데이터가 끊겼을 때 FINISH를 띄울 수 있음
    if (xQueueReceive((QueueHandle_t) Motion_QueueHandle, &move, 100) == pdPASS) {

        // 데이터가 들어왔으니 움직임 표시
        if (!is_active) {
            LCD_WriteStringXY(0, 0, "Moving...       "); // 16글자 꽉 채움 (잔상 제거)
            is_active = true;
        }

        uint8_t request_code = 0xBB;
        HAL_UART_Transmit(&huart2, &request_code, 1, 10);

        // Z축 동작 처리
        if (move.z_action) {
            if (move.z_state) Servo_Set_30();
            else Servo_Set_0();
            osDelay(200);
        }

        // XY 이동 처리
        if (move.max_steps > 0) {
            Step_Set_DirPin(&Step_motor_1, move.dir_a);
            Step_Set_DirPin(&Step_motor_2, move.dir_b);

            isr_ctx.max_steps = move.max_steps;
            isr_ctx.min_steps = move.min_steps;
            isr_ctx.error = move.error;
            isr_ctx.is_a_master = move.is_a_master;
            isr_ctx.current_step = 0;
            isr_ctx.start_arr = move.start_arr;
            isr_ctx.target_arr = move.target_arr;
            isr_ctx.accel_steps = move.accel_steps;
            isr_ctx.decel_start_step = move.decel_start_step;

            Step_Set_ARR(move.start_arr);
            Step_Start();

            // 완료(0x01) 또는 비상정지(0x02) 대기
            osEvent evt = osSignalWait(0x01 | 0x02, osWaitForever);

            if ((evt.value.signals & 0x02) || (kill_flag == 1)) {
                LCD_WriteStringXY(0, 0, "STOP! KILL SW   ");
                kill_flag = 1;
                is_active = false;
            }
            // 정상 완료 시에는 LCD를 건드리지 않음 (연속 동작 시 깜빡임 방지)
            // 루프가 돌아서 데이터가 없으면 아래 else문에서 FINISH 처리함
        }
    }
    else {
        // [타임아웃 발생] 100ms 동안 새 명령이 없음 -> 동작 완료로 간주
        if (is_active && kill_flag == 0) {
            LCD_WriteStringXY(0, 0, "FINISH          "); // 공백 채움
            is_active = false; // 상태 초기화
        }

        // 이미 FINISH 상태라면 아무것도 안 하고 대기 (화면 유지)
    }
}
