################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../Core/driver/lcd/lcd.c 

OBJS += \
./Core/driver/lcd/lcd.o 

C_DEPS += \
./Core/driver/lcd/lcd.d 


# Each subdirectory must supply rules for building sources it contributes
Core/driver/lcd/%.o Core/driver/lcd/%.su Core/driver/lcd/%.cyclo: ../Core/driver/lcd/%.c Core/driver/lcd/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m4 -std=gnu11 -g3 -DDEBUG -DUSE_HAL_DRIVER -DSTM32F411xE -c -I../Core/Inc -I../Drivers/STM32F4xx_HAL_Driver/Inc -I../Drivers/STM32F4xx_HAL_Driver/Inc/Legacy -I../Drivers/CMSIS/Device/ST/STM32F4xx/Include -I../Drivers/CMSIS/Include -I../Middlewares/Third_Party/FreeRTOS/Source/include -I../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS -I../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Core-2f-driver-2f-lcd

clean-Core-2f-driver-2f-lcd:
	-$(RM) ./Core/driver/lcd/lcd.cyclo ./Core/driver/lcd/lcd.d ./Core/driver/lcd/lcd.o ./Core/driver/lcd/lcd.su

.PHONY: clean-Core-2f-driver-2f-lcd

