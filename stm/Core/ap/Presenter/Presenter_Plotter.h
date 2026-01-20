/* Presenter_Plotter.h */

#ifndef AP_PRESENTER_PRESENTER_PLOTTER_H_
#define AP_PRESENTER_PRESENTER_PLOTTER_H_

#include "cmsis_os.h"
#include "../Common/types.h"
#include "../../driver/servo/servo.h"
#include "../../driver/step_motor/step_motor.h"


// 1. 구조체 타입 정의 (메모리를 할당하지 않고 '틀'만 만듭니다)
typedef struct {
    int32_t max_steps;
    int32_t min_steps;
    int32_t error;
    bool is_a_master;
    uint32_t current_step;

    // 가감속 관련 멤버 추가
    uint32_t start_arr;
    uint32_t target_arr;
    uint32_t accel_steps;
    uint32_t decel_start_step;
} ISR_Context_t;

// 2. 외부 참조 선언 (실제 변수는 .c 파일 중 하나에만 존재해야 합니다)
volatile extern ISR_Context_t isr_ctx;

void Presenter_Plotter_Init(osThreadId tid);
void Presenter_Plotter_Execute();

#endif
