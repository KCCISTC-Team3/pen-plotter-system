/*
 * step_motor.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#include "step_motor.h"

step_t Step_motor_1;
step_t Step_motor_2;



void Step_Init() {
    // Step_motor_1
    Step_motor_1.step_port = S1_STEP_PORT;
    Step_motor_1.step_pin  = S1_STEP_PIN;
    Step_motor_1.dir_port  = S1_DIR_PORT;
    Step_motor_1.dir_pin   = S1_DIR_PIN;

    // Step_motor_2
    Step_motor_2.step_port = S2_STEP_PORT;
    Step_motor_2.step_pin  = S2_STEP_PIN;
    Step_motor_2.dir_port  = S2_DIR_PORT;
    Step_motor_2.dir_pin   = S2_DIR_PIN;

    HAL_GPIO_WritePin(Step_motor_1.step_port, Step_motor_1.step_pin, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(Step_motor_1.dir_port, Step_motor_1.dir_pin, CCW);

    HAL_GPIO_WritePin(Step_motor_2.step_port, Step_motor_2.step_pin, GPIO_PIN_RESET);
    HAL_GPIO_WritePin(Step_motor_2.dir_port, Step_motor_2.dir_pin, CCW);
}



void Step_Set_ARR(uint32_t arr) {
    __HAL_TIM_SET_AUTORELOAD(&htim2, arr);
}


void Step_Start() { // 두개 한번에 시작
    __HAL_TIM_SET_COUNTER(&htim2, 0);
    HAL_TIM_Base_Start_IT(&htim2);
}

void Step_Stop() {
    HAL_TIM_Base_Stop_IT(&htim2);
}

void Step_Set_StepPin(step_t* motor, GPIO_PinState state) {
    if (motor != NULL && motor->step_port != NULL) {
        HAL_GPIO_WritePin(motor->step_port, motor->step_pin, state);
    }
}

void Step_Set_DirPin(step_t* motor, GPIO_PinState state) {
    if (motor != NULL && motor->dir_port != NULL) {
        HAL_GPIO_WritePin(motor->dir_port, motor->dir_pin, state);
    }
}
