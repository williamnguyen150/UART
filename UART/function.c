#include <stdint.h>
#include "system.h"
#include "io.h"
#include "sys/alt_irq.h"


// =======================================================
//    VIẾT HÀM PHỤC VỤ NGẮT (ISR)
// =======================================================
void uart_apb_isr(void* context) {
    // a. Đọc trạng thái ngắt xem nguyên nhân do đâu
    uint32_t irq_stat = IORD_32DIRECT(NEW_COMPONENT_0_BASE, 0x14);

    // b. Xử lý sự kiện (Dựa vào thiết kế phần cứng của bạn)
    if (irq_stat & (1 << 1)) {
    	printf("\r                                                           \r");
		printf("[IRQ] RX Overrun ! Dang rut toan bo du lieu khoi FIFO...\n");

		char irq_buf[256]; // Khởi tạo mảng đệm tạm thời
		int irq_idx = 0;

		// Vòng lặp kéo toàn bộ dữ liệu lưu vào mảng
		while (!(IORD_32DIRECT(NEW_COMPONENT_0_BASE, 0x0c) & (1 << 0))) {
			uint32_t rx_val = IORD_32DIRECT(NEW_COMPONENT_0_BASE, 0x08);
			if (irq_idx < 255) { // Đảm bảo không ghi tràn mảng irq_buf
				irq_buf[irq_idx++] = (char)((rx_val >> 2) & 0xFF);
			}
		}
		irq_buf[irq_idx] = '\0'; // Chốt chuỗi C

		// In toàn bộ dữ liệu ra màn hình trong 1 lần duy nhất
		if (irq_idx > 0) {
			printf("[IRQ] Pull out data: %s\n", irq_buf);
		}

		// Khôi phục lại giao diện dòng nhắc lệnh cho người dùng
		printf("> Nhap tin nhan: ");
		fflush(stdout);
    }

    if (irq_stat & (1 << 2)) {
        // Bit 2 là TX_OVERRUN
        printf("[IRQ] TX Overrun\n");
    }

    if (irq_stat & (1 << 0)) {
        // Bit 0 là CONFIG_OVERWRITE
        printf("[IRQ] Loi ghi de cau hinh!\n");
    }

    // c. XÓA CỜ NGẮT BẰNG PHẦN CỨNG (Write 1 to clear)
    // Trong file apb_regs.v, bạn viết: RX_OVERRUN <= RX_OVERRUN & ~w_data[1];
    // Nên ghi lại đúng giá trị irq_stat sẽ xóa đúng các bit vừa xảy ra ngắt
    IOWR_32DIRECT(NEW_COMPONENT_0_BASE, 0x14, irq_stat);
}

void uart_init(uint32_t clk_freq, uint32_t baudrate) {
    // Tính toán hệ số chia (Baud Divisor)
    uint32_t bauddiv = clk_freq / baudrate - 1;

    // QUAN TRỌNG: Theo logic apb_regs.v, phải TẮT TX_EN và RX_EN thì mới ghi đè được BAUDDIV
    // Ghi 0 vào byte thấp nhất (strb[0]) để tắt TX_EN (bit 1) và RX_EN (bit 0)
    IOWR_8DIRECT(NEW_COMPONENT_0_BASE, 0x00, 0x00);

    // Lắp ráp cấu hình 32-bit:
    // BAUDDIV (bit 29:16)
    // DATALEN = 3 (nghĩa là 8 bit data) (bit 12:11)
    // STOP2 = 0 (1 bit stop) (bit 10)
    // PARITY_EN = 0 (Không dùng parity) (bit 9)
    // TX_EN = 1, RX_EN = 1 (Bật trở lại) (bit 1:0)
    uint32_t config_val = 0;
    config_val |= (bauddiv << 16);
    config_val |= (3 << 11);
    config_val |= (0 << 10);
    config_val |= (0 << 9);
    config_val |= (0 << 8);
    config_val |= 0x03; // Bật TX_EN và RX_EN

    // Ghi toàn bộ cấu hình mới xuống phần cứng
    IOWR_32DIRECT(NEW_COMPONENT_0_BASE, 0x00, config_val);
}

/**
 * Hàm phát 1 ký tự (Truyền đi)
 */
void uart_putc(char c) {
    // Đọc thanh ghi STATUS để kiểm tra trạng thái FIFO phát
    // Theo mạch: r_data = {27'd0, TX_BUSY, TX_FULL, TX_EMPTY, RX_FULL, RX_EMPTY};
    // => Bit 3 là TX_FULL

    // Chờ cho đến khi TX_FULL == 0 (Tức là hàng chờ chưa đầy)
    while (IORD_32DIRECT(NEW_COMPONENT_0_BASE, 0x0c) & (1 << 3));

    // Ghi ký tự vào hàng chờ phát (Chỉ ghi 8 bit vào byte 0 của A_TXDATA)
    IOWR_8DIRECT(NEW_COMPONENT_0_BASE, 0x04, c);
}

/**
 * Hàm phát một chuỗi ký tự
 */
void uart_puts(const char* str) {
    while (*str) {
        uart_putc(*str++);
        //usleep(100);
    }
}

/**
 * Hàm nhận 1 ký tự (Đọc về)
 * @return Ký tự nhận được, hoặc -1 nếu có lỗi Parity/Frame, hoặc -2 nếu chưa có dữ liệu
 */
int uart_getc() {
    // Đọc STATUS. Bit 0 là RX_EMPTY
    uint32_t status = IORD_32DIRECT(NEW_COMPONENT_0_BASE, 0x0c);

    if (status & (1 << 0)) {
        return -2; // RX_EMPTY = 1 -> Không có dữ liệu
    }

    // Nếu có dữ liệu, tiến hành đọc thanh ghi RXDATA
    // Theo mạch: r_data = {22'd0, RX_DATA[7:0], PARITY_ERROR, FRAME_ERROR};
    uint32_t rx_reg = IORD_32DIRECT(NEW_COMPONENT_0_BASE, 0x08);

    // Kiểm tra bit 0 (Frame Error) và bit 1 (Parity Error)
    if (rx_reg & 0x03) {
        return -1; // Có lỗi truyền dẫn do nhiễu
    }

    // Dịch phải 2 bit để bóc tách 8-bit RX_DATA ra
    uint8_t rx_data = (rx_reg >> 2) & 0xFF;
    return rx_data;
}
