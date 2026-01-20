/*
 * Listener.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#include "Listener.h"

extern osMessageQId Cmd_QueueHandle; // freertos.c에서 생성된 큐

void Listener_Init() {
	UART_StartReceive();
}

void Listener_Execute(void) {
    coordinate_t temp_data;

    if (data_ready_flag) {
        if (Parse_To_Struct(rx_buffer, &temp_data)) {
            if (xQueueSend((QueueHandle_t)Cmd_QueueHandle, &temp_data, 0) == pdPASS) {
                data_ready_flag = 0;
                UART_StartReceive();
            }
        } else {
            data_ready_flag = 0;
            UART_StartReceive();
        }
    }
}
