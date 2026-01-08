// 저장 경로 Src

#include "process_handler.h"
#include "uart_handler.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "FreeRTOS.h"
#include "queue.h"

extern osMessageQId CoordQueueHandle;
uint8_t data_ready_flag = 0;

static SystemState_t current_state = SYS_IDLE_STATE;
static float targetX, targetY;
static int targetZ;

void Process_Init(void) {
    UART_StartReceive();
}

void Set_Data_Ready(uint8_t state) {
    data_ready_flag = state;
}

uint8_t Parse_To_Struct(char* buf, Coord_t* data) {
    char *x_ptr = strstr(buf, "x:");
    char *y_ptr = strstr(buf, "y:");
    char *z_ptr = strstr(buf, "z:");
    if (x_ptr && y_ptr && z_ptr) {
        data->x = (float)atof(x_ptr + 2);
        data->y = (float)atof(y_ptr + 2);
        data->z = atoi(z_ptr + 2);
        return 1;
    }
    return 0;
}

void Process_Main_Loop(void) {
    Coord_t temp_data;

    // [상시 동작] 수신 및 큐 삽입
    if (data_ready_flag) {
        if (Parse_To_Struct(rx_buffer, &temp_data)) {
            if (xQueueSend(CoordQueueHandle, &temp_data, 0) == pdPASS) {
                data_ready_flag = 0;
                UART_StartReceive();
            }
        } else {
            data_ready_flag = 0;
            UART_StartReceive();
        }
    }

    // FSM
    switch (current_state) {
        case SYS_IDLE_STATE:
            if (xQueueReceive(CoordQueueHandle, &temp_data, 0) == pdPASS) {
                // 꺼내는 순간 0xBB 송신
                uint8_t request_code = 0xBB;
                HAL_UART_Transmit(&huart2, &request_code, 1, 10);

                targetX = temp_data.x;
                targetY = temp_data.y;
                targetZ = temp_data.z;

                current_state = SYS_DRAW_READY_STATE;
            }
            break;

        case SYS_DRAW_READY_STATE:
            current_state = SYS_DRAWING_STATE;
            break;

        case SYS_DRAWING_STATE:
            // TODO: 실제 모터 구동 호출
        	HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);
            osDelay(100); // 테스트용 딜레이
            current_state = SYS_IDLE_STATE;
            break;
    }
}
