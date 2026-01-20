/*
 * Presenter.c
 *
 *  Created on: Jan 6, 2026
 *      Author: kccistc
 */
#include "Presenter.h"
#include "cmsis_os.h"

void Presenter_Init() {
	Presenter_Plotter_Init(osThreadGetId());
}
void Presenter_Execute() {
	Presenter_Plotter_Execute();
}

//통신 코드좀 보고 여기서 통신할지 결정
