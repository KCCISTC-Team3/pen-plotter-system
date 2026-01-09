/*
 * Controller_Plotter.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#include "Controller_Plotter.h"
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "cmsis_os.h"
#include "FreeRTOS.h"
#include "queue.h"

//#include <stdio.h>  // printf, sprintf를 사용하기 위해 필수
//#include <string.h> // strlen을 사용한다면 이것도 필요

extern osMessageQId Cmd_QueueHandle;    // coordinate_t 수신용
extern osMessageQId Motion_QueueHandle; // motion_t 송신용
extern UART_HandleTypeDef huart2; //uart 송신용

static float current_x = 0.0f;
static float current_y = 0.0f;
static int current_z = 1; // 1: Pen Up, 0: Pen Down

void Controller_Plotter_Init() {
	current_x = 0.0f;
	current_y = 0.0f;
	current_z = 1; // Pen Up 상태로 시작
}

void Controller_Plotter_Execute() {
	coordinate_t next_coord;
	motion_t next_motion;
	uint8_t request_code = 0xBB;

//	char debug_buf[64]; // 디버깅용 문자열 버퍼

	if (xQueueReceive((QueueHandle_t) Cmd_QueueHandle, &next_coord,
	portMAX_DELAY) == pdPASS) {

//		printf(debug_buf, "\r\n[Debug] X:%d.%d, Y:%d.%d\r\n",
//				(int) next_coord.x,
//				(int) ((next_coord.x - (int) next_coord.x) * 10),
//				(int) next_coord.y,
//				(int) ((next_coord.y - (int) next_coord.y) * 10));
//		// 변환된 문자열을 UART2로 전송합니다.
//		HAL_UART_Transmit(&huart2, (uint8_t*) debug_buf, strlen(debug_buf),
//				100);
		// 2. XY 거리 계산 및 스텝 변환
		int32_t target_x_steps = (int32_t) (next_coord.x * STEPS_PER_MM);
		int32_t target_y_steps = (int32_t) (next_coord.y * STEPS_PER_MM);
		int32_t curr_x_steps = (int32_t) (current_x * STEPS_PER_MM);
		int32_t curr_y_steps = (int32_t) (current_y * STEPS_PER_MM);

		int32_t dx = target_x_steps - curr_x_steps;
		int32_t dy = target_y_steps - curr_y_steps;

		// 3. 브레젠험 파라미터 및 방향 설정
		int32_t abs_dx = abs(dx);
		int32_t abs_dy = abs(dy);

		next_motion.dir_a = (dx >= 0) ? GPIO_PIN_SET : GPIO_PIN_RESET;
		next_motion.dir_b = (dy >= 0) ? GPIO_PIN_SET : GPIO_PIN_RESET;

		if (abs_dx >= abs_dy) {
			next_motion.is_a_master = true;
			next_motion.max_steps = abs_dx;
			next_motion.min_steps = abs_dy;
		} else {
			next_motion.is_a_master = false;
			next_motion.max_steps = abs_dy;
			next_motion.min_steps = abs_dx;
		}
		next_motion.error = next_motion.max_steps / 2;

		//  Z축 상태 결정
		next_motion.z_state = next_coord.z;  // 차기 Z 상태 (0 or 1)
		next_motion.z_action = (next_coord.z != current_z) ? true : false;

		// ---------------------------------------------------------
		// 5. 속도 및 가감속 설정
		// ---------------------------------------------------------
		uint32_t cruise_arr = (next_coord.z == 1) ? ARR_TRAVEL : ARR_DRAWING;
		next_motion.target_arr = cruise_arr;
		next_motion.start_arr = START_ARR;

		// 가속 구간 설정
		uint32_t ramp_steps = next_motion.max_steps / 3;
		if (ramp_steps > 100)
			ramp_steps = 100;

		next_motion.accel_steps = ramp_steps;
		next_motion.decel_start_step = next_motion.max_steps - ramp_steps;

		// 6. Motion_Queue에 전송
		xQueueSend((QueueHandle_t )Motion_QueueHandle, &next_motion,
				portMAX_DELAY);
		HAL_UART_Transmit(&huart2, &request_code, 1, 10);

		// 현재 좌표 정보 갱신
		current_x = next_coord.x;
		current_y = next_coord.y;
		current_z = next_coord.z;
	}
}
