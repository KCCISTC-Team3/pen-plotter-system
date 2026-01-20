/*
 * lcd.h
 *
 *  Created on: Dec 17, 2025
 *      Author: kccistc
 */

#ifndef DRIVER_LCD_LCD_H_
#define DRIVER_LCD_LCD_H_
#include "stm32f4xx_hal.h"

#define LCD_RS 0
#define LCD_RW 1
#define LCD_E  2
#define LCD_BL 3
#define LCD_4BIT_FUCTION_SET 	0x28
#define LCD_DISPLAY_OFF		 	0x08
#define LCD_DISPLAY_ON 			0x0c
#define LCD_DISPLAY_CLEAR 		0x01
#define LCD_ENTRY_MODE_SET 		0x06
#define LCD_RETURN_HOME			0x02

void LCD_gotoXY(uint8_t row, uint8_t col);
void LCD_CmdMode();
void LCD_DataMode();
void LCD_WriteMode();
void LCD_SendData(uint8_t data);
void LCD_E_High();
void LCD_E_Low();
void LCD_WriteNibble(uint8_t data);
void LCD_WriteByte(uint8_t data);
void LCD_WriteCmdData(uint8_t data);
void LCD_WriteCharData(uint8_t data);
void LCD_BackLightOn();
void LCD_BackLightOff();
void LCD_Init(I2C_HandleTypeDef *phi2c);
void LCD_WriteString(char *str);
void LCD_WriteStringXY(uint8_t row, uint8_t col, char *str);

#endif /* DRIVER_LCD_LCD_H_ */
