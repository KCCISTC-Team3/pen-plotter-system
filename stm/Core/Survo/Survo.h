/*
 * Survo.h
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#ifndef SURVO_SURVO_H_
#define SURVO_SURVO_H_

#include "tim.h"
#include <stdint.h>

#define MIN_PULSE  500 // 0도
#define CENTER_PULSE 1250// 90도
#define MAX_PULSE  2000  // 180도
#define MAX_ANGLE  180

extern TIM_HandleTypeDef htim1;

void Survo_Init();
void Survo_SetAngle(uint8_t angle);
void Survo_SetCenter();
void Survo_Stop();

#endif /* SURVO_SURVO_H_ */
