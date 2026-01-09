/*
 * common.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#ifndef AP_COMMON_COMMON_C_
#define AP_COMMON_COMMON_C_

#include "Common.h"

void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
	if (GPIO_Pin == GPIO_PIN_10) {
		//디바운스
		static uint32_t last_tick = 0;
		if (HAL_GetTick() - last_tick < 200)
			return;
		last_tick = HAL_GetTick();

		Step_Stop();
		Servo_Set_0();
		Presenter_Init();

	}
}

#endif /* AP_COMMON_COMMON_C_ */
