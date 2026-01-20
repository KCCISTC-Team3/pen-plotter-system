/* USER CODE BEGIN Header */
/**
 ******************************************************************************
 * File Name          : freertos.c
 * Description        : Code for freertos applications
 ******************************************************************************
 * @attention
 *
 * Copyright (c) 2026 STMicroelectronics.
 * All rights reserved.
 *
 * This software is licensed under terms that can be found in the LICENSE file
 * in the root directory of this software component.
 * If no LICENSE file comes with this software, it is provided AS-IS.
 *
 ******************************************************************************
 */
/* USER CODE END Header */

/* Includes ------------------------------------------------------------------*/
#include "FreeRTOS.h"
#include "task.h"
#include "main.h"
#include "cmsis_os.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include "../ap/Common/types.h"
#include "../ap/Presenter/Presenter.h"
#include "../ap/Controller/Controller.h"
#include "../ap/Listener/Listener.h"
#include "../ap/Common/Common.h"
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
/* USER CODE BEGIN Variables */

/* USER CODE END Variables */
osThreadId defaultTaskHandle;
osThreadId UART_TaskHandle;
osThreadId Calc_TaskHandle;
osThreadId Motor_TaskHandle;
osMessageQId Motion_QueueHandle;
osMessageQId Cmd_QueueHandle;

/* Private function prototypes -----------------------------------------------*/
/* USER CODE BEGIN FunctionPrototypes */

/* USER CODE END FunctionPrototypes */

void StartDefaultTask(void const * argument);
void Uart(void const * argument);
void Calculation(void const * argument);
void Motor_drive(void const * argument);

void MX_FREERTOS_Init(void); /* (MISRA C 2004 rule 8.1) */

/* GetIdleTaskMemory prototype (linked to static allocation support) */
void vApplicationGetIdleTaskMemory( StaticTask_t **ppxIdleTaskTCBBuffer, StackType_t **ppxIdleTaskStackBuffer, uint32_t *pulIdleTaskStackSize );

/* USER CODE BEGIN GET_IDLE_TASK_MEMORY */
static StaticTask_t xIdleTaskTCBBuffer;
static StackType_t xIdleStack[configMINIMAL_STACK_SIZE];

void vApplicationGetIdleTaskMemory(StaticTask_t **ppxIdleTaskTCBBuffer,
		StackType_t **ppxIdleTaskStackBuffer, uint32_t *pulIdleTaskStackSize) {
	*ppxIdleTaskTCBBuffer = &xIdleTaskTCBBuffer;
	*ppxIdleTaskStackBuffer = &xIdleStack[0];
	*pulIdleTaskStackSize = configMINIMAL_STACK_SIZE;
	/* place for user code */
}
/* USER CODE END GET_IDLE_TASK_MEMORY */

/**
  * @brief  FreeRTOS initialization
  * @param  None
  * @retval None
  */
void MX_FREERTOS_Init(void) {
  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* USER CODE BEGIN RTOS_MUTEX */
	/* add mutexes, ... */
  /* USER CODE END RTOS_MUTEX */

  /* USER CODE BEGIN RTOS_SEMAPHORES */
	/* add semaphores, ... */
  /* USER CODE END RTOS_SEMAPHORES */

  /* USER CODE BEGIN RTOS_TIMERS */
	/* start timers, add new ones, ... */
  /* USER CODE END RTOS_TIMERS */

  /* Create the queue(s) */
  /* definition and creation of Motion_Queue */
  osMessageQDef(Motion_Queue, 64, motion_t);
  Motion_QueueHandle = osMessageCreate(osMessageQ(Motion_Queue), NULL);

  /* definition and creation of Cmd_Queue */
  osMessageQDef(Cmd_Queue, 1, coordinate_t);
  Cmd_QueueHandle = osMessageCreate(osMessageQ(Cmd_Queue), NULL);

  /* USER CODE BEGIN RTOS_QUEUES */
	/* add queues, ... */
  /* USER CODE END RTOS_QUEUES */

  /* Create the thread(s) */
  /* definition and creation of defaultTask */
  osThreadDef(defaultTask, StartDefaultTask, osPriorityNormal, 0, 128);
  defaultTaskHandle = osThreadCreate(osThread(defaultTask), NULL);

  /* definition and creation of UART_Task */
  osThreadDef(UART_Task, Uart, osPriorityNormal, 0, 128);
  UART_TaskHandle = osThreadCreate(osThread(UART_Task), NULL);

  /* definition and creation of Calc_Task */
  osThreadDef(Calc_Task, Calculation, osPriorityNormal, 0, 128);
  Calc_TaskHandle = osThreadCreate(osThread(Calc_Task), NULL);

  /* definition and creation of Motor_Task */
  osThreadDef(Motor_Task, Motor_drive, osPriorityAboveNormal, 0, 128);
  Motor_TaskHandle = osThreadCreate(osThread(Motor_Task), NULL);

  /* USER CODE BEGIN RTOS_THREADS */
	/* add threads, ... */
  /* USER CODE END RTOS_THREADS */

}

/* USER CODE BEGIN Header_StartDefaultTask */
/**
 * @brief  Function implementing the defaultTask thread.
 * @param  argument: Not used
 * @retval None
 */
/* USER CODE END Header_StartDefaultTask */
void StartDefaultTask(void const * argument)
{
  /* USER CODE BEGIN StartDefaultTask */
	/* Infinite loop */
	for (;;) {
		osDelay(1);
	}
  /* USER CODE END StartDefaultTask */
}

/* USER CODE BEGIN Header_Uart */
/**
 * @brief Function implementing the UART_Task thread.
 * @param argument: Not used
 * @retval None
 */
/* USER CODE END Header_Uart */
void Uart(void const * argument)
{
  /* USER CODE BEGIN Uart */
	Listener_Init();

	/* Infinite loop */
	for (;;) {
		Listener_Execute();
		osDelay(1);
	}
  /* USER CODE END Uart */
}

/* USER CODE BEGIN Header_Calculation */
/**
 * @brief Function implementing the Calc_Task thread.
 * @param argument: Not used
 * @retval None
 */
/* USER CODE END Header_Calculation */
void Calculation(void const * argument)
{
  /* USER CODE BEGIN Calculation */
	Controller_Init();
	/* Infinite loop */
	for (;;) {
		Controller_Execute();
		osDelay(1);
	}
  /* USER CODE END Calculation */
}

/* USER CODE BEGIN Header_Motor_drive */
/**
 * @brief Function implementing the Motor_Task thread.
 * @param argument: Not used
 * @retval None
 */
/* USER CODE END Header_Motor_drive */
void Motor_drive(void const * argument)
{
  /* USER CODE BEGIN Motor_drive */
	Presenter_Init();
	/* Infinite loop */
	for (;;) {

		Presenter_Execute();
		osDelay(1);
	}
  /* USER CODE END Motor_drive */
}

/* Private application code --------------------------------------------------*/
/* USER CODE BEGIN Application */

/* USER CODE END Application */
