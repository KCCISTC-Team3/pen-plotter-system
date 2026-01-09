/*
 * Survo.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */


#include "Survo.h"

static uint8_t isInit = 0;
static uint8_t cur_angle = 90;

void Survo_Init()
{
	if(isInit) return;

	__HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, CENTER_PULSE);
	HAL_TIM_PWM_Start(&htim1, TIM_CHANNEL_1);

	isInit = 1;
	cur_angle = 90;
}

void Survo_SetAngle(uint8_t angle)
{
	uint32_t pulse;

	if (!isInit) return;

	if (angle > MAX_ANGLE)
		angle = MAX_ANGLE;

	pulse = MIN_PULSE
	      + (angle * (MAX_PULSE - MIN_PULSE)) / MAX_ANGLE;

	__HAL_TIM_SET_COMPARE(&htim1, TIM_CHANNEL_1, pulse);

	cur_angle = angle;

}

void Survo_SetCenter()
{
	Survo_SetAngle(90);
}

void Survo_Stop()
{
	HAL_TIM_PWM_Stop(&htim1, TIM_CHANNEL_1);
	isInit = 0;
}
