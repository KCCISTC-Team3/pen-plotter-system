/*
 * uart_handler.c
 *
 *  Created on: Jan 7, 2026
 *      Author: kccistc
 */


#include "uart_handler.h"
#include "process_handler.h"

extern UART_HandleTypeDef huart2;

char rx_buffer[64];
uint8_t rx_data;
int rx_index = 0;

void UART_StartReceive(void) {
    HAL_UART_Receive_IT(&huart2, &rx_data, 1);
}

void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
    if (huart->Instance == USART2) {
        if (rx_data == '\n' || rx_data == '\r') {
            rx_buffer[rx_index] = '\0';
            rx_index = 0;
            Set_Data_Ready(1);
            HAL_UART_Receive_IT(&huart2, &rx_data, 1);
        } else if (rx_index < 63) {
            rx_buffer[rx_index++] = rx_data;
            HAL_UART_Receive_IT(&huart2, &rx_data, 1);
        }
    }
}
