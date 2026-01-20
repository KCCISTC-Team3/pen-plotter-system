/*
 * Common.h
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#ifndef AP_COMMON_COMMON_H_
#define AP_COMMON_COMMON_H_

#include <stdint.h>
#include "cmsis_os.h"
#include "../../driver/servo/servo.h"
#include "../../driver/step_motor/step_motor.h"
#include "../Presenter/Presenter.h"

volatile extern uint8_t kill_flag ;

void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin);

#endif /* AP_COMMON_COMMON_H_ */
