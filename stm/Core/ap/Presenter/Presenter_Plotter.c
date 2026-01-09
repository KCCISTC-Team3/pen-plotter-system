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

extern osThreadId Motor_TaskHandle;

extern TIM_HandleTypeDef htim1;
extern TIM_HandleTypeDef htim2;
extern osMessageQId Motion_QueueHandle;

ISR_Context_t isr_ctx;

void Presenter_Plotter_Init(osThreadId tid) {
	Motor_TaskHandle = tid;

// 1. Z축 서보 초기화 (TIM1)----------------------------------------
	Servo_Init();
	Servo_Set_0();
//---------------------------------------------------------------

// 2. 스테핑 모터 핀 초기화 ------------------------------------------
//스텝모터 드라이버에서 초기화 코드가져오기
	Step_Init();
//-----------------------------------------------------------------

// 3. 타이머(TIM2) 인터럽트 대기 상태
	__HAL_TIM_SET_AUTORELOAD(&htim2, 4999); // 기본 속도 세팅
}

/**
 * @brief Motion_Queue에서 데이터를 꺼내 실제 구동
 */
void Presenter_Plotter_Execute() {
	motion_t move; // v1에서는 보통 큐를 통해 포인터를 주고받습니다.

	if (xQueueReceive((QueueHandle_t) Motion_QueueHandle, &move,
	portMAX_DELAY) == pdPASS) {

		// 3. Z축 동작 처리
		if (move.z_action) {
			// 서보모터 제어
			if (move.z_state) {
				Servo_Set_0();
				HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5,GPIO_PIN_SET);
			} else {
				Servo_Set_90();
				HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5,GPIO_PIN_SET);
			}
		}

		// 4. XY 이동 처리
		if (move.max_steps > 0) {
			// 방향 핀 설정 (계산된 방향 적용)

			Step_Set_DirPin(&Step_motor_1, move.dir_a);
			Step_Set_DirPin(&Step_motor_2, move.dir_b);

			// Presenter에서 계산된 모든 값을 ISR 컨텍스트로 전송
			isr_ctx.max_steps = move.max_steps;
			isr_ctx.min_steps = move.min_steps;
			isr_ctx.error = move.error;
			isr_ctx.is_a_master = move.is_a_master;
			isr_ctx.current_step = 0; // 스텝 카운터 초기화

			// 가감속 파라미터 전송
			isr_ctx.start_arr = move.start_arr;
			isr_ctx.target_arr = move.target_arr;
			isr_ctx.accel_steps = move.accel_steps;
			isr_ctx.decel_start_step = move.decel_start_step;

			// ---------------------------------------------------------
			// 4. 타이머 기동 (이동 시작)
			// ---------------------------------------------------------
			// 첫 시작 속도(start_arr) 설정

			Step_Set_ARR(move.start_arr);

			// 타이머 인터럽트 활성화 -> 이제부터 HAL_TIM_PeriodElapsedCallback이 호출됨
			Step_Start();

			// 5. 이동 완료 신호 대기 (v1 방식: osSignalWait)
			// 타이머 ISR에서 osSignalSet(motorTaskHandle, 0x01)을 호출할 때까지 대기합니다.
			osSignalWait(0x01, osWaitForever);
		}
	}
}

