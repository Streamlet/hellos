#include "ide.h"
#include "bootstrap.h"

#define WORDS_PER_SECTOR 256
#define MAX_SECTORS_PER_COMMAND 256

#define REG_BASE_IDE0 0x1F0
#define REG_BASE_IDE1 0x170

// The data register, used for reading/writing data, 2 bytes at a time
#define REG_DATA_OFFSET 0

// The error register (read-only), used for error reporting and setting features
#define REG_ERROR_OFFSET 1

// The features register (write-only), used for setting features
#define REG_FEATURES_OFFSET 1

// The sector count register, used for specifying the number of sectors to read/write
#define REG_SECTOR_COUNT_OFFSET 2

// The LBA low register, used for specifying the low byte of the LBA address
#define REG_LBA_LOW_OFFSET 3

// The LBA mid register, used for specifying the middle byte of the LBA address
#define REG_LBA_MID_OFFSET 4

// The LBA high register, used for specifying the high byte of the LBA address
#define REG_LBA_HIGH_OFFSET 5

// The device register, used for selecting the device and specifying the LBA mode
// bit 0-3: specify the high 4 bits of the LBA address in LBA28
// bit 4 (0x10): select the slave device if set, select the master device if clear
// bit 5 (0x20): set to 1 for LBA48 mode, set to 0 for LBA28 mode.
// bit 6 (0x40): set to 1 for LBA mode, set to 0 for CHS mode.
#define REG_DEVICE_OFFSET 6
#define DEVICE_FLAG_LBA28_MASK 0x0F
#define DEVICE_FLAG_SLAVE 0x10
#define DEVICE_FLAG_LBA_MODE 0x20
#define DEVICE_FLAG_LBA 0x40
#define DEVICE_FLAG_RESERVED 0x80

// The status register, used for reading the status of the device
// bit 0 (0x01): ERR, indicates an error occurred during the last command
// bit 1 (0x02): IDX, reserved, always 0
// bit 2 (0x04): CORR, indicates a correctable data error occurred during the last command
// bit 3 (0x08): DRQ, indicates that the device is ready to transfer data
// bit 4 (0x10): DSC, indicates that the device has completed the command and is ready for the next command
// bit 5 (0x20): DF, indicates a device fault error occurred during the last command
// bit 6 (0x40): DRDY, indicates that the device is ready to accept commands
// bit 7 (0x80): BSY, indicates that the device is busy
#define REG_STATUS_OFFSET 7
#define STATUS_ERR 0x01
#define STATUS_IDX 0x02
#define STATUS_CORR 0x04
#define STATUS_DRQ 0x08
#define STATUS_DSC 0x10
#define STATUS_DF 0x20
#define STATUS_DRDY 0x40
#define STATUS_BSY 0x80

// The command register, used for sending commands to the device
// 0x20: READ SECTORS
// 0x30: WRITE SECTORS
// 0xEC: IDENTIFY
#define REG_COMMAND_OFFSET 7
#define COMMAND_READ_SECTORS 0x20
#define COMMAND_WRITE_SECTORS 0x30
#define COMMAND_IDENTIFY 0xEC

typedef struct {
  unsigned char devices_present;
  ide_device_info device_info[4];
} ide_global_status;

ide_global_status ide_global_status_;

#define SWAP16(x) (((x) >> 8) | ((x) << 8))

void ide_trim_string(char *str, int length) {
  // Trim trailing spaces
  for (int i = length - 1; i >= 0; i--) {
    if (str[i] != ' ') {
      str[i + 1] = '\0';
      break;
    }
  }
}

int ide_wait_for_idle(int base) {
  long timeout = 100000;
  unsigned char status = 0;
  while (timeout-- > 0) {
    status = _inb(base + REG_STATUS_OFFSET);
    if ((status & STATUS_ERR) != 0) {
      return 0;
    }
    if ((status & STATUS_BSY) == 0) {
      return 1;
    }
  }
  return 0;
}

int ide_wait_for_drq_ready(int base) {
  // Wait for the device to respond
  long timeout = 100000;
  unsigned char status = 0;
  while (timeout-- > 0) {
    status = _inb(base + REG_STATUS_OFFSET);
    if ((status & STATUS_ERR) != 0) {
      return 0;
    }
    if ((status & STATUS_BSY) == 0 && (status & STATUS_DRQ) != 0) {
      return 1;
    }
  }
  return 0;
}

unsigned char ide_init() {
  ide_global_status_.devices_present = 0;
  for (int i = IDE_PRIMARY_MASTER; i <= IDE_SECONDARY_SLAVE; i++) {
    int base = (i & IDE_SECONDARY) == 0 ? REG_BASE_IDE0 : REG_BASE_IDE1;
    int device_flags =
        ((i & IDE_SLAVE) == 0 ? 0 : DEVICE_FLAG_SLAVE) | DEVICE_FLAG_LBA | DEVICE_FLAG_LBA_MODE | DEVICE_FLAG_RESERVED;
    // Select the device
    _outb(base + REG_DEVICE_OFFSET, device_flags);
    // Send the IDENTIFY command
    _outb(base + REG_SECTOR_COUNT_OFFSET, 0);
    _outb(base + REG_LBA_LOW_OFFSET, 0);
    _outb(base + REG_LBA_MID_OFFSET, 0);
    _outb(base + REG_LBA_HIGH_OFFSET, 0);
    _outb(base + REG_COMMAND_OFFSET, COMMAND_IDENTIFY);
    if (!ide_wait_for_drq_ready(base)) {
      continue;
    }
    ide_global_status_.devices_present |= (1 << i);
    // Read the IDENTIFY data
    for (int j = 0; j < WORDS_PER_SECTOR; j++) {
      unsigned short data = _inw(base + REG_DATA_OFFSET);
      ((unsigned short *)&ide_global_status_.device_info[i])[j] = SWAP16(data);
    }
    // Trim strings
    ide_trim_string(ide_global_status_.device_info[i].serial, 20);
    ide_trim_string(ide_global_status_.device_info[i].fw_rev, 8);
    ide_trim_string(ide_global_status_.device_info[i].model, 40);
  }
  return ide_global_status_.devices_present;
}

const ide_device_info *ide_get_device_info(unsigned char device) {
  if (device > IDE_SECONDARY_SLAVE) {
    return 0;
  }
  if ((ide_global_status_.devices_present & (1 << device)) == 0) {
    return 0;
  }
  return &ide_global_status_.device_info[device];
}

unsigned int ide_read_sectors(unsigned char device, unsigned long lba, unsigned int sector_count, void *buffer) {
  if (sector_count == 0 || buffer == 0) {
    return 0;
  }
  sector_count =
      sector_count > MAX_SECTORS_PER_COMMAND ? MAX_SECTORS_PER_COMMAND : sector_count; // Max 256 sectors per command
  int base = (device & IDE_SECONDARY) == 0 ? REG_BASE_IDE0 : REG_BASE_IDE1;
  int device_flags = ((device & IDE_SLAVE) == 0 ? 0 : DEVICE_FLAG_SLAVE) | DEVICE_FLAG_LBA | DEVICE_FLAG_LBA_MODE |
                     DEVICE_FLAG_RESERVED;
  // Select the device
  _outb(base + REG_DEVICE_OFFSET, device_flags);
  _inb(base + REG_STATUS_OFFSET); // Read status to clear it
  // Send the READ SECTORS command
  _outb(base + REG_SECTOR_COUNT_OFFSET, sector_count & 0xff);
  _outb(base + REG_LBA_LOW_OFFSET, lba & 0xFF);
  _outb(base + REG_LBA_MID_OFFSET, (lba >> 8) & 0xFF);
  _outb(base + REG_LBA_HIGH_OFFSET, (lba >> 16) & 0xFF);
  _outb(base + REG_DEVICE_OFFSET, device_flags | ((lba >> 24) & DEVICE_FLAG_LBA28_MASK));
  _outb(base + REG_COMMAND_OFFSET, COMMAND_READ_SECTORS);
  unsigned int read_sectors = 0;
  for (int i = 0; i < sector_count; i++) {
    // Wait for the device to respond
    if (!ide_wait_for_drq_ready(base)) {
      return read_sectors;
    }
    // Read the sector data
    for (int j = 0; j < WORDS_PER_SECTOR; j++) {
      unsigned short data = _inw(base + REG_DATA_OFFSET);
      ((unsigned short *)buffer)[j] = data;
    }
    read_sectors++;
    buffer = (unsigned char *)buffer + BYTES_PER_SECTOR;
  }
  return read_sectors;
}

unsigned int ide_write_sectors(unsigned char device, unsigned long lba, unsigned int sector_count, const void *buffer) {
  if (sector_count == 0 || buffer == 0) {
    return 0;
  }
  sector_count =
      sector_count > MAX_SECTORS_PER_COMMAND ? MAX_SECTORS_PER_COMMAND : sector_count; // Max 256 sectors per command
  int base = (device & IDE_SECONDARY) == 0 ? REG_BASE_IDE0 : REG_BASE_IDE1;
  int device_flags = ((device & IDE_SLAVE) == 0 ? 0 : DEVICE_FLAG_SLAVE) | DEVICE_FLAG_LBA | DEVICE_FLAG_LBA_MODE |
                     DEVICE_FLAG_RESERVED;
  // Select the device
  _outb(base + REG_DEVICE_OFFSET, device_flags);
  _inb(base + REG_STATUS_OFFSET); // Read status to clear it
  // Send the WRITE SECTORS command
  _outb(base + REG_SECTOR_COUNT_OFFSET, sector_count & 0xff);
  _outb(base + REG_LBA_LOW_OFFSET, lba & 0xFF);
  _outb(base + REG_LBA_MID_OFFSET, (lba >> 8) & 0xFF);
  _outb(base + REG_LBA_HIGH_OFFSET, (lba >> 16) & 0xFF);
  _outb(base + REG_DEVICE_OFFSET, device_flags | ((lba >> 24) & DEVICE_FLAG_LBA28_MASK));
  _outb(base + REG_COMMAND_OFFSET, COMMAND_WRITE_SECTORS);
  unsigned int written_sectors = 0;
  for (int i = 0; i < sector_count; i++) {
    // Wait for the device to respond
    if (!ide_wait_for_drq_ready(base)) {
      return written_sectors;
    }
    // Write the sector data
    for (int j = 0; j < WORDS_PER_SECTOR; j++) {
      unsigned short data = ((unsigned short *)buffer)[j];
      _outw(base + REG_DATA_OFFSET, data);
    }
    if (!ide_wait_for_idle(base)) {
      return written_sectors;
    }
    written_sectors++;
    buffer = (unsigned char *)buffer + BYTES_PER_SECTOR;
  }
  return written_sectors;
}
