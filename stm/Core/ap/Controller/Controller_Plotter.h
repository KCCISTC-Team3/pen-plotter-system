/*
 * Controller_Plotter.h
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#ifndef AP_CONTROLLER_CONTROLLER_PLOTTER_H_
#define AP_CONTROLLER_CONTROLLER_PLOTTER_H_

//#include <stdbool.h>
#include "../Common/types.h"
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "cmsis_os.h"
#include "FreeRTOS.h"
#include "queue.h"
#include "../../driver/step_motor/step_motor.h"


void Controller_Plotter_Init(); // 처음 좌표 0, 0, 0 설정 , 서보모터 초기화
void Controller_Plotter_Execute(); //큐에서 좌표 디큐, 현재 좌표와 브레젠험 계산, motor_task와 연결된 큐에 motion_t에 맞춰 데이터 enqueue

#define STEPS_PER_MM 20.0f  // 1mm당 스텝 수 (하드웨어에 맞게 수정)
#define ARR_TRAVEL   999   // 이동 시 속도 (작음=빠름)
#define ARR_DRAWING  1499   // 그리기 시 속도
#define START_ARR    4999   // 기동/정지 시 최소 속도

#define MAX_X_LIMIT  250.0f  // X축 제한 (mm)
#define MAX_Y_LIMIT  380.0f  // Y축 제한 (mm)
#define MIN_LIMIT    0.0f    // 최소 제한 (mm)

#endif /* AP_CONTROLLER_CONTROLLER_PLOTTER_H_ */
