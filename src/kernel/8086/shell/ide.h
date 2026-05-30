#ifndef __IDE_H_INCLUDED__
#define __IDE_H_INCLUDED__

#define BYTES_PER_SECTOR 512

#define IDE_MASTER 0x00
#define IDE_SLAVE 0x01
#define IDE_PRIMARY 0x00
#define IDE_SECONDARY 0x02
#define IDE_PRIMARY_MASTER (IDE_PRIMARY | IDE_MASTER)
#define IDE_PRIMARY_SLAVE (IDE_PRIMARY | IDE_SLAVE)
#define IDE_SECONDARY_MASTER (IDE_SECONDARY | IDE_MASTER)
#define IDE_SECONDARY_SLAVE (IDE_SECONDARY | IDE_SLAVE)

#define IDE_PRIMARY_MASTER_EXISTS (1 << IDE_PRIMARY_MASTER)
#define IDE_PRIMARY_SLAVE_EXISTS (1 << IDE_PRIMARY_SLAVE)
#define IDE_SECONDARY_MASTER_EXISTS (1 << IDE_SECONDARY_MASTER)
#define IDE_SECONDARY_SLAVE_EXISTS (1 << IDE_SECONDARY_SLAVE)

// IDE IDENTIFY command returned data structure (512 bytes)
// All 16-bit fields are big-endian, need byte swapping on x86
typedef struct {
  // word 0
  unsigned short config; // bit15=1 for ATAPI device

  // word 1-9
  unsigned short cylinders; // CHS cylinders count
  unsigned short reserved2;
  unsigned short heads;             // CHS heads count
  unsigned short sectors_per_track; // CHS sectors per track
  unsigned short vendor[3];         // Vendor specific

  // word 10-19
  char serial[20]; // Serial number (20 bytes, need byte swap)

  // word 20-21
  unsigned short pio_cycle_time; // PIO cycle time
  unsigned short dma_cycle_time; // DMA cycle time

  // word 22-26
  unsigned short supported_pio_modes; // Supported PIO modes
  unsigned short reserved22;
  char fw_rev[8]; // Firmware version (8 bytes)

  // word 27-46
  char model[40]; // Model string (40 bytes)

  // word 47-49
  unsigned short max_multi_sectors;  // Max sectors per interrupt (bits 7-0)
  unsigned short dword_io_supported; // Dword I/O support
  unsigned short capabilities2;      // Capabilities set 2

  // word 50-52
  unsigned short reserved50;
  unsigned short pio_timing;
  unsigned short dma_timing;

  // word 53-58
  unsigned short valid_fields;      // bit1=1 means word 54-58 valid
  unsigned short cur_cylinders;     // Current cylinders
  unsigned short cur_heads;         // Current heads
  unsigned short cur_sectors;       // Current sectors per track
  unsigned short cur_capacity_low;  // Current capacity low 16 bits
  unsigned short cur_capacity_high; // Current capacity high 16 bits

  // word 59
  unsigned short multi_sectors; // Current sectors per interrupt

  // word 60-61
  unsigned int lba28_sectors; // LBA28 total sectors (32 bits)

  // word 62-79
  unsigned short dma_modes; // Supported DMA modes
  unsigned short reserved63[17];

  // word 80-84
  unsigned short major_version; // Supported ATA major version
  unsigned short minor_version; // Supported ATA minor version
  unsigned short commands1;     // Supported command set 1
  unsigned short commands2;     // Supported command set 2
  unsigned short commands3;     // Supported command set 3

  // word 85-87
  unsigned short enabled_cmds1; // Enabled command set 1
  unsigned short enabled_cmds2; // Enabled command set 2
  unsigned short enabled_cmds3; // Enabled command set 3

  // word 88-99
  unsigned short ultra_dma_modes; // Supported Ultra DMA modes
  unsigned short reserved89[11];

  // word 100-103
  unsigned long long lba48_sectors; // LBA48 total sectors (48 bits)

  // word 104-255
  unsigned short reserved104[152]; // Remaining reserved fields
} ide_device_info;

// return IDE_*_EXISTS flags
unsigned char ide_init();
const ide_device_info *ide_get_device_info(unsigned char device);

// device: IDE_PRIMARY_MASTER, IDE_PRIMARY_SLAVE, IDE_SECONDARY_MASTER, or IDE_SECONDARY_SLAVE
// return number of sectors successfully read/written
unsigned int ide_read_sectors(unsigned char device, unsigned long lba, unsigned int sector_count, void *buffer);
unsigned int ide_write_sectors(unsigned char device, unsigned long lba, unsigned int sector_count, const void *buffer);

#endif // __IDE_H_INCLUDED__
