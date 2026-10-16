#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include "system.h"
#include "io.h"
#include "function.c"

#define REG_TEST_OFFSET 0x04

int main() {
    printf("=== KHOI TAO HE THONG ===\n");

    // 1. Tạm tắt ngắt trước khi cấu hình (Ghi 0 vào A_IRQEN ở offset 0x10)
    IOWR_32DIRECT(NEW_COMPONENT_0_BASE, 0x10, 0x00);

    // 2. Xóa sạch mọi cờ ngắt cũ đang tồn đọng (Ghi 1 để xóa toàn bộ A_IRQSTAT ở offset 0x14)
    IOWR_32DIRECT(NEW_COMPONENT_0_BASE, 0x14, 0xFFFFFFFF);

    int res = alt_ic_isr_register(
        NEW_COMPONENT_0_IRQ_INTERRUPT_CONTROLLER_ID,
        NEW_COMPONENT_0_IRQ,
        uart_apb_isr,
        NULL,
        NULL
    );

    if (res != 0) {
        printf("Loi: Khong the dang ky ngat!\n");
        return -1;
    }

    // 3. QUAN TRỌNG: BẬT NGẮT TỪ PHÍA PHẦN CỨNG (Cho phép IR_EN = 1)
    // Nếu không có lệnh này, hàm uart_apb_isr sẽ không bao giờ kích hoạt
    IOWR_32DIRECT(NEW_COMPONENT_0_BASE, 0x10, 0x01);

    printf("=== BAT DAU TEST UART APB CORE ===\n");

    // Khởi tạo UART với xung nhịp 50MHz, Baudrate 115200
    uart_init(50000000, 115200);

    int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);

    char tx_buf[256];
    int tx_idx = 0;
    tx_buf[0] = '\0';

    printf("=== BAT DAU GIAO TIEP UART ===\n");
    printf("> Nhap tin nhan (hoac go 'exit' de thoat): ");
    fflush(stdout);

    while (1) {
        // ========================================================
        // LUỒNG 1: KIỂM TRA DỮ LIỆU TỪ MẠCH UART (RX) - KHÔNG DÙNG BUFFER
        // ========================================================
        int c_uart = uart_getc();
        if (c_uart >= 0) {
            // Xóa dòng nhập hiện tại để tránh giao diện đan xen chữ

            // Xử lý in ký tự: nếu là ký tự xuống dòng thì in rõ chữ <Enter>
            if (c_uart == '\n' || c_uart == '\r') {
            	printf("\r                                               \r");
                printf("[Nhan]: <Enter>\n");
            } else {
                // In ngay lập tức ký tự nhận được
            	printf("\r                                               \r");
                printf("[Nhan]: %c\n", (char)c_uart);
            }

            // In lại prompt và phần chữ mà người dùng đang gõ dở ở TX
            printf("> Nhap tin nhan: %s", tx_buf);
            fflush(stdout);

        } else if (c_uart == -1) {
            // Có lỗi truyền dẫn (Frame/Parity)
        }

        // ========================================================
        // LUỒNG 2: KIỂM TRA NGƯỜI DÙNG BẤM PHÍM TỪ TERMINAL (TX)
        // ========================================================
        int c_stdin = getchar();
        if (c_stdin != EOF && c_stdin > 0) {

            // Nếu bấm Enter
            if (c_stdin == '\n' || c_stdin == '\r') {
                tx_buf[tx_idx] = '\0';
                printf("\n");

                if (strcmp(tx_buf, "exit") == 0) {
                    break;
                }

                uart_puts(tx_buf);
                uart_puts("\n");

                tx_idx = 0;
                tx_buf[0] = '\0';
                printf("> Nhap tin nhan: ");
                fflush(stdout);
            }
            // Nếu bấm Backspace
            else if (c_stdin == '\b' || c_stdin == 127) {
                if (tx_idx > 0) {
                    tx_idx--;
                    tx_buf[tx_idx] = '\0';
                    printf("\b \b");
                    fflush(stdout);
                }
            }
            // Ký tự bình thường
            else {
                if (tx_idx < 255) {
                    tx_buf[tx_idx++] = (char)c_stdin;
                    tx_buf[tx_idx] = '\0';
                    putchar(c_stdin);
                    fflush(stdout);
                }
            }
        }

        usleep(50);
    }

    printf("\n=== DA NGAT CHUONG TRINH ===\n");
    return 0;
}
