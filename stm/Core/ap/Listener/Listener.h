/*
 * Listener.h
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */

#ifndef AP_LISTENER_LISTENER_H_
#define AP_LISTENER_LISTENER_H_

#include "uart_handler.h"
#include "process_handler.h"
#include "FreeRTOS.h"
#include "queue.h"

void Listener_Init();
void Listener_Execute();

#endif /* AP_LISTENER_LISTENER_H_ */
