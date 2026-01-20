################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (13.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../Core/ap/Controller/Controller.c \
../Core/ap/Controller/Controller_Plotter.c 

OBJS += \
./Core/ap/Controller/Controller.o \
./Core/ap/Controller/Controller_Plotter.o 

C_DEPS += \
./Core/ap/Controller/Controller.d \
./Core/ap/Controller/Controller_Plotter.d 


# Each subdirectory must supply rules for building sources it contributes
Core/ap/Controller/%.o Core/ap/Controller/%.su Core/ap/Controller/%.cyclo: ../Core/ap/Controller/%.c Core/ap/Controller/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m4 -std=gnu11 -g3 -DDEBUG -DUSE_HAL_DRIVER -DSTM32F411xE -c -I../Core/Inc -I../Drivers/STM32F4xx_HAL_Driver/Inc -I../Drivers/STM32F4xx_HAL_Driver/Inc/Legacy -I../Drivers/CMSIS/Device/ST/STM32F4xx/Include -I../Drivers/CMSIS/Include -I../Middlewares/Third_Party/FreeRTOS/Source/include -I../Middlewares/Third_Party/FreeRTOS/Source/CMSIS_RTOS -I../Middlewares/Third_Party/FreeRTOS/Source/portable/GCC/ARM_CM4F -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Core-2f-ap-2f-Controller

clean-Core-2f-ap-2f-Controller:
	-$(RM) ./Core/ap/Controller/Controller.cyclo ./Core/ap/Controller/Controller.d ./Core/ap/Controller/Controller.o ./Core/ap/Controller/Controller.su ./Core/ap/Controller/Controller_Plotter.cyclo ./Core/ap/Controller/Controller_Plotter.d ./Core/ap/Controller/Controller_Plotter.o ./Core/ap/Controller/Controller_Plotter.su

.PHONY: clean-Core-2f-ap-2f-Controller

