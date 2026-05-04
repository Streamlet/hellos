#ifndef __BOOTSTRAP_H_INCLUDED__
#define __BOOTSTRAP_H_INCLUDED__

extern unsigned char inb(unsigned short port);
extern unsigned short inw(unsigned short port);
extern void outb(unsigned short port, unsigned char value);
extern void outw(unsigned short port, unsigned short value);

#endif  // __BOOTSTRAP_H_INCLUDED__
