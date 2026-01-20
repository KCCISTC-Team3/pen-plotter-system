/*
 * servo.h
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#ifndef DRIVER_SERVO_H_
#define DRIVER_SERVO_H_

#include "tim.h"
#include <stdint.h>

extern TIM_HandleTypeDef htim1;

#define MIN_PULSE  		500 	// 0도
#define CENTER_PULSE	1250	// 90도
#define MAX_PULSE  		2000  	//180도
#define MIN_ANGLE		0 		//최소각도설정
#define MAX_ANGLE  		180 	//최대각도설정

void Servo_Init();
void Servo_SetAngle(uint8_t angle);
void Servo_Set_0();
void Servo_Set_30();
void Servo_Set_60();
void Servo_Set_90();
void Servo_Set_180();
void Servo_Stop();

#endif /* DRIVER_SERVO_H_ */
