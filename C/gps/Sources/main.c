#include "../../shared/plasmaSoPCDesign.h"
#include "../../shared/plasma.h"
#include "../../shared/plasmaMyPrint.h"
//#include <string.h>

#define MemoryRead(A)     (*(volatile unsigned int*)(A))
#define MemoryWrite(A,V) *(volatile unsigned int*)(A)=(V)

int main(int argc, char ** argv)
{
	char message[128];
	char time[10];
	char c;
	char message_id[5];
	int i = 0;
	int j = 0;
	puts("Welcome to Gps project\n");
	while(1){
		if((MemoryRead(UART_PMOD_STATUS) & UART_PMOD_READ_AVAILABLE) == 1){
			puts("1st CHAR RECEIVED\n");
			i = 0;
			j = 0;
			c = MemoryRead(UART_PMOD_READ);
			while(c != '\n'){

				message[i] = c;
				c = MemoryRead(UART_PMOD_READ);
				i++;
			}
			message[i] = '\n';
			message[i+1] = 0;
			puts(message);
			// while(message[j] != '$')
			// 	j++;
			// j++;
			// int k;
			// for( k = 0; k < 5; k++){
			// 	message_id[k] = message[j+k];
			// 	j++;
			// }
			//if(strcmp(message_id, "GPGGA") == 0){

			//}
		}
	}
}
