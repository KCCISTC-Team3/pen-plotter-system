/*
 * lcd.c
 *
 *  Created on: Dec 17, 2025
 *      Author: kccistc
 */

#include "lcd.h"

uint8_t lcdData = 0; // 실제로 내보내는 데이터
I2C_HandleTypeDef *hLcdI2C; // main에 있는 I2C 핸들러 대신임

void LCD_CmdMode()
{
	lcdData &= ~(1<<LCD_RS); // lcd 데이터의 0번(LCD_RS 위치의) 데이터를 0으로
}

void LCD_DataMode()
{
	lcdData |= (1<<LCD_RS); // lcd 데이터의 0번(LCD_RS 위치의) 데이터를 1로
}

void LCD_WriteMode()
{
	lcdData &= ~(1<<LCD_RW); // lcd 데이터의 1번(LCD_RW 위치의) 데이터를 0으로
}

void LCD_SendData(uint8_t data)
{
	// send data to I2C Interface
	HAL_I2C_Master_Transmit(hLcdI2C, 0x27<<1, &data, 1, 1000);
}

void LCD_E_High()
{
	lcdData |= (1<<LCD_E);
	LCD_SendData(lcdData);
}

void LCD_E_Low()
{
	lcdData &= ~(1<<LCD_E);
	LCD_SendData(lcdData);
}

void LCD_WriteNibble(uint8_t data)
{
	LCD_E_High();
	lcdData = (lcdData & 0x0f) | (data & 0xf0); // 상위 4비트를 다 0으로 만들어 줌
	LCD_SendData(lcdData); // lcd 데이터를 실제로 내보냄
	LCD_E_Low();
}

void LCD_WriteByte(uint8_t data) // 두 번 보내야 됨
{
	LCD_WriteNibble(data); // 상위 4비트
	data <<= 4; // shift
	LCD_WriteNibble(data); // 하위 4비트
}

void LCD_WriteCmdData(uint8_t data)
{
	LCD_CmdMode();
	LCD_WriteMode();
	LCD_WriteByte(data);
}

void LCD_WriteCharData(uint8_t data)
{
	LCD_DataMode();
	LCD_WriteMode();
	LCD_WriteByte(data);
}

void LCD_BackLightOn()
{
	lcdData |= (1<<LCD_BL);
	LCD_WriteByte(lcdData);
}

void LCD_BackLightOff()
{
	lcdData &= ~(1<<LCD_BL);
	LCD_WriteByte(lcdData);
}

void LCD_Init(I2C_HandleTypeDef *phi2c) // 초기화할 때 해당 핸들러를 넣어줌
{
	hLcdI2C = phi2c;
	HAL_Delay(40);
	LCD_CmdMode();
	LCD_WriteMode();
	LCD_WriteNibble(0x30); // 상위 4비트만 보냄
	HAL_Delay(5);
	LCD_WriteNibble(0x30);
	HAL_Delay(1);
	LCD_WriteNibble(0x30);
	LCD_WriteNibble(0x20);
	LCD_WriteByte(LCD_4BIT_FUCTION_SET); 	// 0x28
	LCD_WriteByte(LCD_DISPLAY_OFF); 		// 0x08
	LCD_WriteByte(LCD_DISPLAY_CLEAR); 		// 0x01
	LCD_WriteByte(LCD_ENTRY_MODE_SET); 		// 0x06
	LCD_WriteByte(LCD_RETURN_HOME);
	LCD_WriteByte(LCD_DISPLAY_ON); 			// 0x0c
	LCD_BackLightOn();
}

void LCD_gotoXY(uint8_t row, uint8_t col)
{
	col %= 16;
	row %= 2;

	uint8_t lcdRegisterAddress = (0x40 * row) + col;
	uint8_t command = 0x80 + lcdRegisterAddress;
	LCD_WriteCmdData(command);
}

void LCD_WriteString(char *str)
{
	for (int i = 0; str[i]; i++){
		LCD_WriteCharData(str[i]);
	}
}

void LCD_WriteStringXY(uint8_t row, uint8_t col, char *str)
{
	LCD_gotoXY(row, col);
	LCD_WriteString(str);
}






































