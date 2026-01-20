/*
 * servo.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */
#include "servo.h"

void Servo_Init() {
	HAL_TIM_PWM_Start(&htim1, TIM_CHANNEL_1);
}

void Servo_SetAngle(uint8_t angle) {
	uint32_t pulse;

	if (angle < MIN_ANGLE) {
		angle = 0;
	} else if (angle > MAX_ANGLE) {
		angle = 180;
	}

	pulse = 500 + (angle * 2000 / 180);
	__HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, pulse);
}

void Servo_Set_0() {
	Servo_SetAngle(0);
}

void Servo_Set_30(){
	Servo_SetAngle(30);
}

void Servo_Set_60(){
	Servo_SetAngle(60);
}

void Servo_Set_90() {
	Servo_SetAngle(90);
}

void Servo_Set_180() {
	Servo_SetAngle(180);
}

void Servo_Stop() {
	HAL_TIM_PWM_Stop(&htim1, TIM_CHANNEL_1);
}
