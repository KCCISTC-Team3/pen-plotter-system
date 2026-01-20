/*
 * Controller_Plotter.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#include "Controller_Plotter.h"

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

	if (xQueueReceive((QueueHandle_t) Cmd_QueueHandle, &next_coord,
	portMAX_DELAY) == pdPASS) {

		// X축 제한
		if (next_coord.x < MIN_LIMIT)
			next_coord.x = MIN_LIMIT;
		if (next_coord.x > MAX_X_LIMIT)
			next_coord.x = MAX_X_LIMIT;

		// Y축 제한
		if (next_coord.y < MIN_LIMIT)
			next_coord.y = MIN_LIMIT;
		if (next_coord.y > MAX_Y_LIMIT)
			next_coord.y = MAX_Y_LIMIT;

		// XY 거리 계산 및 스텝 변환
		int32_t target_x_steps = (int32_t) (next_coord.x * STEPS_PER_MM);
		int32_t target_y_steps = (int32_t) (next_coord.y * STEPS_PER_MM);
		int32_t curr_x_steps = (int32_t) (current_x * STEPS_PER_MM);
		int32_t curr_y_steps = (int32_t) (current_y * STEPS_PER_MM);

		// 브레젠험 파라미터 및 방향 설정
		// 1. 카르테시안 변위 계산 (기존과 동일)
		int32_t dx = target_x_steps - curr_x_steps;
		int32_t dy = target_y_steps - curr_y_steps;

		//  CoreXY 변환 공식 적용
		// 실제 모터 A와 B가 움직여야 할 "상대적인 스텝 수"를 계산합니다.
		int32_t da = dx + dy;
		int32_t db = dy - dx;

		// 브레젠험 파라미터 및 방향 설정
		int32_t abs_da = abs(da);
		int32_t abs_db = abs(db);

		// 모터 A, B 각각의 방향 설정
		next_motion.dir_a = (da >= 0) ? CCW : CW;
		next_motion.dir_b = (db >= 0) ? CCW : CW;

		// 주축(Master) 결정 (A와 B 중 더 많이 움직이는 모터를 기준으로 설정)
		if (abs_da >= abs_db) {
			next_motion.is_a_master = true;  // Motor A가 더 많이 움직임
			next_motion.max_steps = abs_da;
			next_motion.min_steps = abs_db;
		} else {
			next_motion.is_a_master = false; // Motor B가 더 많이 움직임
			next_motion.max_steps = abs_db;
			next_motion.min_steps = abs_da;
		}
		next_motion.error = next_motion.max_steps / 2; // 반올림

		//  Z축 상태 결정
		next_motion.z_state = next_coord.z;  // 차기 Z 상태 (0 or 1)
		next_motion.z_action = (next_coord.z != current_z) ? true : false;

		// ---------------------------------------------------------
		//  속도 및 가감속 설정
		// ---------------------------------------------------------
		uint32_t cruise_arr = (next_coord.z == 1) ? ARR_TRAVEL : ARR_DRAWING;
		next_motion.target_arr = cruise_arr;
		next_motion.start_arr = START_ARR;

		// 가속 구간 설정
		// 1. 가감속 구간을 전체 거리의 일정 비율로 설정 (예: 25%)
		uint32_t ramp_steps = next_motion.max_steps / 4;

		// 2. 100mm/s와 같은 고속 주행에서는 100스텝은 너무 짧습니다.
		// 1200~1500스텝 정도로 상한선을 크게 높여주세요.
		if (ramp_steps > 1200) {
			ramp_steps = 1200;
		}

		next_motion.accel_steps = ramp_steps;
		next_motion.decel_start_step = next_motion.max_steps - ramp_steps;

		///////////////////////////////////////////
		//////////////////////////////////////////

		// 6. Motion_Queue에 전송
		xQueueSend((QueueHandle_t )Motion_QueueHandle, &next_motion,
				portMAX_DELAY);

		// 현재 좌표 정보 갱신
		current_x = next_coord.x;
		current_y = next_coord.y;
		current_z = next_coord.z;
	}
}



