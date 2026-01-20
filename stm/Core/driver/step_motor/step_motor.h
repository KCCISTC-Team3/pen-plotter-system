/*
 * step_motor.h
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#ifndef DRIVER_STEP_MOTOR_STEP_MOTOR_H_
#define DRIVER_STEP_MOTOR_STEP_MOTOR_H_

#include <main.h>
#include "tim.h"

// A4988 MS 핀 정의
#define S1_STEP_PORT  GPIOA
#define S1_STEP_PIN   GPIO_PIN_9
#define S1_DIR_PORT   GPIOC
#define S1_DIR_PIN    GPIO_PIN_7

#define S2_STEP_PORT  GPIOB
#define S2_STEP_PIN   GPIO_PIN_6
#define S2_DIR_PORT   GPIOA
#define S2_DIR_PIN    GPIO_PIN_7

#define CW 	GPIO_PIN_SET
#define CCW	GPIO_PIN_RESET

typedef struct {
	GPIO_TypeDef *step_port;
	uint16_t step_pin;
	GPIO_TypeDef *dir_port;
	uint16_t dir_pin;
} step_t;


extern TIM_HandleTypeDef htim2;

extern step_t Step_motor_1; // 아래있는 스텝모터
extern step_t Step_motor_2; //위에 있는 스텝모터

void Step_Init();
void Step_Set_ARR(uint32_t arr);
void Step_Start();
void Step_Stop();
void Step_Set_StepPin(step_t *motor, GPIO_PinState state);
void Step_Set_DirPin(step_t *motor, GPIO_PinState state);
#endif /* DRIVER_STEP_MOTOR_STEP_MOTOR_H_ */
