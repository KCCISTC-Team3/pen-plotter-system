/*
 * types.h
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#ifndef AP_COMMON_TYPES_H_
#define AP_COMMON_TYPES_H_

#include <stdbool.h>
//#include "stm32f4xx_it.h"
#include "main.h"

typedef struct {
    float x;
    float y;
    int z;
} coordinate_t;




typedef struct {
    int32_t max_steps;
    int32_t min_steps;
    int32_t error;

    // 가감속 관련 추가
    uint32_t start_arr;     // 시작/종료 시의 느린 ARR (예: 9999)
    uint32_t target_arr;    // 목표 크루징 ARR (예: 2499)
    uint32_t accel_steps;   // 가속에 사용할 스텝 수
    uint32_t decel_start_step; // 감속을 시작할 스텝 번호

    bool is_a_master;
    GPIO_PinState dir_a;
    GPIO_PinState dir_b;
    bool z_action;
    int z_state;
} motion_t;


#endif /* AP_COMMON_TYPES_H_ */
