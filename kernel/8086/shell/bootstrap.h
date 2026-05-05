#ifndef __BOOTSTRAP_H_INCLUDED__
#define __BOOTSTRAP_H_INCLUDED__

extern void _halt();
extern void _clr_int();
extern void _set_int();
extern void _rst_ivt();
extern unsigned char _inb(unsigned short port);
extern unsigned short _inw(unsigned short port);
extern void _outb(unsigned short port, unsigned char value);
extern void _outw(unsigned short port, unsigned short value);

#endif  // __BOOTSTRAP_H_INCLUDED__
