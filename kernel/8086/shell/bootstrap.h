#ifndef __BOOTSTRAP_H_INCLUDED__
#define __BOOTSTRAP_H_INCLUDED__

extern void _halt();
extern void _disable();
extern void _enable();
extern unsigned char _inb(unsigned short port);
extern unsigned short _inw(unsigned short port);
extern void _outb(unsigned short port, unsigned char value);
extern void _outw(unsigned short port, unsigned short value);

#endif // __BOOTSTRAP_H_INCLUDED__
