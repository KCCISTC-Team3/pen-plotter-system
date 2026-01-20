/*
 * common.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#ifndef AP_COMMON_COMMON_C_
#define AP_COMMON_COMMON_C_

#include "Common.h"
#include "../driver/lcd/lcd.h"
#include "cmsis_os.h"

volatile uint8_t kill_flag = 0;

extern osThreadId Motor_TaskHandle;

void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
	if (GPIO_Pin == GPIO_PIN_10) {
		static uint32_t last_tick = 0;
		if (HAL_GetTick() - last_tick < 200)
			return;
		last_tick = HAL_GetTick();

		kill_flag = 1;
		Step_Stop();
		Servo_Set_0();
		osSignalSet(Motor_TaskHandle, 0x02);
	}
}

#endif /* AP_COMMON_COMMON_C_ */
