#ifndef __BOOTSTRAP_H_INCLUDED__
#define __BOOTSTRAP_H_INCLUDED__

void _halt();
void _disable();
void _enable();
unsigned char _inb(unsigned short port);
unsigned short _inw(unsigned short port);
void _outb(unsigned short port, unsigned char value);
void _outw(unsigned short port, unsigned short value);

#endif // __BOOTSTRAP_H_INCLUDED__
