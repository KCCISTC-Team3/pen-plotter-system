// 저장 경로 Src

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
        if (rx_data == '\n') {
            rx_buffer[rx_index] = '\0';
            rx_index = 0;
            Set_Data_Ready(1); // 이 함수는 process_handler.c에 정의되어 있음
        } else if (rx_index < 63) {
            rx_buffer[rx_index++] = rx_data;
        }
        HAL_UART_Receive_IT(&huart2, &rx_data, 1);
    }
}
