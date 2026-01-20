/*
 * process_handler.c
 *
 *  Created on: Jan 7, 2026
 *      Author: kccistc
 */

#include "process_handler.h"
#include "uart_handler.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "FreeRTOS.h"
#include "queue.h"


//extern osMessageQId CoordQueueHandle;
extern osMessageQId Cmd_QueueHandle;

uint8_t data_ready_flag = 0;

void Process_Init(void) {
    UART_StartReceive();
}

void Set_Data_Ready(uint8_t state) {
    data_ready_flag = state;
}


uint8_t Parse_To_Struct(char* buf, coordinate_t* data) {
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
